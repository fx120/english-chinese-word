<?php

namespace app\api\model;

use think\Model;

/**
 * 短信验证码模型
 * 说明: 存储短信验证码，用于用户登录验证
 */
class SmsCode extends Model
{
    // 表名
    protected $name = 'sms_code';
    
    // 开启自动写入时间戳字段
    protected $autoWriteTimestamp = false; // 手动管理时间戳
    
    // 定义字段类型
    protected $type = [
        'id' => 'integer',
        'created_at' => 'integer',
        'expired_at' => 'integer',
        'used' => 'integer',
    ];
    
    // 验证码有效期（秒）
    const EXPIRE_TIME = 300; // 5分钟
    
    /**
     * 生成验证码
     * @param string $mobile 手机号
     * @return string 验证码
     */
    public static function generate($mobile)
    {
        // 生成6位随机数字验证码
        $code = str_pad(mt_rand(0, 999999), 6, '0', STR_PAD_LEFT);
        
        $now = time();
        
        // 创建验证码记录
        self::create([
            'mobile' => $mobile,
            'code' => $code,
            'created_at' => $now,
            'expired_at' => $now + self::EXPIRE_TIME,
            'used' => 0
        ]);
        
        return $code;
    }
    
    /**
     * 验证验证码
     * @param string $mobile 手机号
     * @param string $code 验证码
     * @return bool|string true=验证成功, false=验证失败, 字符串=错误信息
     */
    public static function verify($mobile, $code)
    {
        $now = time();
        
        // 查找最新的未使用的验证码
        $smsCode = self::where([
            'mobile' => $mobile,
            'code' => $code,
            'used' => 0
        ])
        ->where('expired_at', '>', $now)
        ->order('created_at', 'desc')
        ->find();
        
        if (!$smsCode) {
            // 检查是否是验证码错误还是过期
            $anyCode = self::where([
                'mobile' => $mobile,
                'code' => $code
            ])
            ->order('created_at', 'desc')
            ->find();
            
            if (!$anyCode) {
                return '验证码错误';
            } elseif ($anyCode->expired_at <= $now) {
                return '验证码已过期';
            } elseif ($anyCode->used == 1) {
                return '验证码已使用';
            }
            
            return '验证码无效';
        }
        
        // 标记为已使用
        $smsCode->used = 1;
        $smsCode->save();
        
        return true;
    }
    
    /**
     * 检查验证码发送频率
     * @param string $mobile 手机号
     * @param int $interval 间隔时间（秒）
     * @return bool true=可以发送, false=发送过于频繁
     */
    public static function checkFrequency($mobile, $interval = 60)
    {
        $now = time();
        
        $lastCode = self::where('mobile', $mobile)
            ->where('created_at', '>', $now - $interval)
            ->order('created_at', 'desc')
            ->find();
        
        return !$lastCode;
    }
    
    /**
     * 清理过期验证码
     * @return int 清理的数量
     */
    public static function cleanExpired()
    {
        $now = time();
        
        // 删除7天前的验证码
        return self::where('created_at', '<', $now - 7 * 86400)->delete();
    }
}
