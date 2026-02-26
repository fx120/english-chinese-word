# AI背单词应用 - 安装指南

## 环境要求

### 后端环境
- PHP >= 7.4.0
- MySQL >= 5.7
- Composer
- Apache/Nginx (支持URL重写)

### 前端环境
- Flutter SDK >= 3.0
- Dart SDK >= 2.17
- Android Studio / Xcode (用于移动端开发)

## 后端安装步骤

### 1. 安装依赖

进入后端目录并安装Composer依赖：

```bash
cd www.jpwenku.com
composer install
```

这将安装所有必需的PHP包，包括：
- ThinkPHP 5.x 框架
- Firebase JWT库（用于JWT认证）
- PHPSpreadsheet（用于Excel解析）
- 其他FastAdmin依赖

### 2. 配置数据库

#### 方法1：使用环境变量（推荐）

在 `www.jpwenku.com/` 目录下创建 `.env` 文件：

```ini
[app]
debug = true
trace = false

[database]
type = mysql
hostname = 127.0.0.1
database = ai_vocabulary
username = root
password = your_password
hostport = 3306
prefix = fa_
charset = utf8mb4
```

#### 方法2：直接修改配置文件

编辑 `www.jpwenku.com/application/database.php`：

```php
return [
    'type'     => 'mysql',
    'hostname' => '127.0.0.1',
    'database' => 'ai_vocabulary',
    'username' => 'root',
    'password' => 'your_password',
    'hostport' => '3306',
    'charset'  => 'utf8mb4',
    'prefix'   => 'fa_',
];
```

### 3. 创建数据库

```sql
CREATE DATABASE ai_vocabulary CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 4. 导入数据库表结构

```bash
mysql -u root -p ai_vocabulary < www.jpwenku.com/database/migrations/20240115_create_vocabulary_tables.sql
```

### 5. 配置JWT密钥

**重要**：生产环境必须修改JWT密钥！

编辑 `www.jpwenku.com/application/api/config.php`：

```php
'jwt' => [
    'key' => '你的复杂随机字符串', // 修改为复杂的随机字符串
    // ...
],
```

生成随机密钥的方法：

```bash
# Linux/Mac
openssl rand -base64 32

# 或使用PHP
php -r "echo bin2hex(random_bytes(32));"
```

### 6. 配置CORS

编辑 `www.jpwenku.com/application/api/config.php`：

开发环境（允许所有域名）：
```php
'cors' => [
    'enable' => true,
    'allow_origin' => '*',
    // ...
],
```

生产环境（限制特定域名）：
```php
'cors' => [
    'enable' => true,
    'allow_origin' => 'https://app.jpwenku.com,https://www.jpwenku.com',
    // ...
],
```

### 7. 配置阿里云短信服务（可选）

1. 登录FastAdmin后台：`http://your-domain/admin`
2. 进入"插件管理"
3. 找到"阿里云短信"插件
4. 配置以下信息：
   - AccessKey ID
   - AccessKey Secret
   - 短信签名
   - 短信模板CODE

### 8. 配置Web服务器

#### Apache配置

确保启用了 `mod_rewrite` 模块，`.htaccess` 文件已存在于 `www.jpwenku.com/public/` 目录。

虚拟主机配置示例：

```apache
<VirtualHost *:80>
    ServerName api.jpwenku.com
    DocumentRoot /path/to/www.jpwenku.com/public
    
    <Directory /path/to/www.jpwenku.com/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

#### Nginx配置

```nginx
server {
    listen 80;
    server_name api.jpwenku.com;
    root /path/to/www.jpwenku.com/public;
    index index.php index.html;

    location / {
        if (!-e $request_filename) {
            rewrite ^(.*)$ /index.php?s=$1 last;
            break;
        }
    }

    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

### 9. 设置目录权限

```bash
cd www.jpwenku.com
chmod -R 755 runtime
chmod -R 755 public/uploads
```

### 10. 测试安装

访问以下URL测试安装是否成功：

```
http://your-domain/api/common/init?version=1.0.0
```

如果返回JSON数据，说明安装成功。

## 前端安装步骤

### 1. 安装Flutter依赖

```bash
cd app
flutter pub get
```

### 2. 配置API地址

编辑 `app/lib/services/api_client.dart`，修改API基础URL：

```dart
static const String BASE_URL = 'https://api.jpwenku.com';
```

开发环境可以使用本地地址：

```dart
static const String BASE_URL = 'http://localhost/www.jpwenku.com/public';
```

### 3. 运行应用

#### Android

```bash
flutter run
```

#### iOS

```bash
flutter run
```

#### 生成APK

```bash
flutter build apk --release
```

#### 生成iOS包

```bash
flutter build ios --release
```

## 验证安装

### 1. 测试后端API

使用Postman或curl测试API接口：

```bash
# 测试发送验证码
curl -X POST http://your-domain/api/auth.php?action=sendCode \
  -H "Content-Type: application/json" \
  -d '{"mobile":"13800138000"}'

# 预期响应
{
  "code": 0,
  "msg": "验证码已发送",
  "data": {
    "expired_at": 1234567890
  }
}
```

### 2. 测试JWT认证

```bash
# 登录获取令牌
curl -X POST http://your-domain/api/auth.php?action=login \
  -H "Content-Type: application/json" \
  -d '{"mobile":"13800138000","code":"123456"}'

# 使用令牌访问受保护接口
curl -X GET http://your-domain/api/vocabulary.php?action=getList \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 3. 测试CORS

在浏览器控制台执行：

```javascript
fetch('http://your-domain/api/vocabulary.php?action=getList', {
  method: 'GET',
  headers: {
    'Content-Type': 'application/json',
  }
})
.then(response => response.json())
.then(data => console.log(data));
```

如果能正常返回数据，说明CORS配置成功。

## 常见问题

### Q1: Composer安装失败

**问题**：网络问题导致依赖下载失败

**解决方法**：使用国内镜像

```bash
composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/
```

### Q2: 数据库连接失败

**问题**：`SQLSTATE[HY000] [2002] Connection refused`

**解决方法**：
1. 检查MySQL服务是否启动
2. 检查数据库配置是否正确
3. 检查防火墙设置

### Q3: JWT令牌验证失败

**问题**：`认证令牌无效或已过期`

**解决方法**：
1. 检查JWT密钥配置是否正确
2. 确认令牌未过期
3. 确认请求头格式：`Authorization: Bearer {token}`

### Q4: CORS跨域错误

**问题**：`Access to fetch at ... has been blocked by CORS policy`

**解决方法**：
1. 确认CORS配置中 `enable` 为 `true`
2. 检查 `allow_origin` 配置
3. 确认OPTIONS请求能正常返回

### Q5: 路由404错误

**问题**：访问API接口返回404

**解决方法**：
1. 检查URL重写是否配置正确
2. 确认控制器文件存在
3. 检查控制器命名是否符合FastAdmin规范

### Q6: 文件上传权限错误

**问题**：`Permission denied`

**解决方法**：

```bash
chmod -R 755 www.jpwenku.com/runtime
chmod -R 755 www.jpwenku.com/public/uploads
```

## 开发环境配置

### 启用调试模式

编辑 `.env` 文件：

```ini
[app]
debug = true
trace = true
```

或编辑 `www.jpwenku.com/application/config.php`：

```php
'app_debug' => true,
'app_trace' => true,
```

### 查看日志

日志文件位置：`www.jpwenku.com/runtime/log/`

```bash
tail -f www.jpwenku.com/runtime/log/202401/15.log
```

## 生产环境部署

### 1. 关闭调试模式

```ini
[app]
debug = false
trace = false
```

### 2. 配置HTTPS

使用Let's Encrypt免费SSL证书：

```bash
certbot --nginx -d api.jpwenku.com
```

### 3. 优化性能

- 启用OPcache
- 配置Redis缓存
- 启用Gzip压缩
- 配置CDN加速

### 4. 安全加固

- 修改JWT密钥
- 限制CORS允许的域名
- 配置防火墙规则
- 定期更新依赖包
- 配置日志监控

## 下一步

安装完成后，请参考以下文档：

- [FastAdmin配置文档](./fastadmin-configuration.md)
- [API接口文档](./api-documentation.md)
- [数据库设计文档](./database-design.md)

## 技术支持

如遇到问题，请查看：

- [FastAdmin官方文档](https://doc.fastadmin.net/)
- [ThinkPHP 5.0文档](https://www.kancloud.cn/manual/thinkphp5)
- [Flutter官方文档](https://flutter.dev/docs)
