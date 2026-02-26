<?php

namespace app\api\library;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use think\Config;
use think\Exception;

/**
 * JWT认证类
 */
class Auth
{
    /**
     * 生成JWT令牌
     * @param int $userId 用户ID
     * @param array $data 附加数据
     * @return string JWT令牌
     */
    public static function generateToken($userId, $data = [])
    {
        $config = Config::get('jwt');
        $now = time();
        
        $payload = [
            'iss' => $config['iss'],           // 发行者
            'aud' => $config['aud'],           // 接收者
            'iat' => $now,                     // 签发时间
            'nbf' => $now,                     // 生效时间
            'exp' => $now + $config['expire'], // 过期时间
            'uid' => $userId,                  // 用户ID
            'data' => $data,                   // 附加数据
        ];
        
        return JWT::encode($payload, $config['key'], $config['alg']);
    }
    
    /**
     * 验证JWT令牌
     * @param string $token JWT令牌
     * @return object|false 解码后的数据，失败返回false
     */
    public static function verifyToken($token)
    {
        try {
            $config = Config::get('jwt');
            $decoded = JWT::decode($token, new Key($config['key'], $config['alg']));
            return $decoded;
        } catch (\Exception $e) {
            return false;
        }
    }
    
    /**
     * 从请求头获取JWT令牌
     * @return string|null
     */
    public static function getTokenFromHeader()
    {
        $authorization = request()->header('Authorization');
        
        if (!$authorization) {
            return null;
        }
        
        // 支持 "Bearer token" 格式
        if (stripos($authorization, 'Bearer') === 0) {
            return trim(substr($authorization, 6));
        }
        
        return $authorization;
    }
    
    /**
     * 获取当前登录用户ID
     * @return int|null
     */
    public static function getCurrentUserId()
    {
        $token = self::getTokenFromHeader();
        
        if (!$token) {
            return null;
        }
        
        $decoded = self::verifyToken($token);
        
        if (!$decoded) {
            return null;
        }
        
        return $decoded->uid ?? null;
    }
    
    /**
     * 刷新JWT令牌
     * @param string $token 旧令牌
     * @return string|false 新令牌，失败返回false
     */
    public static function refreshToken($token)
    {
        $decoded = self::verifyToken($token);
        
        if (!$decoded) {
            return false;
        }
        
        // 生成新令牌
        return self::generateToken($decoded->uid, (array)($decoded->data ?? []));
    }
    
    /**
     * 检查令牌是否即将过期（剩余时间少于1天）
     * @param string $token JWT令牌
     * @return bool
     */
    public static function isTokenExpiringSoon($token)
    {
        $decoded = self::verifyToken($token);
        
        if (!$decoded) {
            return false;
        }
        
        $exp = $decoded->exp ?? 0;
        $now = time();
        
        // 剩余时间少于1天
        return ($exp - $now) < 86400;
    }
}
