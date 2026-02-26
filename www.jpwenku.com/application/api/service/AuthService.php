<?php

namespace app\api\service;

use think\Config;
use think\Db;
use think\Exception;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;

/**
 * 认证服务类
 * 处理验证码生成、验证、JWT令牌管理等认证相关业务逻辑
 */
class AuthService
{
    /**
     * 验证码长度
     */
    const CODE_LENGTH = 6;
    
    /**
     * 验证码有效期（秒）
     */
    const CODE_EXPIRE = 300; // 5分钟
    
    /**
     * JWT令牌有效期（秒）
     */
    const TOKEN_EXPIRE = 2592000; // 30天
    
    /**
     * 发送频率限制（秒）
     */
    const SEND_INTERVAL = 60; // 60秒
    
    /**
     * IP发送限制（次/小时）
     */
    const IP_LIMIT_PER_HOUR = 5;
    
    /**
     * 生成验证码
     * 
     * @param int $length 验证码长度
     * @return string
     */
    public static function generateCode($length = self::CODE_LENGTH)
    {
        $code = '';
        for ($i = 0; $i < $length; $i++) {
            $code .= mt_rand(0, 9);
        }
        return $code;
    }
    
    /**
     * 保存验证码到数据库
     * 
     * @param string $mobile 手机号
     * @param string $code 验证码
     * @return bool
     */
    public static function saveCode($mobile, $code)
    {
        $now = time();
        $expiredAt = $now + self::CODE_EXPIRE;
        
        $data = [
            'mobile' => $mobile,
            'code' => $code,
            'created_at' => $now,
            'expired_at' => $expiredAt,
            'used' => 0,
        ];
        
        return Db::name('sms_code')->insert($data);
    }
    
    /**
     * 验证验证码
     * 
     * @param string $mobile 手机号
     * @param string $code 验证码
     * @return array ['valid' => bool, 'message' => string, 'code_id' => int]
     */
    public static function validateCode($mobile, $code)
    {
        // 查询验证码
        $smsCode = Db::name('sms_code')
            ->where('mobile', $mobile)
            ->where('code', $code)
            ->where('used', 0)
            ->order('created_at', 'desc')
            ->find();
        
        if (!$smsCode) {
            return [
                'valid' => false,
                'message' => '验证码不正确',
                'code_id' => null
            ];
        }
        
        // 检查是否过期
        if (time() > $smsCode['expired_at']) {
            return [
                'valid' => false,
                'message' => '验证码已过期',
                'code_id' => $smsCode['id']
            ];
        }
        
        return [
            'valid' => true,
            'message' => '验证码正确',
            'code_id' => $smsCode['id']
        ];
    }
    
    /**
     * 标记验证码为已使用
     * 
     * @param int $codeId 验证码ID
     * @return bool
     */
    public static function markCodeAsUsed($codeId)
    {
        return Db::name('sms_code')
            ->where('id', $codeId)
            ->update(['used' => 1]);
    }
    
    /**
     * 检查发送频率限制
     * 
     * @param string $mobile 手机号
     * @return array ['allowed' => bool, 'message' => string, 'wait_seconds' => int]
     */
    public static function checkSendFrequency($mobile)
    {
        // 查询最近的验证码
        $lastCode = Db::name('sms_code')
            ->where('mobile', $mobile)
            ->order('created_at', 'desc')
            ->find();
        
        if ($lastCode) {
            $elapsed = time() - $lastCode['created_at'];
            if ($elapsed < self::SEND_INTERVAL) {
                $waitSeconds = self::SEND_INTERVAL - $elapsed;
                return [
                    'allowed' => false,
                    'message' => "发送过于频繁，请{$waitSeconds}秒后再试",
                    'wait_seconds' => $waitSeconds
                ];
            }
        }
        
        return [
            'allowed' => true,
            'message' => '允许发送',
            'wait_seconds' => 0
        ];
    }
    
    /**
     * 检查IP发送限制
     * 
     * @param string $ip IP地址
     * @return array ['allowed' => bool, 'message' => string, 'count' => int]
     */
    public static function checkIpLimit($ip)
    {
        // 查询1小时内该IP的发送次数
        $count = Db::name('sms_code')
            ->where('created_at', '>', time() - 3600)
            ->count();
        
        if ($count >= self::IP_LIMIT_PER_HOUR) {
            return [
                'allowed' => false,
                'message' => '发送次数过多，请稍后再试',
                'count' => $count
            ];
        }
        
        return [
            'allowed' => true,
            'message' => '允许发送',
            'count' => $count
        ];
    }
    
    /**
     * 生成JWT令牌
     * 
     * @param int $userId 用户ID
     * @param array $payload 附加数据
     * @return string
     */
    public static function generateToken($userId, $payload = [])
    {
        $config = Config::get('jwt');
        $key = $config['key'] ?? 'your-secret-key';
        $algorithm = $config['algorithm'] ?? 'HS256';
        
        $now = time();
        $expire = $now + self::TOKEN_EXPIRE;
        
        $tokenPayload = [
            'iss' => $config['issuer'] ?? 'jpwenku.com', // 签发者
            'aud' => $config['audience'] ?? 'jpwenku.com', // 接收者
            'iat' => $now, // 签发时间
            'nbf' => $now, // 生效时间
            'exp' => $expire, // 过期时间
            'uid' => $userId, // 用户ID
        ];
        
        // 合并附加数据
        $tokenPayload = array_merge($tokenPayload, $payload);
        
        return JWT::encode($tokenPayload, $key, $algorithm);
    }
    
    /**
     * 验证JWT令牌
     * 
     * @param string $token JWT令牌
     * @return array ['valid' => bool, 'message' => string, 'payload' => array|null]
     */
    public static function validateToken($token)
    {
        try {
            $config = Config::get('jwt');
            $key = $config['key'] ?? 'your-secret-key';
            $algorithm = $config['algorithm'] ?? 'HS256';
            
            $decoded = JWT::decode($token, new Key($key, $algorithm));
            
            return [
                'valid' => true,
                'message' => '令牌有效',
                'payload' => (array)$decoded
            ];
            
        } catch (\Firebase\JWT\ExpiredException $e) {
            return [
                'valid' => false,
                'message' => '令牌已过期',
                'payload' => null
            ];
        } catch (\Firebase\JWT\SignatureInvalidException $e) {
            return [
                'valid' => false,
                'message' => '令牌签名无效',
                'payload' => null
            ];
        } catch (\Exception $e) {
            return [
                'valid' => false,
                'message' => '令牌无效: ' . $e->getMessage(),
                'payload' => null
            ];
        }
    }
    
    /**
     * 刷新JWT令牌
     * 
     * @param string $token 旧令牌
     * @return array ['success' => bool, 'message' => string, 'token' => string|null]
     */
    public static function refreshToken($token)
    {
        $validation = self::validateToken($token);
        
        if (!$validation['valid']) {
            return [
                'success' => false,
                'message' => $validation['message'],
                'token' => null
            ];
        }
        
        $payload = $validation['payload'];
        $userId = $payload['uid'] ?? null;
        
        if (!$userId) {
            return [
                'success' => false,
                'message' => '令牌数据无效',
                'token' => null
            ];
        }
        
        // 生成新令牌
        $newPayload = [
            'mobile' => $payload['mobile'] ?? '',
            'nickname' => $payload['nickname'] ?? '',
        ];
        
        $newToken = self::generateToken($userId, $newPayload);
        
        return [
            'success' => true,
            'message' => '令牌刷新成功',
            'token' => $newToken
        ];
    }
    
    /**
     * 从请求头获取令牌
     * 
     * @return string|null
     */
    public static function getTokenFromHeader()
    {
        $authorization = request()->header('Authorization');
        
        if (empty($authorization)) {
            return null;
        }
        
        // 格式: Bearer {token}
        if (strpos($authorization, 'Bearer ') === 0) {
            return substr($authorization, 7);
        }
        
        return $authorization;
    }
    
    /**
     * 发送短信验证码（集成阿里云短信插件）
     * 
     * @param string $mobile 手机号
     * @param string $code 验证码
     * @return array ['success' => bool, 'message' => string]
     */
    public static function sendSms($mobile, $code)
    {
        try {
            // 调用FastAdmin的阿里云短信插件
            // 这里需要根据实际安装的插件调整
            $result = \app\common\library\Sms::send($mobile, $code, 'mobilelogin');
            
            if ($result) {
                return [
                    'success' => true,
                    'message' => '短信发送成功'
                ];
            } else {
                return [
                    'success' => false,
                    'message' => '短信发送失败'
                ];
            }
            
        } catch (Exception $e) {
            // 记录错误日志
            \think\Log::error('短信发送异常: ' . $e->getMessage());
            
            return [
                'success' => false,
                'message' => '短信发送异常: ' . $e->getMessage()
            ];
        }
    }
    
    /**
     * 清理过期的验证码
     * 建议定时任务调用
     * 
     * @return int 清理的记录数
     */
    public static function cleanExpiredCodes()
    {
        $count = Db::name('sms_code')
            ->where('expired_at', '<', time())
            ->delete();
        
        return $count;
    }
}
