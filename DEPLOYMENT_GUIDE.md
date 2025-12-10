# DoNow 自托管部署与打包指南

DoNow 目前默认使用**自托管 Python 认证服务**，以支持在中国大陆等 Firebase 受限地区的访问。本文档将指导您如何部署后端服务以及如何打包前端应用。

## 1. 后端服务部署 (Auth Server)

后端服务位于 `auth-server/` 目录，基于 Python Flask + MySQL。

### 环境要求
- Docker & Docker Compose
- 一个域名（例如 `auth.name666.top`）
- SSL 证书（推荐使用 Nginx + Certbot）

### 部署步骤

1. **上传代码**：将 `auth-server/` 文件夹上传到服务器。
2. **配置环境变量**：
   ```bash
   cd auth-server
   cp .env.example .env
   nano .env
   ```
   *注意：务必配置 `MAIL_` 相关参数以支持邮件验证和密码找回。*

3. **启动服务**：
   ```bash
   docker-compose up -d --build
   ```

4. **配置 Nginx 反向代理**（示例）：
   ```nginx
   server {
       server_name auth.name666.top;
       
       location / {
           proxy_pass http://localhost:5000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
       
       # ... SSL 配置 (Certbot) ...
   }
   ```

## 2. 前端应用打包 (Flutter)

Flutter 应用支持通过**编译时变量**切换认证后端。

### 默认打包 (使用自托管服务)
默认情况下，应用连接到 `https://auth.name666.top/api/auth`。

```bash
flutter build apk
```

### 指定自定义服务器地址
如果您在本地测试或有新的服务器地址：

```bash
# 本地真机调试（替换为电脑IP）
flutter run --dart-define=AUTH_API_URL=http://192.168.x.x:5000/api/auth

# 打包指定地址
flutter build apk --dart-define=AUTH_API_URL=https://your-new-domain.com/api/auth
```

### 切换回 Google Firebase
如果您需要发布 Google Play 版本或在非受限地区使用：

```bash
flutter build apk --dart-define=USE_SELF_HOSTED=false
```

### iOS 打包注意事项
在 `ios/Runner/Info.plist` 中，如果使用 HTTP (非 HTTPS) 进行本地调试，需要配置 `NSAppTransportSecurity` 允许任意加载（生产环境建议移除）。

## 3. 功能对比

| 功能 | 自托管 (默认) | Firebase (通过参数切换) |
| :--- | :--- | :--- |
| **登录/注册** | ✅ 支持 (Email + 密码) | ✅ 支持 |
| **匿名登录** | ✅ 支持 | ✅ 支持 |
| **邮件验证** | ✅ 支持 (需配置 SMTP) | ✅ 支持 |
| **找回密码** | ✅ 支持 (需配置 SMTP) | ✅ 支持 |
| **中国大陆访问** | ✅ **可用** | ❌ **不可用** |
| **数据存储** | 您的 MySQL 数据库 | Google Firebase |

## 4. 维护与调试

- **后端日志**：`docker-compose logs -f`
- **前端日志**：在 Settings -> Developer Options 中开启 "Debug Logs" 可在屏幕上查看请求错误。
