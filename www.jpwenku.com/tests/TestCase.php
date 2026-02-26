<?php

namespace tests;

use PHPUnit\Framework\TestCase as BaseTestCase;
use think\Db;
use think\Request;

/**
 * 基础测试类
 * 提供通用的测试辅助方法
 */
abstract class TestCase extends BaseTestCase
{
    /**
     * 测试用户ID
     */
    protected $testUserId;

    /**
     * 测试用户手机号
     */
    protected $testMobile = '13800138000';

    /**
     * 测试JWT令牌
     */
    protected $testToken;

    /**
     * 设置测试环境
     */
    protected function setUp(): void
    {
        parent::setUp();
        
        // 开启事务
        Db::startTrans();
    }

    /**
     * 清理测试环境
     */
    protected function tearDown(): void
    {
        // 回滚事务
        Db::rollback();
        
        parent::tearDown();
    }

    /**
     * 创建测试用户
     * 
     * @param array $data 用户数据
     * @return int 用户ID
     */
    protected function createTestUser($data = [])
    {
        $defaultData = [
            'mobile' => $this->testMobile,
            'nickname' => '测试用户',
            'status' => 'normal',
            'created_at' => time(),
            'updated_at' => time(),
        ];

        $userData = array_merge($defaultData, $data);
        $userId = Db::name('user')->insertGetId($userData);
        
        $this->testUserId = $userId;
        
        return $userId;
    }

    /**
     * 生成测试JWT令牌
     * 
     * @param int $userId 用户ID
     * @return string JWT令牌
     */
    protected function generateTestToken($userId = null)
    {
        $userId = $userId ?? $this->testUserId;
        
        if (!$userId) {
            $userId = $this->createTestUser();
        }

        $payload = [
            'iss' => 'vocabulary-app',
            'iat' => time(),
            'exp' => time() + (30 * 24 * 60 * 60), // 30天
            'user_id' => $userId,
        ];

        $this->testToken = \Firebase\JWT\JWT::encode($payload, 'test_secret_key', 'HS256');
        
        return $this->testToken;
    }

    /**
     * 创建测试验证码
     * 
     * @param string $mobile 手机号
     * @param string $code 验证码
     * @return int 验证码ID
     */
    protected function createTestSmsCode($mobile, $code = '123456')
    {
        $data = [
            'mobile' => $mobile,
            'code' => $code,
            'created_at' => time(),
            'expired_at' => time() + 300, // 5分钟后过期
            'used' => 0,
        ];

        return Db::name('sms_code')->insertGetId($data);
    }

    /**
     * 创建测试单词
     * 
     * @param array $data 单词数据
     * @return int 单词ID
     */
    protected function createTestWord($data = [])
    {
        $defaultData = [
            'word' => 'test_' . uniqid(),
            'phonetic' => '/test/',
            'part_of_speech' => 'n.',
            'definition' => '测试单词',
            'example' => 'This is a test.',
            'created_at' => time(),
            'updated_at' => time(),
        ];

        $wordData = array_merge($defaultData, $data);
        
        return Db::name('word')->insertGetId($wordData);
    }

    /**
     * 创建测试词表
     * 
     * @param array $data 词表数据
     * @return int 词表ID
     */
    protected function createTestVocabularyList($data = [])
    {
        $defaultData = [
            'name' => '测试词表_' . uniqid(),
            'description' => '这是一个测试词表',
            'category' => 'test',
            'difficulty_level' => 1,
            'word_count' => 0,
            'is_official' => 1,
            'status' => 'normal',
            'created_at' => time(),
            'updated_at' => time(),
        ];

        $listData = array_merge($defaultData, $data);
        
        return Db::name('vocabulary_list')->insertGetId($listData);
    }

    /**
     * 关联单词到词表
     * 
     * @param int $listId 词表ID
     * @param int $wordId 单词ID
     * @param int $sortOrder 排序
     * @return int 关联ID
     */
    protected function attachWordToList($listId, $wordId, $sortOrder = 0)
    {
        $data = [
            'vocabulary_list_id' => $listId,
            'word_id' => $wordId,
            'sort_order' => $sortOrder,
            'created_at' => time(),
        ];

        return Db::name('vocabulary_list_word')->insertGetId($data);
    }

    /**
     * 创建用户词表关联
     * 
     * @param int $userId 用户ID
     * @param int $listId 词表ID
     * @return int 关联ID
     */
    protected function createUserVocabularyList($userId, $listId)
    {
        $data = [
            'user_id' => $userId,
            'vocabulary_list_id' => $listId,
            'downloaded_at' => time(),
            'is_custom' => 0,
        ];

        return Db::name('user_vocabulary_list')->insertGetId($data);
    }

    /**
     * 创建用户学习进度
     * 
     * @param int $userId 用户ID
     * @param int $wordId 单词ID
     * @param int $listId 词表ID
     * @param array $data 进度数据
     * @return int 进度ID
     */
    protected function createUserWordProgress($userId, $wordId, $listId, $data = [])
    {
        $defaultData = [
            'user_id' => $userId,
            'word_id' => $wordId,
            'vocabulary_list_id' => $listId,
            'status' => 'not_learned',
            'learned_at' => null,
            'last_review_at' => null,
            'next_review_at' => null,
            'review_count' => 0,
            'error_count' => 0,
            'memory_level' => 0,
        ];

        $progressData = array_merge($defaultData, $data);
        
        return Db::name('user_word_progress')->insertGetId($progressData);
    }

    /**
     * 模拟HTTP请求
     * 
     * @param string $method HTTP方法
     * @param string $url 请求URL
     * @param array $data 请求数据
     * @param array $headers 请求头
     * @return array 响应数据
     */
    protected function request($method, $url, $data = [], $headers = [])
    {
        // 这里简化处理，实际项目中可能需要更复杂的请求模拟
        $request = Request::instance();
        $request->method($method);
        
        if ($this->testToken && !isset($headers['Authorization'])) {
            $headers['Authorization'] = 'Bearer ' . $this->testToken;
        }

        foreach ($headers as $key => $value) {
            $request->header([$key => $value]);
        }

        return [
            'method' => $method,
            'url' => $url,
            'data' => $data,
            'headers' => $headers,
        ];
    }

    /**
     * 断言响应成功
     * 
     * @param array $response 响应数据
     */
    protected function assertResponseSuccess($response)
    {
        $this->assertIsArray($response);
        $this->assertArrayHasKey('code', $response);
        $this->assertEquals(0, $response['code'], $response['msg'] ?? '');
    }

    /**
     * 断言响应失败
     * 
     * @param array $response 响应数据
     */
    protected function assertResponseError($response)
    {
        $this->assertIsArray($response);
        $this->assertArrayHasKey('code', $response);
        $this->assertNotEquals(0, $response['code']);
    }
}
