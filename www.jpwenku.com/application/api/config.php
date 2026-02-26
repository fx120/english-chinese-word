<?php

//API模块配置文件
return [
    // 异常处理类
    'exception_handle' => '\\app\\api\\library\\ExceptionHandle',
    
    // JWT配置
    'jwt' => [
        // JWT密钥 (生产环境请修改为复杂的随机字符串)
        'key' => 'jpwenku_ai_vocabulary_jwt_secret_key_2024',
        // JWT算法
        'alg' => 'HS256',
        // JWT过期时间 (30天，单位：秒)
        'expire' => 30 * 24 * 60 * 60,
        // 刷新令牌过期时间 (60天，单位：秒)
        'refresh_expire' => 60 * 24 * 60 * 60,
        // 令牌发行者
        'iss' => 'www.jpwenku.com',
        // 令牌接收者
        'aud' => 'ai-vocabulary-app',
    ],
    
    // CORS跨域配置
    'cors' => [
        // 是否开启跨域
        'enable' => true,
        // 允许的域名，* 表示允许所有域名
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
    
    // API路由配置
    'api_route' => [
        // API版本
        'version' => 'v1',
        // 是否启用API版本控制
        'version_control' => false,
        // API响应格式
        'response_format' => 'json',
    ],
    
    // 短信验证码配置
    'sms_code' => [
        // 验证码长度
        'length' => 6,
        // 验证码有效期（秒）
        'expire' => 300, // 5分钟
        // 验证码类型：numeric(纯数字), alpha(纯字母), mixed(数字+字母)
        'type' => 'numeric',
    ],
];
