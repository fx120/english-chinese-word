<?php

namespace addons\alioss\library;

use app\common\library\Upload;
use DateTime;
use DateTimeZone;

class Auth
{

    public function __construct()
    {

    }

    public function params($name, $md5, $callback = true)
    {
        $config = get_addon_config('alioss');
        $callback_param = array(
            'callbackUrl'      => $config['notifyurl'] ?? '',
            'callbackBody'     => 'filename=${object}&size=${size}&mimeType=${mimeType}&height=${imageInfo.height}&width=${imageInfo.width}',
            'callbackBodyType' => "application/x-www-form-urlencoded"
        );

        $jsonOptions = JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE;
        $base64_callback_body = base64_encode(json_encode($callback_param));

        $now = time();
        $end = $now + $config['expire']; //设置该policy超时时间是10s. 即这个policy过了这个有效时间，将不能访问
        $expiration = $this->gmt_iso8601($end);

        preg_match('/(\d+)(\w+)/', $config['maxsize'], $matches);
        $type = strtolower($matches[2]);
        $typeDict = ['b' => 0, 'k' => 1, 'kb' => 1, 'm' => 2, 'mb' => 2, 'gb' => 3, 'g' => 3];
        $size = (int)$config['maxsize'] * pow(1024, $typeDict[$type] ?? 0);

        //最大文件大小.用户可以自己设置
        $condition = array(0 => 'content-length-range', 1 => 0, 2 => $size);
        $conditions[] = $condition;

        //V4签名
        // 获取当前UTC时间并格式化
        $utcTime = new DateTime('now', new DateTimeZone('UTC'));
        $date = $utcTime->format('Ymd'); // 当前日期，用于签名计算
        $product = 'oss';
        $version = 'OSS4-HMAC-SHA256';
        $region = str_replace('-internal', '', substr(explode('.', $config['endpoint'])[0], 4));
        $credential = "{$config['accessKeyId']}/{$date}/{$region}/{$product}/aliyun_v4_request";

        $conditions[] = ['x-oss-signature-version' => $version];
        $conditions[] = ['x-oss-credential' => $credential];
        $conditions[] = ['x-oss-date' => $utcTime->format('Ymd\THis\Z')];

        $arr = ['expiration' => $expiration, 'conditions' => $conditions];

        $policy = base64_encode(json_encode($arr, $jsonOptions));

        // 计算签名所需的信息
        $signingKey = "aliyun_v4" . $config['accessKeySecret']; // 构造签名密钥
        $h1Key = $this->hmacSign($signingKey, $date); // 第一步：对日期签名
        $h2Key = $this->hmacSign($h1Key, $region);   // 第二步：对区域签名
        $h3Key = $this->hmacSign($h2Key, $product);  // 第三步：对产品签名
        $h4Key = $this->hmacSign($h3Key, "aliyun_v4_request"); // 第四步：对请求签名

        // 计算最终签名
        $signature = hash_hmac('sha256', $policy, $h4Key);


        $key = (new Upload())->getSavekey($config['savekey'], $name, $md5);
        $key = ltrim($key, "/");

        $response = array();
        $response['id'] = $config['accessKeyId'];
        $response['key'] = $key;
        $response['policy'] = $policy;
        $response['expire'] = $end;
        $response['callback'] = '';
        $response['x-oss-signature-version'] = $version;
        $response['x-oss-credential'] = $credential;
        $response['x-oss-date'] = $utcTime->format('Ymd\THis\Z');
        $response['x-oss-signature'] = $signature;
        return $response;
    }

    public function check($signature, $policy)
    {
        $config = get_addon_config('alioss');
        $sign = base64_encode(hash_hmac('sha1', $policy, $config['accessKeySecret'], true));
        return $signature == $sign;
    }

    private function hmacSign($key, $data)
    {
        return hash_hmac('sha256', $data, $key, true);
    }

    private function gmt_iso8601($time)
    {
        $dtStr = date("c", $time);
        $mydatetime = new \DateTime($dtStr);
        $expiration = $mydatetime->format(\DateTime::ISO8601);
        $pos = strpos($expiration, '+');
        $expiration = substr($expiration, 0, $pos);
        return $expiration . "Z";
    }

    public static function isModuleAllow()
    {
        $config = get_addon_config('alioss');
        $module = request()->module();
        $module = $module ? strtolower($module) : 'index';
        $noNeedLogin = array_filter(explode(',', $config['noneedlogin'] ?? ''));
        $isModuleLogin = false;
        $tagName = 'upload_config_checklogin';
        foreach (\think\Hook::get($tagName) as $index => $name) {
            if (\think\Hook::exec($name, $tagName)) {
                $isModuleLogin = true;
                break;
            }
        }
        if (in_array($module, $noNeedLogin)
            || ($module == 'admin' && \app\admin\library\Auth::instance()->id)
            || ($module != 'admin' && \app\common\library\Auth::instance()->id)
            || $isModuleLogin) {
            return true;
        } else {
            return false;
        }
    }

}
