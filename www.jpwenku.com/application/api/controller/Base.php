<?php

namespace app\api\controller;

use app\common\controller\Api;
use app\api\library\Auth;
use app\api\library\Cors;
use think\exception\HttpResponseException;
use think\Response;

/**
 * API基础控制器（需要JWT认证）
 * 所有需要认证的API控制器都应该继承此类
 */
class Base extends Api
{
    /**
     * 无需登录的方法，可在子类中重写
     * @var array
     */
    protected $noNeedLogin = [];
    
    /**
     * 无需鉴权的方法
     * @var array
     */
    protected $noNeedRight = '*';
    
    /**
     * 当前登录用户ID
     * @var int
     */
    protected $userId = 0;
    
    /**
     * 当前登录用户信息
     * @var object
     */
    protected $user = null;
    
    /**
     * 初始化
     */
    public function _initialize()
    {
        // 处理CORS跨域请求
        $corsResponse = Cors::handle();
        if ($corsResponse !== null) {
            // OPTIONS预检请求直接返回
            $corsResponse->send();
            exit;
        }
        
        parent::_initialize();
        
        // 获取当前请求的方法名
        $action = $this->request->action();
        
        // 检查是否需要登录
        if (!in_array($action, $this->noNeedLogin)) {
            $this->checkAuth();
        }
    }
    
    /**
     * 检查JWT认证
     */
    protected function checkAuth()
    {
        $token = Auth::getTokenFromHeader();
        
        if (!$token) {
            $this->error('未提供认证令牌', null, 401);
        }
        
        $decoded = Auth::verifyToken($token);
        
        if (!$decoded) {
            $this->error('认证令牌无效或已过期', null, 401);
        }
        
        $this->userId = $decoded->uid ?? 0;
        
        if (!$this->userId) {
            $this->error('认证令牌格式错误', null, 401);
        }
        
        // 可以在这里加载用户信息
        // $this->user = \app\common\model\User::get($this->userId);
    }
    
    /**
     * 返回成功响应
     * @param string $msg 提示信息
     * @param mixed $data 返回数据
     * @param int $code 状态码
     */
    protected function success($msg = 'success', $data = null, $code = 0)
    {
        $result = [
            'code' => $code,
            'msg' => $msg,
            'data' => $data,
        ];
        
        $response = Response::create($result, 'json');
        $response = Cors::setHeaders($response);
        
        throw new HttpResponseException($response);
    }
    
    /**
     * 返回错误响应
     * @param string $msg 错误信息
     * @param mixed $data 返回数据
     * @param int $code 错误码
     */
    protected function error($msg = 'error', $data = null, $code = 1)
    {
        $result = [
            'code' => $code,
            'msg' => $msg,
            'data' => $data,
        ];
        
        $response = Response::create($result, 'json');
        $response = Cors::setHeaders($response);
        
        throw new HttpResponseException($response);
    }
}
