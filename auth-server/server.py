"""
DoNow Authentication Server
自托管认证服务，使用 MySQL 数据库，支持邮件发送
"""

import os
import uuid
import secrets
from datetime import datetime, timedelta
from functools import wraps
from threading import Thread

import bcrypt
import jwt
import pymysql
from flask import Flask, request, jsonify, g, render_template_string, redirect, url_for
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_mail import Mail, Message
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
# Serve uploaded files from 'uploads' directory
app.config['UPLOAD_FOLDER'] = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'uploads')
if not os.path.exists(app.config['UPLOAD_FOLDER']):
    os.makedirs(app.config['UPLOAD_FOLDER'])

from flask import send_from_directory
@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

CORS(app)

# 配置
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', secrets.token_hex(32))
app.config['JWT_EXPIRATION_HOURS'] = int(os.getenv('JWT_EXPIRATION_HOURS', 24 * 7))  # 7天
app.config['FRONTEND_URL'] = os.getenv('FRONTEND_URL', 'http://localhost:5000')

# MySQL 配置
app.config['MYSQL_HOST'] = os.getenv('MYSQL_HOST', 'localhost')
app.config['MYSQL_PORT'] = int(os.getenv('MYSQL_PORT', 3306))
app.config['MYSQL_USER'] = os.getenv('MYSQL_USER', 'root')
app.config['MYSQL_PASSWORD'] = os.getenv('MYSQL_PASSWORD', '')
app.config['MYSQL_DATABASE'] = os.getenv('MYSQL_DATABASE', 'donow_auth')

# 邮件配置
app.config['MAIL_SERVER'] = os.getenv('MAIL_SERVER', 'localhost')
app.config['MAIL_PORT'] = int(os.getenv('MAIL_PORT', 25))
app.config['MAIL_USE_TLS'] = os.getenv('MAIL_USE_TLS', 'false').lower() == 'true'
app.config['MAIL_USE_SSL'] = os.getenv('MAIL_USE_SSL', 'false').lower() == 'true'
app.config['MAIL_USERNAME'] = os.getenv('MAIL_USERNAME')
app.config['MAIL_PASSWORD'] = os.getenv('MAIL_PASSWORD')
app.config['MAIL_DEFAULT_SENDER'] = os.getenv('MAIL_DEFAULT_SENDER', 'noreply@donow.local')

mail = Mail(app)

# 限流
limiter = Limiter(
    key_func=get_remote_address,
    app=app,
    default_limits=["200 per day", "50 per hour"],
    storage_uri="memory://"
)


# ==================== 邮件发送 ====================

def send_async_email(app, msg):
    with app.app_context():
        try:
            mail.send(msg)
        except Exception as e:
            print(f"❌ Email sending failed: {e}")

def send_email(to, subject, template_html):
    msg = Message(
        subject,
        recipients=[to],
        html=template_html
    )
    # 异步发送，不阻塞 API
    Thread(target=send_async_email, args=(app, msg)).start()


# ==================== HTML 模板 ====================

HTML_VERIFY_EMAIL = """
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background-color: #f5f5f5; }
        .card { background: white; padding: 2rem; border-radius: 1rem; box-shadow: 0 4px 6px rgba(0,0,0,0.1); max-width: 400px; width: 100%; text-align: center; }
        .btn { display: inline-block; background: black; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; margin-top: 1rem; font-weight: bold; }
        h1 { margin-top: 0; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Verify Email</h1>
        <p>Click the button below to verify your email address for DoNow.</p>
        <a href="{{ link }}" class="btn">Verify Email</a>
    </div>
</body>
</html>
"""

HTML_RESET_PASSWORD = """
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background-color: #f5f5f5; }
        .card { background: white; padding: 2rem; border-radius: 1rem; box-shadow: 0 4px 6px rgba(0,0,0,0.1); max-width: 400px; width: 100%; text-align: center; }
        .btn { display: inline-block; background: black; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; margin-top: 1rem; font-weight: bold; }
        h1 { margin-top: 0; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Reset Password</h1>
        <p>Someone requested a password reset for your DoNow account. Click below to reset it.</p>
        <a href="{{ link }}" class="btn">Reset Password</a>
        <p style="margin-top: 1rem; font-size: 0.8rem; color: #666;">If you didn't request this, please ignore this email.</p>
    </div>
</body>
</html>
"""

# ==================== 数据库 ====================

def get_db():
    if 'db' not in g:
        g.db = pymysql.connect(
            host=app.config['MYSQL_HOST'],
            port=app.config['MYSQL_PORT'],
            user=app.config['MYSQL_USER'],
            password=app.config['MYSQL_PASSWORD'],
            database=app.config['MYSQL_DATABASE'],
            charset='utf8mb4',
            cursorclass=pymysql.cursors.DictCursor
        )
    return g.db

@app.teardown_appcontext
def close_db(exception):
    db = g.pop('db', None)
    if db is not None:
        db.close()

def init_db():
    conn = pymysql.connect(
        host=app.config['MYSQL_HOST'],
        port=app.config['MYSQL_PORT'],
        user=app.config['MYSQL_USER'],
        password=app.config['MYSQL_PASSWORD'],
        charset='utf8mb4'
    )
    try:
        with conn.cursor() as cursor:
            cursor.execute(f"CREATE DATABASE IF NOT EXISTS `{app.config['MYSQL_DATABASE']}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
            cursor.execute(f"USE `{app.config['MYSQL_DATABASE']}`")
            
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS users (
                    id VARCHAR(36) PRIMARY KEY,
                    email VARCHAR(255) UNIQUE NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    display_name VARCHAR(255),
                    email_verified TINYINT(1) DEFAULT 0,
                    verification_token VARCHAR(255),
                    reset_token VARCHAR(255),
                    reset_token_expiry DATETIME,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME NOT NULL,
                    is_anonymous TINYINT(1) DEFAULT 0,
                    INDEX idx_email (email),
                    INDEX idx_verification_token (verification_token),
                    INDEX idx_reset_token (reset_token)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ''')
            
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS refresh_tokens (
                    id VARCHAR(36) PRIMARY KEY,
                    user_id VARCHAR(36) NOT NULL,
                    token VARCHAR(255) UNIQUE NOT NULL,
                    expires_at DATETIME NOT NULL,
                    created_at DATETIME NOT NULL,
                    INDEX idx_token (token),
                    INDEX idx_user_id (user_id),
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ''')
            # Auto-migration: Check if avatar_url exists, if not add it
            try:
                cursor.execute("SHOW COLUMNS FROM users LIKE 'avatar_url'")
                if not cursor.fetchone():
                    cursor.execute("ALTER TABLE users ADD COLUMN avatar_url VARCHAR(500)")
                    print("✅ Added avatar_url column")
                
                # Auto-migration: Gamification fields
                cursor.execute("SHOW COLUMNS FROM users LIKE 'xp'")
                if not cursor.fetchone():
                    cursor.execute("ALTER TABLE users ADD COLUMN xp INT DEFAULT 0")
                    print("✅ Added xp column")
                    
                cursor.execute("SHOW COLUMNS FROM users LIKE 'level'")
                if not cursor.fetchone():
                    cursor.execute("ALTER TABLE users ADD COLUMN level INT DEFAULT 1")
                    print("✅ Added level column")

                cursor.execute("SHOW COLUMNS FROM users LIKE 'achievements'")
                if not cursor.fetchone():
                    cursor.execute("ALTER TABLE users ADD COLUMN achievements TEXT")
                    print("✅ Added achievements column")
                    
            except Exception as e:
                print(f"⚠️ Migration check failed: {e}")

        conn.commit()
        print("✅ Database initialized successfully")
    finally:
        conn.close()

def _user_to_dict(user):
    """Helper to convert database user row to API response dict"""
    import json
    
    achievements_data = []
    if user.get('achievements'):
        try:
            achievements_data = json.loads(user['achievements'])
        except:
            achievements_data = []

    return {
        'uid': user['id'],
        'email': user['email'],
        'displayName': user['display_name'],
        'nickname': user['display_name'],
        'avatar': user.get('avatar_url'),
        'emailVerified': bool(user.get('email_verified', False)),
        'isAnonymous': bool(user.get('is_anonymous', False)),
        # Gamification
        'xp': user.get('xp', 0),
        'level': user.get('level', 1),
        'achievements': achievements_data,
        'createdAt': user['created_at'].isoformat() if user.get('created_at') else None
    }

# ==================== 辅助函数 ====================

def generate_token(user_id: str, email: str) -> dict:
    now = datetime.utcnow()
    exp = now + timedelta(hours=app.config['JWT_EXPIRATION_HOURS'])
    payload = {'user_id': user_id, 'email': email, 'iat': now, 'exp': exp}
    
    access_token = jwt.encode(payload, app.config['SECRET_KEY'], algorithm='HS256')
    if isinstance(access_token, bytes):
        access_token = access_token.decode('utf-8')
        
    refresh_token = secrets.token_urlsafe(64)
    
    db = get_db()
    with db.cursor() as cursor:
        cursor.execute(
            'INSERT INTO refresh_tokens (id, user_id, token, expires_at, created_at) VALUES (%s, %s, %s, %s, %s)',
            (str(uuid.uuid4()), user_id, refresh_token, now + timedelta(days=30), now)
        )
    db.commit()
    
    return {
        'access_token': access_token,
        'refresh_token': refresh_token,
        'token_type': 'Bearer',
        'expires_in': int(exp.timestamp())
    }

def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or invalid authorization header'}), 401
        
        token = auth_header.split(' ')[1]
        try:
            payload = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            g.user_id = payload['user_id']
            g.email = payload['email']
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        return f(*args, **kwargs)
    return decorated

# ==================== 网页路由 (用户点击链接访问) ====================

@app.route('/verify', methods=['GET'])
def verify_page():
    token = request.args.get('token')
    if not token:
        return "Invalid token", 400
        
    # 调用内部逻辑验证
    db = get_db()
    with db.cursor() as cursor:
        cursor.execute('SELECT * FROM users WHERE verification_token = %s', (token,))
        user = cursor.fetchone()
        
        if not user:
            return "<h2>❌ Invalid or expired verification link.</h2>"
            
        cursor.execute(
            'UPDATE users SET email_verified = 1, verification_token = NULL, updated_at = %s WHERE id = %s',
            (datetime.utcnow(), user['id'])
        )
    db.commit()
    
    return """
    <h2>✅ Email Verified Successfully!</h2>
    <p>You can now close this window and return to the DoNow app.</p>
    <script>
        // 尝试唤起 App (Deep Link) - 可选
        // window.location.href = "donow://auth/verified";
    </script>
    """

@app.route('/reset-password-page', methods=['GET', 'POST'])
def reset_password_page():
    # 这是一个简单的重置密码网页
    token = request.args.get('token')
    if request.method == 'POST':
        password = request.form.get('password')
        token = request.form.get('token')
        
        if len(password) < 6:
            return "Password too short"
            
        db = get_db()
        with db.cursor() as cursor:
            cursor.execute('SELECT * FROM users WHERE reset_token = %s', (token,))
            user = cursor.fetchone()
            
            if not user or (user['reset_token_expiry'] and datetime.utcnow() > user['reset_token_expiry']):
                return "<h2>❌ Invalid or expired reset link.</h2>"
                
            password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
            cursor.execute(
                'UPDATE users SET password_hash = %s, reset_token = NULL, reset_token_expiry = NULL, updated_at = %s WHERE id = %s',
                (password_hash, datetime.utcnow(), user['id'])
            )
        db.commit()
        return "<h2>✅ Password Reset Successfully!</h2><p>You can now login with your new password.</p>"

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background-color: #f5f5f5; }}
            form {{ background: white; padding: 2rem; border-radius: 1rem; box-shadow: 0 4px 6px rgba(0,0,0,0.1); width: 300px; }}
            input {{ width: 100%; padding: 10px; margin: 10px 0; border: 1px solid #ccc; border-radius: 4px; box-sizing: border-box; }}
            button {{ width: 100%; background: black; color: white; padding: 10px; border: none; border-radius: 4px; font-weight: bold; cursor: pointer; }}
        </style>
    </head>
    <body>
        <form method="POST">
            <h2>Reset Password</h2>
            <input type="hidden" name="token" value="{token}">
            <input type="password" name="password" placeholder="New Password" required minlength="6">
            <button type="submit">Reset Password</button>
        </form>
    </body>
    </html>
    """

# ==================== API 路由 ====================

@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'ok', 'service': 'DoNow Auth Server', 'database': 'MySQL'})

@app.route('/api/auth/register', methods=['POST'])
@limiter.limit("5 per minute")
def register():
    data = request.get_json()
    email = data.get('email', '').strip().lower()
    password = data.get('password', '')
    display_name = data.get('displayName', '')
    
    if not email or not password:
        return jsonify({'error': 'Email and password required'}), 400
    if len(password) < 6:
        return jsonify({'error': 'Password must be at least 6 characters'}), 400
    if '@' not in email:
        return jsonify({'error': 'Invalid email format'}), 400
    
    db = get_db()
    with db.cursor() as cursor:
        cursor.execute('SELECT id FROM users WHERE email = %s', (email,))
        if cursor.fetchone():
            return jsonify({'error': 'Email already exists'}), 409
        
        user_id = str(uuid.uuid4())
        password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
        verification_token = secrets.token_urlsafe(32)
        now = datetime.utcnow()
        
        # Default avatar using DiceBear based on UID
        default_avatar = f"https://api.dicebear.com/7.x/adventurer/png?seed={user_id}"

        cursor.execute(
            '''INSERT INTO users (id, email, password_hash, display_name, avatar_url, verification_token, created_at, updated_at, xp, level, achievements)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)''',
            (user_id, email, password_hash, display_name, default_avatar, verification_token, now, now, 0, 1, '[]')
        )
    db.commit()
    
    # 发送验证邮件
    link = f"{app.config['FRONTEND_URL']}/verify?token={verification_token}"
    html = render_template_string(HTML_VERIFY_EMAIL, link=link)
    send_email(email, "Verify your email for DoNow", html)
    
    # Construct a temporary user dict for response since we just inserted it
    new_user = {
        'id': user_id, 'email': email, 'display_name': display_name,
        'email_verified': 0, 'is_anonymous': 0, 'avatar_url': default_avatar,
        'xp': 0, 'level': 1, 'achievements': '[]', 'created_at': now
    }
    
    tokens = generate_token(user_id, email)
    return jsonify({
        'user': _user_to_dict(new_user),
        'tokens': tokens
    }), 201

@app.route('/api/auth/login', methods=['POST'])
@limiter.limit("20 per hour")
def login():
    data = request.get_json()
    email = data.get('email', '').strip().lower()
    password = data.get('password', '')
    
    if not email or not password:
        return jsonify({'error': 'Email and password are required'}), 400
    
    db = get_db()
    with db.cursor() as cursor:
        cursor.execute('SELECT * FROM users WHERE email = %s', (email,))
        user = cursor.fetchone()
    
    if not user or not bcrypt.checkpw(password.encode(), user['password_hash'].encode()):
        return jsonify({'error': 'Invalid email or password'}), 401
    
    tokens = generate_token(user['id'], user['email'])
    return jsonify({
        'user': _user_to_dict(user),
        'tokens': tokens
    })

@app.route('/api/auth/anonymous', methods=['POST'])
@limiter.limit("20 per hour")
def anonymous_login():
    db = get_db()
    user_id = str(uuid.uuid4())
    email = f"anonymous_{user_id[:8]}@donow.local"
    password_hash = bcrypt.hashpw(secrets.token_bytes(32), bcrypt.gensalt()).decode()
    now = datetime.utcnow()
    
    # Default avatar for anonymous user
    default_avatar = f"https://api.dicebear.com/7.x/adventurer/png?seed={user_id}"

    with db.cursor() as cursor:
        cursor.execute(
            '''INSERT INTO users (id, email, password_hash, is_anonymous, email_verified, created_at, updated_at, avatar_url)
               VALUES (%s, %s, %s, 1, 1, %s, %s, %s)''',
            (user_id, email, password_hash, now, now, default_avatar)
        )
    db.commit()
    
    # Construct new anonymous user dict
    new_user = {
        'id': user_id, 'email': email, 'display_name': None,
        'email_verified': 1, 'is_anonymous': 1, 'avatar_url': default_avatar,
        'xp': 0, 'level': 1, 'achievements': None, 'created_at': now
    }

    tokens = generate_token(user_id, email)
    return jsonify({
        'user': _user_to_dict(new_user),
        'tokens': tokens
    })

@app.route('/api/auth/refresh', methods=['POST'])
def refresh_token():
    data = request.get_json()
    refresh_token = data.get('refreshToken')
    if not refresh_token:
        return jsonify({'error': 'Refresh token is required'}), 400
    
    db = get_db()
    with db.cursor() as cursor:
        cursor.execute('SELECT * FROM refresh_tokens WHERE token = %s', (refresh_token,))
        token_record = cursor.fetchone()
    
    if not token_record:
        return jsonify({'error': 'Invalid refresh token'}), 401
    
    if datetime.utcnow() > token_record['expires_at']:
        with db.cursor() as cursor:
            cursor.execute('DELETE FROM refresh_tokens WHERE id = %s', (token_record['id'],))
        db.commit()
        return jsonify({'error': 'Refresh token expired'}), 401
    
    with db.cursor() as cursor:
        cursor.execute('SELECT * FROM users WHERE id = %s', (token_record['user_id'],))
        user = cursor.fetchone()
        
        # 删除旧 token
        cursor.execute('DELETE FROM refresh_tokens WHERE id = %s', (token_record['id'],))
    db.commit()
    
    if not user:
        return jsonify({'error': 'User not found'}), 404
        
    tokens = generate_token(user['id'], user['email'])
    return jsonify({
        'user': _user_to_dict(user),
        'tokens': tokens
    })

@app.route('/api/auth/forgot-password', methods=['POST'])
@limiter.limit("5 per hour")
def forgot_password():
    data = request.get_json()
    email = data.get('email', '').strip().lower()
    
    if not email:
        return jsonify({'error': 'Email is required'}), 400
    
    db = get_db()
    with db.cursor() as cursor:
        cursor.execute('SELECT * FROM users WHERE email = %s', (email,))
        user = cursor.fetchone()
    
    if user:
        reset_token = secrets.token_urlsafe(32)
        reset_expiry = datetime.utcnow() + timedelta(hours=1)
        
        with db.cursor() as cursor:
            cursor.execute(
                'UPDATE users SET reset_token = %s, reset_token_expiry = %s, updated_at = %s WHERE id = %s',
                (reset_token, reset_expiry, datetime.utcnow(), user['id'])
            )
        db.commit()
        
        # 发送重置邮件
        link = f"{app.config['FRONTEND_URL']}/reset-password-page?token={reset_token}"
        html = render_template_string(HTML_RESET_PASSWORD, link=link)
        send_email(email, "Reset your DoNow password", html)
    
    return jsonify({'message': 'If the email exists, a reset link will be sent'})

@app.route('/api/auth/me', methods=['GET'])
@require_auth
def get_current_user():
    db = get_db()
    with db.cursor() as cursor:
        cursor.execute('SELECT * FROM users WHERE id = %s', (g.user_id,))
        user = cursor.fetchone()
    return jsonify({
        'user': _user_to_dict(user)
    })

@app.route('/api/auth/profile', methods=['POST'])
@require_auth
def update_profile():
    data = request.get_json()
    nickname = data.get('nickname')
    avatar_url = data.get('avatar')
    
    updates = []
    params = []
    
    if nickname is not None:
        updates.append("display_name = %s")
        params.append(nickname)
        
    if avatar_url is not None:
        updates.append("avatar_url = %s")
        params.append(avatar_url)
        
    if not updates:
        return jsonify({'message': 'No changes provided'})
        
    params.append(g.user_id)
    
    db = get_db()
    with db.cursor() as cursor:
        sql = f"UPDATE users SET {', '.join(updates)}, updated_at = NOW() WHERE id = %s"
        cursor.execute(sql, tuple(params))
    db.commit()
    
    # Return updated user info
    with db.cursor() as cursor:
        cursor.execute('SELECT * FROM users WHERE id = %s', (g.user_id,))
        user = cursor.fetchone()
        
    return jsonify({
        'user': _user_to_dict(user)
    })

@app.route('/api/auth/gamification/sync', methods=['POST'])
@require_auth
def sync_gamification():
    data = request.get_json()
    xp = data.get('xp')
    level = data.get('level')
    achievements = data.get('achievements') # Expecting a JSON list or similar structure
    
    updates = []
    params = []
    
    if xp is not None:
        updates.append("xp = %s")
        params.append(int(xp))
        
    if level is not None:
        updates.append("level = %s")
        params.append(int(level))
        
    if achievements is not None:
        import json
        updates.append("achievements = %s")
        # Store as JSON string
        if isinstance(achievements, list):
            params.append(json.dumps(achievements))
        else:
            params.append(str(achievements))
            
    if not updates:
        return jsonify({'message': 'No changes provided'})
        
    params.append(g.user_id)
    
    db = get_db()
    with db.cursor() as cursor:
        sql = f"UPDATE users SET {', '.join(updates)}, updated_at = NOW() WHERE id = %s"
        cursor.execute(sql, tuple(params))
    db.commit()
    
    # Return updated user info
    with db.cursor() as cursor:
        cursor.execute('SELECT * FROM users WHERE id = %s', (g.user_id,))
        user = cursor.fetchone()
        
    return jsonify({
        'user': _user_to_dict(user)
    })

@app.route('/api/auth/logout', methods=['POST'])
@require_auth
def logout():
    data = request.get_json() or {}
    refresh_token = data.get('refreshToken')
    if refresh_token:
        db = get_db()
        with db.cursor() as cursor:
            cursor.execute('DELETE FROM refresh_tokens WHERE token = %s AND user_id = %s', (refresh_token, g.user_id))
        db.commit()
    return jsonify({'message': 'Logged out successfully'})

@app.route('/api/auth/delete-account', methods=['DELETE'])
@require_auth
def delete_account():
    db = get_db()
    with db.cursor() as cursor:
        cursor.execute('DELETE FROM refresh_tokens WHERE user_id = %s', (g.user_id,))
        cursor.execute('DELETE FROM users WHERE id = %s', (g.user_id,))
    db.commit()
    return jsonify({'message': 'Account deleted successfully'})

# ... (保留前面的代码)

# 初始化数据库 (确保 Gunicorn 启动时也运行)
try:
    print("🔄 Attempting to initialize database...")
    init_db()
except Exception as e:
    print(f"⚠️ Database initialization skipped or failed: {e}")

@app.route('/api/upload/avatar', methods=['POST'])
@require_auth
def upload_avatar():
    """Proxy avatar upload to external image host to avoid CORS issues on web."""
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
        
    if file:
        try:
            import requests as http_requests
            
            # Read file bytes
            file_bytes = file.read()
            filename = file.filename
            content_type = file.content_type or 'image/jpeg'
            
            # Forward to external image host
            external_url = 'https://image.name666.top/upload'
            files = {'file': (filename, file_bytes, content_type)}
            
            response = http_requests.post(external_url, files=files, timeout=30)
            
            if response.status_code != 200:
                print(f"External upload failed: {response.status_code} - {response.text}")
                return jsonify({'error': f'External upload failed: {response.status_code}'}), 500
            
            # Parse response: [{"src": "/file/xxx.png"}]
            data = response.json()
            if isinstance(data, list) and len(data) > 0 and 'src' in data[0]:
                src = data[0]['src']
                full_url = f'https://image.name666.top{src}'
                return jsonify({'url': full_url}), 200
            else:
                print(f"Unexpected response format: {data}")
                return jsonify({'error': 'Invalid response from image host'}), 500
                
        except Exception as e:
            print(f"Upload Error: {e}")
            return jsonify({'error': f'Upload failed: {str(e)}'}), 500

if __name__ == '__main__':
    # Initialize DB
    init_db()
    
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'true').lower() == 'true'
    
    print(f"🚀 Auth Server running on http://localhost:{port}")
    app.run(host='0.0.0.0', port=port, debug=debug)

