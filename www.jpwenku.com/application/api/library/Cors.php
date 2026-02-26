<?php

namespace app\api\library;

use think\Config;
use think\Response;

/**
 * CORS跨域处理类
 */
class Cors
{
    /**
     * 处理CORS跨域请求
     * @return Response|null
     */
    public static function handle()
    {
        $config = Config::get('cors');
        
        // 如果未启用CORS，直接返回
        if (!$config['enable']) {
            return null;
        }
        
        // 获取请求来源
        $origin = request()->header('Origin');
        
        // 设置CORS响应头
        header('Access-Control-Allow-Origin: ' . $config['allow_origin']);
        header('Access-Control-Allow-Methods: ' . $config['allow_methods']);
        header('Access-Control-Allow-Headers: ' . $config['allow_headers']);
        
        if ($config['allow_credentials']) {
            header('Access-Control-Allow-Credentials: true');
        }
        
        header('Access-Control-Max-Age: ' . $config['max_age']);
        
        // 处理OPTIONS预检请求
        if (request()->isOptions()) {
            return Response::create('', 'html', 204);
        }
        
        return null;
    }
    
    /**
     * 设置CORS响应头（用于响应对象）
     * @param Response $response 响应对象
     * @return Response
     */
    public static function setHeaders($response)
    {
        $config = Config::get('cors');
        
        if (!$config['enable']) {
            return $response;
        }
        
        $response->header([
            'Access-Control-Allow-Origin' => $config['allow_origin'],
            'Access-Control-Allow-Methods' => $config['allow_methods'],
            'Access-Control-Allow-Headers' => $config['allow_headers'],
            'Access-Control-Allow-Credentials' => $config['allow_credentials'] ? 'true' : 'false',
            'Access-Control-Max-Age' => $config['max_age'],
        ]);
        
        return $response;
    }
}
