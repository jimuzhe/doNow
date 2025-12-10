# DoNow Authentication Server

自托管认证服务，功能类似 Firebase Auth。

## 功能

- ✅ 邮箱/密码注册
- ✅ 邮箱/密码登录
- ✅ 匿名登录
- ✅ JWT Token 认证
- ✅ Refresh Token 刷新
- ✅ 邮箱验证
- ✅ 忘记密码/重置密码
- ✅ 更新用户资料
- ✅ 删除账户
- ✅ 限流保护

## 部署步骤

### 1. 安装依赖

```bash
cd auth-server
pip install -r requirements.txt
```

### 2. 配置环境变量

```bash
cp .env.example .env
nano .env
```

修改 `SECRET_KEY` 为随机字符串（**非常重要！**）：
```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

### 3. 运行服务器

**开发模式：**
```bash
python server.py
```

**生产模式（使用 Gunicorn）：**
```bash
gunicorn -w 4 -b 0.0.0.0:5000 server:app
```

### 4. 配置 Nginx 反向代理（推荐）

```nginx
server {
    listen 80;
    server_name auth.name666.top;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 5. 配置 SSL（使用 Certbot）

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d auth.name666.top
```

### 6. 配置 Systemd 服务

创建 `/etc/systemd/system/donow-auth.service`：

```ini
[Unit]
Description=DoNow Auth Server
After=network.target

[Service]
User=www-data
WorkingDirectory=/path/to/auth-server
Environment="PATH=/path/to/venv/bin"
ExecStart=/path/to/venv/bin/gunicorn -w 4 -b 127.0.0.1:5000 server:app
Restart=always

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
sudo systemctl enable donow-auth
sudo systemctl start donow-auth
```

## API 文档

### 注册
```
POST /api/auth/register
{
  "email": "user@example.com",
  "password": "123456",
  "displayName": "用户名"
}
```

### 登录
```
POST /api/auth/login
{
  "email": "user@example.com",
  "password": "123456"
}
```

### 匿名登录
```
POST /api/auth/anonymous
```

### 刷新 Token
```
POST /api/auth/refresh
{
  "refreshToken": "xxx"
}
```

### 获取当前用户
```
GET /api/auth/me
Authorization: Bearer <access_token>
```

### 忘记密码
```
POST /api/auth/forgot-password
{
  "email": "user@example.com"
}
```

### 重置密码
```
POST /api/auth/reset-password
{
  "token": "reset_token",
  "newPassword": "new_password"
}
```

### 验证邮箱
```
POST /api/auth/verify-email
{
  "token": "verification_token"
}
```

### 更新资料
```
PUT /api/auth/update-profile
Authorization: Bearer <access_token>
{
  "displayName": "新名字"
}
```

### 登出
```
POST /api/auth/logout
Authorization: Bearer <access_token>
{
  "refreshToken": "xxx"
}
```

### 删除账户
```
DELETE /api/auth/delete-account
Authorization: Bearer <access_token>
```

## 响应格式

成功响应：
```json
{
  "user": {
    "uid": "uuid",
    "email": "user@example.com",
    "displayName": "用户名",
    "emailVerified": true,
    "isAnonymous": false
  },
  "tokens": {
    "access_token": "jwt_token",
    "refresh_token": "refresh_token",
    "token_type": "Bearer",
    "expires_in": 1234567890
  }
}
```

错误响应：
```json
{
  "error": "错误信息"
}
```
