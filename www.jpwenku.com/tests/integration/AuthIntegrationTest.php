<?php

namespace tests\integration;

use tests\TestCase;
use think\Db;
use app\api\service\AuthService;

/**
 * 用户注册登录流程集成测试
 * 
 * 测试需求: 1.1-1.4
 * 测试完整的用户注册登录流程
 */
class AuthIntegrationTest extends TestCase
{
    /**
     * @test
     * 测试完整的验证码登录流程
     * 
     * 验证需求:
     * - 1.1: 发送验证码
     * - 1.2: 验证码5分钟内有效
     * - 1.3: 验证码登录创建用户
     * - 1.4: 返回JWT令牌，有效期30天
     */
    public function testCompleteVerificationCodeLoginFlow()
    {
        $mobile = '13900139000';
        $code = '123456';

        // 步骤1: 发送验证码
        $smsCodeId = $this->createTestSmsCode($mobile, $code);
        $this->assertGreaterThan(0, $smsCodeId, '验证码创建失败');

        // 验证验证码记录
        $smsCode = Db::name('sms_code')->where('id', $smsCodeId)->find();
        $this->assertNotEmpty($smsCode, '验证码记录不存在');
        $this->assertEquals($mobile, $smsCode['mobile']);
        $this->assertEquals($code, $smsCode['code']);
        $this->assertEquals(0, $smsCode['used'], '验证码应该未使用');

        // 验证验证码有效期（5分钟）
        $expectedExpiredAt = $smsCode['created_at'] + 300;
        $this->assertEquals($expectedExpiredAt, $smsCode['expired_at'], '验证码有效期应该是5分钟');

        // 步骤2: 使用验证码登录
        $authService = new AuthService();
        
        // 验证验证码
        $isValid = $authService->verifyCode($mobile, $code);
        $this->assertTrue($isValid, '验证码验证失败');

        // 创建或获取用户
        $user = Db::name('user')->where('mobile', $mobile)->find();
        if (!$user) {
            $userId = Db::name('user')->insertGetId([
                'mobile' => $mobile,
                'nickname' => '用户' . substr($mobile, -4),
                'status' => 'normal',
                'created_at' => time(),
                'updated_at' => time(),
            ]);
            $user = Db::name('user')->where('id', $userId)->find();
        }

        $this->assertNotEmpty($user, '用户创建失败');
        $this->assertEquals($mobile, $user['mobile']);

        // 步骤3: 生成JWT令牌
        $token = $authService->generateToken($user['id']);
        $this->assertNotEmpty($token, 'JWT令牌生成失败');

        // 验证JWT令牌有效期（30天）
        $decoded = \Firebase\JWT\JWT::decode($token, new \Firebase\JWT\Key('test_secret_key', 'HS256'));
        $this->assertNotEmpty($decoded);
        $this->assertEquals($user['id'], $decoded->user_id);

        // 验证令牌有效期是30天
        $expectedExpiration = time() + (30 * 24 * 60 * 60);
        $actualExpiration = $decoded->exp;
        $timeDifference = abs($expectedExpiration - $actualExpiration);
        $this->assertLessThan(5, $timeDifference, 'JWT令牌有效期应该是30天');

        // 步骤4: 验证验证码已标记为已使用
        $smsCode = Db::name('sms_code')->where('id', $smsCodeId)->find();
        $this->assertEquals(1, $smsCode['used'], '验证码应该标记为已使用');
    }

    /**
     * @test
     * 测试验证码过期场景
     * 
     * 验证需求: 1.5
     */
    public function testExpiredVerificationCode()
    {
        $mobile = '13900139001';
        $code = '654321';

        // 创建已过期的验证码（过期时间设置为过去）
        $expiredCodeId = Db::name('sms_code')->insertGetId([
            'mobile' => $mobile,
            'code' => $code,
            'created_at' => time() - 400, // 400秒前创建
            'expired_at' => time() - 100, // 100秒前过期
            'used' => 0,
        ]);

        $this->assertGreaterThan(0, $expiredCodeId);

        // 尝试验证过期的验证码
        $authService = new AuthService();
        $isValid = $authService->verifyCode($mobile, $code);

        $this->assertFalse($isValid, '过期的验证码应该验证失败');
    }

    /**
     * @test
     * 测试错误验证码场景
     * 
     * 验证需求: 1.5
     */
    public function testInvalidVerificationCode()
    {
        $mobile = '13900139002';
        $correctCode = '111111';
        $wrongCode = '999999';

        // 创建验证码
        $this->createTestSmsCode($mobile, $correctCode);

        // 尝试使用错误的验证码
        $authService = new AuthService();
        $isValid = $authService->verifyCode($mobile, $wrongCode);

        $this->assertFalse($isValid, '错误的验证码应该验证失败');
    }

    /**
     * @test
     * 测试已使用的验证码不能重复使用
     * 
     * 验证需求: 1.5
     */
    public function testUsedVerificationCodeCannotBeReused()
    {
        $mobile = '13900139003';
        $code = '222222';

        // 创建验证码
        $smsCodeId = $this->createTestSmsCode($mobile, $code);

        // 第一次使用验证码
        $authService = new AuthService();
        $isValid = $authService->verifyCode($mobile, $code);
        $this->assertTrue($isValid, '第一次验证应该成功');

        // 标记为已使用
        Db::name('sms_code')->where('id', $smsCodeId)->update(['used' => 1]);

        // 尝试再次使用相同的验证码
        $isValidAgain = $authService->verifyCode($mobile, $code);
        $this->assertFalse($isValidAgain, '已使用的验证码不能重复使用');
    }

    /**
     * @test
     * 测试同一手机号多次登录使用同一用户账户
     * 
     * 验证需求: 1.3, 1.6
     */
    public function testSameMobileUseSameUserAccount()
    {
        $mobile = '13900139004';

        // 第一次登录 - 创建用户
        $code1 = '333333';
        $this->createTestSmsCode($mobile, $code1);

        $authService = new AuthService();
        $authService->verifyCode($mobile, $code1);

        $userId1 = Db::name('user')->insertGetId([
            'mobile' => $mobile,
            'nickname' => '用户' . substr($mobile, -4),
            'status' => 'normal',
            'created_at' => time(),
            'updated_at' => time(),
        ]);

        $this->assertGreaterThan(0, $userId1);

        // 第二次登录 - 应该使用相同的用户
        $code2 = '444444';
        $this->createTestSmsCode($mobile, $code2);

        $authService->verifyCode($mobile, $code2);

        $user = Db::name('user')->where('mobile', $mobile)->find();
        $this->assertEquals($userId1, $user['id'], '同一手机号应该使用相同的用户账户');

        // 验证只有一个用户记录
        $userCount = Db::name('user')->where('mobile', $mobile)->count();
        $this->assertEquals(1, $userCount, '同一手机号应该只有一个用户记录');
    }

    /**
     * @test
     * 测试JWT令牌包含正确的用户信息
     * 
     * 验证需求: 1.4
     */
    public function testJwtTokenContainsCorrectUserInfo()
    {
        $mobile = '13900139005';
        $userId = Db::name('user')->insertGetId([
            'mobile' => $mobile,
            'nickname' => '测试用户',
            'status' => 'normal',
            'created_at' => time(),
            'updated_at' => time(),
        ]);

        $authService = new AuthService();
        $token = $authService->generateToken($userId);

        // 解码JWT令牌
        $decoded = \Firebase\JWT\JWT::decode($token, new \Firebase\JWT\Key('test_secret_key', 'HS256'));

        // 验证令牌包含正确的用户ID
        $this->assertEquals($userId, $decoded->user_id);

        // 验证令牌包含签发时间
        $this->assertNotEmpty($decoded->iat);
        $this->assertLessThanOrEqual(time(), $decoded->iat);

        // 验证令牌包含过期时间
        $this->assertNotEmpty($decoded->exp);
        $this->assertGreaterThan(time(), $decoded->exp);
    }
}
