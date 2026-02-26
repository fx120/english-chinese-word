<?php

namespace app\api\controller;

use app\common\controller\Api;
use app\common\library\Auth as AuthLib;
use app\common\library\Sms as Smslib;
use app\common\model\User;
use think\Db;
use think\Hook;

/**
 * 用户认证控制器
 * 使用FastAdmin原生Auth库管理token
 */
class Auth extends Api
{
    protected $noNeedLogin = ['sendCode', 'login', 'loginByPassword'];
    protected $noNeedRight = '*';

    public function _initialize()
    {
        $corsResponse = \app\api\library\Cors::handle();
        if ($corsResponse !== null) {
            $corsResponse->send();
            exit;
        }
        parent::_initialize();
    }

    /**
     * 发送短信验证码
     */
    public function sendCode()
    {
        $mobile = $this->request->post('mobile');

        if (!$mobile || !\think\Validate::regex($mobile, "^1\d{10}$")) {
            $this->error('手机号格式不正确');
        }

        $last = Smslib::get($mobile, 'mobilelogin');
        if ($last && time() - $last['createtime'] < 60) {
            $this->error('发送过于频繁，请稍后再试');
        }

        $ipSendTotal = \app\common\model\Sms::where(['ip' => $this->request->ip()])
            ->whereTime('createtime', '-1 hours')
            ->count();
        if ($ipSendTotal >= 5) {
            $this->error('发送过于频繁，请稍后再试');
        }

        if (!Hook::get('sms_send')) {
            $this->error('短信服务未配置，请联系管理员');
        }

        $ret = Smslib::send($mobile, null, 'mobilelogin');

        if ($ret) {
            $this->success('验证码已发送');
        } else {
            $this->error('验证码发送失败，请稍后重试');
        }
    }

    /**
     * 验证码登录
     */
    public function login()
    {
        $mobile = $this->request->post('mobile');
        $code = $this->request->post('code');
        
        \think\Log::info('[Auth.login] 收到登录请求, mobile=' . $mobile . ', code=' . $code);
        \think\Log::info('[Auth.login] POST数据: ' . json_encode($this->request->post()));
        \think\Log::info('[Auth.login] Content-Type: ' . $this->request->header('content-type'));

        if (!$mobile || !\think\Validate::regex($mobile, "^1\d{10}$")) {
            \think\Log::info('[Auth.login] 手机号格式不正确');
            $this->error('手机号格式不正确');
        }

        if (!$code || !preg_match('/^\d{4,6}$/', $code)) {
            \think\Log::info('[Auth.login] 验证码格式不正确, code=' . var_export($code, true));
            $this->error('验证码格式不正确');
        }

        \think\Log::info('[Auth.login] 开始验证验证码');
        $ret = Smslib::check($mobile, $code, 'mobilelogin');
        \think\Log::info('[Auth.login] Smslib::check 结果: ' . var_export($ret, true));
        if (!$ret) {
            $this->error('验证码不正确');
        }

        Smslib::flush($mobile, 'mobilelogin');

        // 查找或注册用户
        $user = User::getByMobile($mobile);
        $auth = AuthLib::instance();
        
        \think\Log::info('[Auth.login] 查找用户, mobile=' . $mobile . ', 用户存在=' . ($user ? 'yes, id=' . $user->id : 'no'));

        if (!$user) {
            $username = $mobile;
            $password = \fast\Random::alnum(8);
            \think\Log::info('[Auth.login] 新用户注册, username=' . $username);
            $ret = $auth->register($username, $password, '', $mobile, [
                'nickname' => '用户' . substr($mobile, -4),
            ]);
            \think\Log::info('[Auth.login] 注册结果: ' . var_export($ret, true) . ', error: ' . $auth->getError());
            if (!$ret) {
                $this->error('注册失败: ' . $auth->getError());
            }
        } else {
            \think\Log::info('[Auth.login] 已有用户, 调用direct登录, user_id=' . $user->id);
            $ret = $auth->direct($user->id);
            \think\Log::info('[Auth.login] direct结果: ' . var_export($ret, true) . ', error: ' . $auth->getError());
            if (!$ret) {
                $this->error('登录失败: ' . $auth->getError());
            }
        }

        $userinfo = $auth->getUserinfo();
        $token = $auth->getToken();
        \think\Log::info('[Auth.login] 登录成功, token=' . $token . ', userinfo=' . json_encode($userinfo));

        $this->success('登录成功', [
            'token' => $auth->getToken(),
            'user' => [
                'id' => $userinfo['id'],
                'mobile' => $userinfo['mobile'],
                'nickname' => $userinfo['nickname'],
                'avatar' => $userinfo['avatar'],
                'email' => $userinfo['email'] ?? '',
                'gender' => intval($userinfo['gender'] ?? 0),
                'birthday' => $userinfo['birthday'] ?? null,
                'bio' => $userinfo['bio'] ?? '',
                'created_at' => $userinfo['createtime'] ?? time(),
            ]
        ]);
    }

    /**
     * 用户名密码登录
     */
    public function loginByPassword()
    {
        $account = $this->request->post('account');
        $password = $this->request->post('password');

        if (!$account) {
            $this->error('请输入用户名或手机号');
        }

        if (!$password) {
            $this->error('请输入密码');
        }

        $auth = AuthLib::instance();
        $ret = $auth->login($account, $password);

        if (!$ret) {
            $this->error('用户名或密码错误: ' . $auth->getError());
        }

        $userinfo = $auth->getUserinfo();

        $this->success('登录成功', [
            'token' => $auth->getToken(),
            'user' => [
                'id' => $userinfo['id'],
                'mobile' => $userinfo['mobile'] ?? '',
                'nickname' => $userinfo['nickname'],
                'avatar' => $userinfo['avatar'],
                'email' => $userinfo['email'] ?? '',
                'gender' => intval($userinfo['gender'] ?? 0),
                'birthday' => $userinfo['birthday'] ?? null,
                'bio' => $userinfo['bio'] ?? '',
                'created_at' => $userinfo['createtime'] ?? time(),
            ]
        ]);
    }

    /**
     * 登出
     */
    public function logout()
    {
        if (!$this->auth->isLogin()) {
            $this->success('已登出');
            return;
        }

        $this->auth->logout();
        $this->success('登出成功');
    }

    /**
     * 刷新token（重新登录延长有效期）
     */
    public function refresh()
    {
        if (!$this->auth->isLogin()) {
            $this->error('未登录', null, 401);
        }

        // 直接用当前用户ID重新登录，生成新token
        $userId = $this->auth->id;
        $this->auth->logout();

        $auth = AuthLib::instance();
        $ret = $auth->direct($userId);

        if (!$ret) {
            $this->error('刷新失败', null, 401);
        }

        $this->success('刷新成功', [
            'token' => $auth->getToken()
        ]);
    }

    /**
     * 更新用户资料
     */
    public function updateProfile()
    {
        $userId = $this->auth->id;
        
        $allowFields = ['nickname', 'email', 'gender', 'birthday', 'bio'];
        $data = [];
        
        foreach ($allowFields as $field) {
            $value = $this->request->post($field);
            if ($value !== null) {
                $data[$field] = $value;
            }
        }
        
        if (empty($data)) {
            $this->error('没有需要更新的数据');
        }
        
        // 验证性别值
        if (isset($data['gender'])) {
            $data['gender'] = intval($data['gender']);
            if (!in_array($data['gender'], [0, 1, 2])) {
                $this->error('性别值不正确');
            }
        }
        
        // 验证邮箱格式
        if (isset($data['email']) && !empty($data['email'])) {
            if (!\think\Validate::is($data['email'], 'email')) {
                $this->error('邮箱格式不正确');
            }
        }
        
        // 验证生日格式
        if (isset($data['birthday']) && !empty($data['birthday'])) {
            if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $data['birthday'])) {
                $this->error('生日格式不正确，请使用 YYYY-MM-DD 格式');
            }
        }
        
        // 昵称长度限制
        if (isset($data['nickname'])) {
            if (mb_strlen($data['nickname']) > 20) {
                $this->error('昵称不能超过20个字符');
            }
        }
        
        // 个性签名长度限制
        if (isset($data['bio'])) {
            if (mb_strlen($data['bio']) > 100) {
                $this->error('个性签名不能超过100个字符');
            }
        }
        
        $data['updatetime'] = time();
        
        $ret = Db::name('user')->where('id', $userId)->update($data);
        
        if ($ret === false) {
            $this->error('更新失败');
        }
        
        // 返回更新后的用户信息
        $userinfo = Db::name('user')
            ->where('id', $userId)
            ->field('id,mobile,nickname,avatar,email,gender,birthday,bio,createtime')
            ->find();
        
        $this->success('更新成功', [
            'user' => [
                'id' => $userinfo['id'],
                'mobile' => $userinfo['mobile'],
                'nickname' => $userinfo['nickname'],
                'avatar' => $userinfo['avatar'],
                'email' => $userinfo['email'],
                'gender' => intval($userinfo['gender']),
                'birthday' => $userinfo['birthday'],
                'bio' => $userinfo['bio'],
                'created_at' => $userinfo['createtime'] ?? time(),
            ]
        ]);
    }

    /**
     * 获取当前用户信息
     */
    public function getUserInfo()
    {
        $userId = $this->auth->id;
        
        $userinfo = Db::name('user')
            ->where('id', $userId)
            ->field('id,mobile,nickname,avatar,email,gender,birthday,bio,createtime')
            ->find();
        
        if (!$userinfo) {
            $this->error('用户不存在');
        }
        
        $this->success('success', [
            'user' => [
                'id' => $userinfo['id'],
                'mobile' => $userinfo['mobile'],
                'nickname' => $userinfo['nickname'],
                'avatar' => $userinfo['avatar'],
                'email' => $userinfo['email'],
                'gender' => intval($userinfo['gender']),
                'birthday' => $userinfo['birthday'],
                'bio' => $userinfo['bio'],
                'created_at' => $userinfo['createtime'] ?? time(),
            ]
        ]);
    }
}
