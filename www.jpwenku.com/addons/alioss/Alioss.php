<?php

namespace addons\alioss;

use addons\alioss\library\Auth;
use OSS\Core\OssException;
use OSS\OssClient;
use think\Addons;
use think\App;
use think\Config;
use think\Loader;

/**
 * 阿里云OSS上传插件
 */
class Alioss extends Addons
{

    /**
     * 插件安装方法
     * @return bool
     */
    public function install()
    {
        return true;
    }

    /**
     * 插件卸载方法
     * @return bool
     */
    public function uninstall()
    {
        return true;
    }

    /**
     * 添加命名空间
     */
    public function appInit()
    {
        if (!class_exists("\OSS\OssClient")) {
            //添加支付包的命名空间
            Loader::addNamespace('OSS', ADDON_PATH . 'alioss' . DS . 'library' . DS . 'OSS' . DS);
        }
    }

    /**
     * 判断是否来源于API上传
     */
    public function moduleInit($request)
    {
        $config = $this->getConfig();
        $module = strtolower($request->module());
        // 判断api/common/upload 是否使用云存储上传
        if ($module == 'api' && ($config['apiupload'] ?? 0) &&
            strtolower($request->controller()) == 'common' &&
            strtolower($request->action()) == 'upload') {
            request()->param('isApi', true);
            App::invokeMethod(["\\addons\\alioss\\controller\\Index", "upload"], ['isApi' => true]);
        }
    }

    /**
     * 加载配置
     */
    public function uploadConfigInit(&$upload)
    {
        $config = $this->getConfig();

        $data = ['deadline' => time() + $config['expire']];
        $signature = hash_hmac('sha1', json_encode($data), $config['accessKeySecret'], true);

        $token = '';
        if (Auth::isModuleAllow()) {
            $token = $config['accessKeyId'] . ':' . base64_encode($signature) . ':' . base64_encode(json_encode($data));
        }
        $multipart = [
            'aliosstoken' => $token
        ];
        $config['uploadurl'] = 'https://' . $config['bucket'] . '.' . $config['endpoint'];
        $upload = array_merge($upload, [
            'cdnurl'     => $config['cdnurl'],
            'uploadurl'  => $config['uploadmode'] == 'client' ? $config['uploadurl'] : addon_url('alioss/index/upload', [], false, true),
            'uploadmode' => $config['uploadmode'],
            'bucket'     => $config['bucket'],
            'maxsize'    => $config['maxsize'],
            'mimetype'   => $config['mimetype'],
            'savekey'    => $config['savekey'],
            'chunking'   => (bool)($config['chunking'] ?? $upload['chunking']),
            'chunksize'  => (int)($config['chunksize'] ?? $upload['chunksize']),
            'multipart'  => $multipart,
            'storage'    => $this->getName(),
            'multiple'   => (bool)$config['multiple'],
        ]);
    }

    /**
     * 附件删除后
     */
    public function uploadDelete($attachment)
    {
        $config = $this->getConfig();
        if ($attachment['storage'] == 'alioss' && isset($config['syncdelete']) && $config['syncdelete']) {
            // 删除云存储端文件
            try {
                $ossClient = new OssClient($config['accessKeyId'], $config['accessKeySecret'], $config['endpoint']);
                $ossClient->deleteObject($config['bucket'], ltrim($attachment->url, '/'));
            } catch (OssException $e) {
                return false;
            }

            //如果是服务端中转，还需要删除本地文件
            //if ($config['uploadmode'] == 'server') {
            //    $filePath = ROOT_PATH . 'public' . str_replace('/', DS, $attachment->url);
            //    if ($filePath) {
            //        @unlink($filePath);
            //    }
            //}
        }
        return true;
    }

}
