<?php

namespace app\common\library;

use fast\Random;
use think\Hook;

/**
 * 短信验证码类
 */
class Sms
{

    /**
     * 验证码有效时长
     * @var int
     */
    protected static $expire = 300;

    /**
     * 最大允许检测的次数
     * @var int
     */
    protected static $maxCheckNums = 10;

    /**
     * 获取最后一次手机发送的数据
     *
     * @param   int    $mobile 手机号
     * @param   string $event  事件
     * @return  Sms
     */
    public static function get($mobile, $event = 'default')
    {
        $sms = \app\common\model\Sms::where(['mobile' => $mobile, 'event' => $event])
            ->order('id', 'DESC')
            ->find();
        Hook::listen('sms_get', $sms, null, true);
        return $sms ?: null;
    }

    /**
     * 发送验证码
     *
     * @param   int    $mobile 手机号
     * @param   int    $code   验证码,为空时将自动生成4位数字
     * @param   string $event  事件
     * @return  boolean
     */
    public static function send($mobile, $code = null, $event = 'default')
    {
        $code = is_null($code) ? Random::numeric(6) : $code;
        $time = time();
        $ip = request()->ip();
        \think\Log::info('[Smslib::send] mobile=' . $mobile . ', code=' . $code . ', event=' . $event);
        $sms = \app\common\model\Sms::create(['event' => $event, 'mobile' => $mobile, 'code' => $code, 'ip' => $ip, 'createtime' => $time]);
        \think\Log::info('[Smslib::send] sms记录已创建, id=' . $sms->id);
        \think\Log::info('[Smslib::send] 触发sms_send hook, sms数据: ' . json_encode($sms->toArray()));
        $result = Hook::listen('sms_send', $sms, null, true);
        \think\Log::info('[Smslib::send] hook返回结果: ' . var_export($result, true));
        if (!$result) {
            // 即使发送失败也保留验证码记录（方便测试环境使用）
            \think\Log::info('[Smslib::send] hook返回false, 短信发送失败但保留验证码记录, code=' . $code);
        }
        return true;
    }

    /**
     * 发送通知
     *
     * @param   mixed  $mobile   手机号,多个以,分隔
     * @param   string $msg      消息内容
     * @param   string $template 消息模板
     * @return  boolean
     */
    public static function notice($mobile, $msg = '', $template = null)
    {
        $params = [
            'mobile'   => $mobile,
            'msg'      => $msg,
            'template' => $template
        ];
        $result = Hook::listen('sms_notice', $params, null, true);
        return (bool)$result;
    }

    /**
     * 校验验证码
     *
     * @param   int    $mobile 手机号
     * @param   int    $code   验证码
     * @param   string $event  事件
     * @return  boolean
     */
    public static function check($mobile, $code, $event = 'default')
    {
        $time = time() - self::$expire;
        $sms = \app\common\model\Sms::where(['mobile' => $mobile, 'event' => $event])
            ->order('id', 'DESC')
            ->find();
        \think\Log::info('[Smslib::check] mobile=' . $mobile . ', code=' . $code . ', event=' . $event);
        \think\Log::info('[Smslib::check] 查询到sms记录: ' . ($sms ? json_encode($sms->toArray()) : 'NULL'));
        \think\Log::info('[Smslib::check] 过期时间阈值: ' . $time . ', 当前时间: ' . time());
        if ($sms) {
            \think\Log::info('[Smslib::check] sms.createtime=' . $sms['createtime'] . ', sms.times=' . $sms['times'] . ', sms.code=' . $sms['code']);
            \think\Log::info('[Smslib::check] 未过期=' . ($sms['createtime'] > $time ? 'yes' : 'no') . ', 未超次数=' . ($sms['times'] <= self::$maxCheckNums ? 'yes' : 'no'));
            if ($sms['createtime'] > $time && $sms['times'] <= self::$maxCheckNums) {
                $correct = $code == $sms['code'];
                \think\Log::info('[Smslib::check] 验证码比对: input=' . $code . ', db=' . $sms['code'] . ', correct=' . ($correct ? 'yes' : 'no'));
                if (!$correct) {
                    $sms->times = $sms->times + 1;
                    $sms->save();
                    return false;
                } else {
                    $result = Hook::listen('sms_check', $sms, null, true);
                    \think\Log::info('[Smslib::check] sms_check hook结果: ' . var_export($result, true));
                    return $result;
                }
            } else {
                \think\Log::info('[Smslib::check] 验证码已过期或超过最大检测次数，清空');
                self::flush($mobile, $event);
                return false;
            }
        } else {
            \think\Log::info('[Smslib::check] 未找到验证码记录');
            return false;
        }
    }

    /**
     * 清空指定手机号验证码
     *
     * @param   int    $mobile 手机号
     * @param   string $event  事件
     * @return  boolean
     */
    public static function flush($mobile, $event = 'default')
    {
        \app\common\model\Sms::where(['mobile' => $mobile, 'event' => $event])
            ->delete();
        Hook::listen('sms_flush');
        return true;
    }
}
