# Auth控制器实现文档

## 概述

Auth控制器实现了用户认证功能，包括短信验证码发送、验证码登录和JWT令牌刷新。

## 实现位置

- **文件路径**: `www.jpwenku.com/application/api/controller/Auth.php`
- **命名空间**: `app\api\controller`
- **父类**: `app\common\controller\Api`

## 功能说明

### 1. 发送验证码 (sendCode)

**接口地址**: `POST /api/auth/sendCode`

**请求参数**:
```json
{
  "mobile": "13800138000"
}
```

**功能特性**:
- 生成6位数字验证码
- 验证码有效期5分钟
- 60秒内不能重复发送
- 1小时内最多发送5次（防止滥用）
- 调用阿里云短信插件发送验证码

**响应示例**:
```json
{
  "code": 1,
  "msg": "验证码已发送",
  "data": {
    "expired_at": 1705308000
  }
}
```

**错误处理**:
- 手机号格式不正确
- 发送过于频繁
- 短信服务未配置
- 验证码发送失败

### 2. 验证码登录 (login)

**接口地址**: `POST /api/auth/login`

**请求参数**:
```json
{
  "mobile": "13800138000",
  "code": "123456"
}
```

**功能特性**:
- 验证手机号和验证码格式
- 检查验证码是否正确和过期
- 自动创建新用户或登录现有用户
- 生成JWT令牌（有效期30天）
- 标记验证码为已使用

**响应示例**:
```json
{
  "code": 1,
  "msg": "登录成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "mobile": "13800138000",
      "nickname": "用户8000",
      "avatar": ""
    }
  }
}
```

**错误处理**:
- 手机号格式不正确
- 验证码格式不正确
- 验证码不正确
- 验证码已过期

### 3. 刷新令牌 (refresh)

**接口地址**: `POST /api/auth/refresh`

**请求头**:
```
Authorization: Bearer {token}
```

**功能特性**:
- 验证当前令牌有效性
- 生成新的JWT令牌
- 保持用户登录状态

**响应示例**:
```json
{
  "code": 1,
  "msg": "令牌刷新成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**错误处理**:
- 未提供令牌
- 令牌无效或已过期

## 技术实现细节

### 验证码生成

```php
private function generateCode()
{
    $config = Config::get('sms_code');
    $length = $config['length'] ?? 6;
    
    $code = '';
    for ($i = 0; $i < $length; $i++) {
        $code .= mt_rand(0, 9);
    }
    
    return $code;
}
```

### 短信发送

使用FastAdmin的阿里云短信插件：

```php
private function sendSms($mobile, $code)
{
    try {
        $result = \app\common\library\Sms::send($mobile, $code, 'login');
        return $result ? true : false;
    } catch (Exception $e) {
        \think\Log::error('短信发送失败: ' . $e->getMessage());
        return false;
    }
}
```

### JWT令牌生成

使用自定义的Auth库：

```php
$token = \app\api\library\Auth::generateToken($user->id, [
    'mobile' => $user->mobile,
    'nickname' => $user->nickname,
]);
```

## 数据库依赖

### fa_sms_code 表

```sql
CREATE TABLE `fa_sms_code` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `mobile` varchar(11) NOT NULL,
  `code` varchar(6) NOT NULL,
  `created_at` int(11) NOT NULL,
  `expired_at` int(11) NOT NULL,
  `used` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_mobile` (`mobile`),
  KEY `idx_expired_at` (`expired_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### fa_user 表

使用FastAdmin的标准用户表结构，包含以下字段：
- `id`: 用户ID
- `mobile`: 手机号（唯一）
- `nickname`: 昵称
- `avatar`: 头像
- `status`: 状态
- `createtime`: 创建时间
- `updatetime`: 更新时间

## 配置说明

### JWT配置 (config.php)

```php
'jwt' => [
    'key' => 'jpwenku_ai_vocabulary_jwt_secret_key_2024',
    'alg' => 'HS256',
    'expire' => 30 * 24 * 60 * 60,  // 30天
    'refresh_expire' => 60 * 24 * 60 * 60,  // 60天
    'iss' => 'www.jpwenku.com',
    'aud' => 'ai-vocabulary-app',
],
```

### 短信验证码配置 (config.php)

```php
'sms_code' => [
    'length' => 6,  // 验证码长度
    'expire' => 300,  // 5分钟过期
    'type' => 'numeric',  // 纯数字
],
```

## 安全特性

1. **频率限制**:
   - 同一手机号60秒内只能发送一次
   - 1小时内最多发送5次

2. **验证码安全**:
   - 验证码使用后立即标记为已使用
   - 验证码5分钟后自动过期
   - 验证码只能使用一次

3. **JWT令牌**:
   - 使用HS256算法加密
   - 令牌包含用户ID和基本信息
   - 令牌有效期30天
   - 支持令牌刷新

4. **CORS跨域**:
   - 支持跨域请求
   - 处理OPTIONS预检请求
   - 配置允许的域名和请求方法

## 无需登录的方法

控制器中定义了无需登录即可访问的方法：

```php
protected $noNeedLogin = ['sendCode', 'login'];
```

这意味着：
- `sendCode`: 发送验证码不需要登录
- `login`: 登录接口本身不需要登录
- `refresh`: 刷新令牌需要提供有效的JWT令牌

## 错误码说明

- `code = 1`: 操作成功
- `code = 0`: 操作失败（业务错误）
- `code = 401`: 未授权（令牌无效或过期）
- `code = 403`: 无权限

## 测试建议

### 单元测试

1. 测试验证码生成格式正确（6位数字）
2. 测试验证码发送频率限制
3. 测试验证码过期检查
4. 测试用户自动创建逻辑
5. 测试JWT令牌生成和验证
6. 测试令牌刷新功能

### 集成测试

1. 完整的登录流程测试
2. 验证码错误处理测试
3. 令牌过期和刷新测试
4. 并发请求测试

## 依赖项

- **FastAdmin框架**: 基础框架和用户模型
- **ThinkPHP 5.x**: 底层框架
- **Firebase JWT**: JWT令牌生成和验证
- **阿里云短信插件**: 短信发送服务

## 后续优化建议

1. 添加图形验证码防止机器人攻击
2. 实现更复杂的频率限制策略（如滑动窗口）
3. 添加短信发送失败重试机制
4. 实现验证码模板配置
5. 添加用户登录日志记录
6. 实现多设备登录管理

## 相关文件

- 控制器: `www.jpwenku.com/application/api/controller/Auth.php`
- JWT库: `www.jpwenku.com/application/api/library/Auth.php`
- CORS库: `www.jpwenku.com/application/api/library/Cors.php`
- 配置文件: `www.jpwenku.com/application/api/config.php`
- 路由配置: `www.jpwenku.com/application/api/route.php`
- 数据库迁移: `www.jpwenku.com/database/migrations/20240115_create_vocabulary_tables.sql`

## 实现日期

2024-01-15

## 实现状态

✅ 已完成

## 验证需求

- 需求 1.1: 发送6位数字验证码 ✅
- 需求 1.2: 验证码5分钟有效期 ✅
- 需求 1.3: 验证码登录创建/登录用户 ✅
- 需求 1.4: 返回JWT令牌（30天有效期）✅
