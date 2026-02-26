<?php

/**
 * API模块公共函数文件
 */

use think\Config;

/**
 * 生成随机验证码
 * @param int $length 验证码长度
 * @param string $type 验证码类型：numeric(纯数字), alpha(纯字母), mixed(数字+字母)
 * @return string
 */
function generate_code($length = 6, $type = 'numeric')
{
    $chars = '';
    
    switch ($type) {
        case 'numeric':
            $chars = '0123456789';
            break;
        case 'alpha':
            $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
            break;
        case 'mixed':
            $chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
            break;
        default:
            $chars = '0123456789';
    }
    
    $code = '';
    $charsLen = strlen($chars);
    
    for ($i = 0; $i < $length; $i++) {
        $code .= $chars[mt_rand(0, $charsLen - 1)];
    }
    
    return $code;
}

/**
 * 验证手机号格式
 * @param string $mobile 手机号
 * @return bool
 */
function validate_mobile($mobile)
{
    return preg_match('/^1[3-9]\d{9}$/', $mobile) === 1;
}

/**
 * 验证验证码格式
 * @param string $code 验证码
 * @param int $length 验证码长度
 * @return bool
 */
function validate_code($code, $length = 6)
{
    return preg_match('/^\d{' . $length . '}$/', $code) === 1;
}

/**
 * 获取当前时间戳
 * @return int
 */
function current_timestamp()
{
    return time();
}

/**
 * 计算过期时间戳
 * @param int $seconds 秒数
 * @return int
 */
function expire_timestamp($seconds)
{
    return time() + $seconds;
}

/**
 * 检查时间戳是否过期
 * @param int $timestamp 时间戳
 * @return bool
 */
function is_expired($timestamp)
{
    return time() > $timestamp;
}

/**
 * 格式化API响应
 * @param int $code 状态码
 * @param string $msg 提示信息
 * @param mixed $data 返回数据
 * @return array
 */
function api_response($code = 0, $msg = 'success', $data = null)
{
    return [
        'code' => $code,
        'msg' => $msg,
        'data' => $data,
    ];
}

/**
 * 成功响应
 * @param string $msg 提示信息
 * @param mixed $data 返回数据
 * @return array
 */
function api_success($msg = 'success', $data = null)
{
    return api_response(0, $msg, $data);
}

/**
 * 错误响应
 * @param string $msg 错误信息
 * @param mixed $data 返回数据
 * @param int $code 错误码
 * @return array
 */
function api_error($msg = 'error', $data = null, $code = 1)
{
    return api_response($code, $msg, $data);
}

/**
 * 获取配置项
 * @param string $key 配置键名
 * @param mixed $default 默认值
 * @return mixed
 */
function api_config($key, $default = null)
{
    return Config::get($key, $default);
}
