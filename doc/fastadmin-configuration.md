# FastAdmin项目配置文档

## 配置概述

本文档描述AI背单词应用后端FastAdmin项目的基础配置，包括数据库连接、JWT认证、CORS跨域和API路由规则。

## 配置文件位置

所有配置文件位于 `www.jpwenku.com/application/` 目录下：

- `database.php` - 数据库配置
- `config.php` - 应用主配置
- `api/config.php` - API模块配置
- `api/route.php` - API路由配置

## 1. 数据库配置

### 文件位置
`www.jpwenku.com/application/database.php`

### 配置说明

```php
return [
    'type'     => 'mysql',           // 数据库类型
    'hostname' => '127.0.0.1',       // 服务器地址
    'database' => 'fastadmin',       // 数据库名
    'username' => 'root',            // 用户名
    'password' => '',                // 密码
    'hostport' => '',                // 端口（默认3306）
    'charset'  => 'utf8mb4',         // 字符集
    'prefix'   => 'fa_',             // 表前缀
];
```

### 环境变量配置

建议在 `.env` 文件中配置数据库连接信息：

```ini
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

## 2. JWT认证配置

### 文件位置
`www.jpwenku.com/application/api/config.php`

### JWT配置项

```php
'jwt' => [
    // JWT密钥（生产环境必须修改）
    'key' => 'jpwenku_ai_vocabulary_jwt_secret_key_2024',
    
    // JWT算法
    'alg' => 'HS256',
    
    // JWT过期时间（30天）
    'expire' => 30 * 24 * 60 * 60,
    
    // 刷新令牌过期时间（60天）
    'refresh_expire' => 60 * 24 * 60 * 60,
    
    // 令牌发行者
    'iss' => 'www.jpwenku.com',
    
    // 令牌接收者
    'aud' => 'ai-vocabulary-app',
],
```

### JWT使用说明

#### 生成令牌

```php
use app\api\library\Auth;

$userId = 1;
$token = Auth::generateToken($userId);
```

#### 验证令牌

```php
use app\api\library\Auth;

$token = Auth::getTokenFromHeader();
$decoded = Auth::verifyToken($token);

if ($decoded) {
    $userId = $decoded->uid;
}
```

#### 刷新令牌

```php
use app\api\library\Auth;

$oldToken = Auth::getTokenFromHeader();
$newToken = Auth::refreshToken($oldToken);
```

### 安全建议

1. **生产环境必须修改JWT密钥**：使用复杂的随机字符串
2. **使用HTTPS**：确保令牌在传输过程中加密
3. **定期刷新令牌**：建议在令牌即将过期时自动刷新
4. **妥善保管密钥**：不要将密钥提交到版本控制系统

## 3. CORS跨域配置

### 文件位置
`www.jpwenku.com/application/api/config.php`

### CORS配置项

```php
'cors' => [
    // 是否开启跨域
    'enable' => true,
    
    // 允许的域名（* 表示允许所有域名）
    'allow_origin' => '*',
    
    // 允许的请求方法
    'allow_methods' => 'GET, POST, PUT, DELETE, OPTIONS',
    
    // 允许的请求头
    'allow_headers' => 'Content-Type, Authorization, X-Requested-With',
    
    // 是否允许携带凭证
    'allow_credentials' => true,
    
    // 预检请求缓存时间（秒）
    'max_age' => 86400,
],
```

### CORS使用说明

CORS中间件会自动处理跨域请求，包括：

1. **自动添加CORS响应头**
2. **处理OPTIONS预检请求**
3. **支持携带凭证的跨域请求**

### 生产环境配置

生产环境建议限制允许的域名：

```php
'allow_origin' => 'https://app.jpwenku.com,https://www.jpwenku.com',
```

## 4. API路由配置

### FastAdmin路由格式

FastAdmin使用特殊的API路径格式：

```
/api/{controller}.php?action={method}&{params}
```

### 路由映射关系

| URL路径 | 控制器 | 方法 |
|---------|--------|------|
| `/api/auth.php?action=sendCode` | `Auth.php` | `sendCode` |
| `/api/auth.php?action=login` | `Auth.php` | `login` |
| `/api/vocabulary.php?action=getList` | `Vocabulary.php` | `getList` |
| `/api/word.php?action=update` | `Word.php` | `update` |

### 控制器命名规范

**重要**：FastAdmin控制器命名规范

- ✅ 正确：`Auth.php`, `Vocabulary.php`, `Word.php`, `Userdata.php`
- ❌ 错误：`AuthController.php`, `VocabularyList.php`, `userData.php`

规则：
1. 文件名首字母大写
2. 其他字母小写
3. 不支持驼峰命名
4. 不添加Controller后缀

### 路由配置文件

`www.jpwenku.com/application/api/route.php`

```php
use think\Route;

// 认证相关
Route::post('api/auth/sendCode', 'api/auth/sendCode');
Route::post('api/auth/login', 'api/auth/login');
Route::post('api/auth/refresh', 'api/auth/refresh');

// 词表管理
Route::get('api/vocabulary/getList', 'api/vocabulary/getList');
Route::get('api/vocabulary/getDetail', 'api/vocabulary/getDetail');
Route::post('api/vocabulary/download', 'api/vocabulary/download');

// 单词管理
Route::post('api/word/addToList', 'api/word/addToList');
Route::post('api/word/update', 'api/word/update');

// 用户数据同步
Route::post('api/userdata/syncProgress', 'api/userdata/syncProgress');
Route::get('api/userdata/getStatistics', 'api/userdata/getStatistics');
```

## 5. 短信验证码配置

### 配置项

```php
'sms_code' => [
    // 验证码长度
    'length' => 6,
    
    // 验证码有效期（秒）
    'expire' => 300, // 5分钟
    
    // 验证码类型
    'type' => 'numeric',
],
```

### 阿里云短信插件

本项目使用FastAdmin的阿里云短信插件发送验证码。

插件位置：`www.jpwenku.com/addons/alisms/`

配置方法：
1. 在FastAdmin后台进入"插件管理"
2. 找到"阿里云短信"插件
3. 配置AccessKey、AccessSecret和短信模板

## 6. 基础控制器

### Base控制器

所有需要JWT认证的API控制器都应该继承 `Base` 控制器。

文件位置：`www.jpwenku.com/application/api/controller/Base.php`

```php
namespace app\api\controller;

use app\api\controller\Base;

class Vocabulary extends Base
{
    // 无需登录的方法
    protected $noNeedLogin = [];
    
    public function getList()
    {
        // $this->userId 可以直接使用当前登录用户ID
        // ...
    }
}
```

### 无需认证的接口

如果某些方法不需要JWT认证，可以在 `$noNeedLogin` 数组中声明：

```php
protected $noNeedLogin = ['getList', 'getDetail'];
```

## 7. 公共函数

### 文件位置
`www.jpwenku.com/application/api/common.php`

### 常用函数

```php
// 生成验证码
$code = generate_code(6, 'numeric');

// 验证手机号
if (validate_mobile($mobile)) {
    // 手机号格式正确
}

// 验证验证码
if (validate_code($code, 6)) {
    // 验证码格式正确
}

// 检查是否过期
if (is_expired($timestamp)) {
    // 已过期
}

// API响应
return api_success('操作成功', $data);
return api_error('操作失败', null, 1001);
```

## 8. 响应格式

### 标准响应格式

所有API接口统一使用以下响应格式：

```json
{
    "code": 0,
    "msg": "success",
    "data": {
        // 返回数据
    }
}
```

### 状态码说明

| code | 说明 |
|------|------|
| 0 | 成功 |
| 1 | 一般错误 |
| 401 | 未认证或认证失败 |
| 403 | 无权限 |
| 404 | 资源不存在 |
| 500 | 服务器错误 |

## 9. 部署检查清单

### 开发环境

- [ ] 配置数据库连接信息
- [ ] 创建数据库表结构
- [ ] 配置阿里云短信插件（可选）
- [ ] 测试JWT认证功能
- [ ] 测试CORS跨域功能

### 生产环境

- [ ] 修改JWT密钥为复杂随机字符串
- [ ] 限制CORS允许的域名
- [ ] 配置HTTPS证书
- [ ] 关闭调试模式（app_debug = false）
- [ ] 配置日志记录
- [ ] 配置数据库连接池
- [ ] 配置Redis缓存（可选）
- [ ] 配置阿里云短信服务
- [ ] 性能优化和压力测试

## 10. 常见问题

### Q1: JWT令牌验证失败？

**原因**：
- JWT密钥配置错误
- 令牌已过期
- 令牌格式不正确

**解决方法**：
1. 检查JWT配置是否正确
2. 确认令牌未过期
3. 确认请求头格式：`Authorization: Bearer {token}`

### Q2: CORS跨域请求失败？

**原因**：
- CORS未启用
- 允许的域名配置错误
- 预检请求被拦截

**解决方法**：
1. 确认CORS配置中 `enable` 为 `true`
2. 检查 `allow_origin` 配置
3. 确认OPTIONS请求能正常返回

### Q3: 路由无法访问？

**原因**：
- 控制器命名不符合FastAdmin规范
- 路由配置错误
- URL重写未配置

**解决方法**：
1. 检查控制器命名是否符合规范
2. 确认路由配置正确
3. 检查服务器URL重写配置

## 11. 相关文档

- [FastAdmin官方文档](https://doc.fastadmin.net/)
- [ThinkPHP 5.0完全开发手册](https://www.kancloud.cn/manual/thinkphp5)
- [JWT官方文档](https://jwt.io/)
- [CORS规范](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/CORS)

## 更新日志

- 2024-01-15: 初始版本，完成基础配置
