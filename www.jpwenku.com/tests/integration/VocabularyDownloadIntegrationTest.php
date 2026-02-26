<?php

namespace tests\integration;

use tests\TestCase;
use think\Db;
use app\api\service\VocabularyService;

/**
 * 词表下载流程集成测试
 * 
 * 测试需求: 2.1-2.10
 * 测试完整的词表下载流程
 */
class VocabularyDownloadIntegrationTest extends TestCase
{
    /**
     * @test
     * 测试完整的词表下载流程
     * 
     * 验证需求:
     * - 2.1-2.3: 词表和单词数据结构
     * - 2.4-2.6: 词表创建和单词关联
     * - 2.8: 查询词表列表
     * - 2.9: 返回词表元数据
     */
    public function testCompleteVocabularyDownloadFlow()
    {
        // 准备测试数据
        $userId = $this->createTestUser();
        $this->generateTestToken($userId);

        // 步骤1: 创建词表定义
        $listId = $this->createTestVocabularyList([
            'name' => 'CET-4核心词汇',
            'description' => '大学英语四级核心词汇',
            'category' => 'CET4',
            'difficulty_level' => 2,
            'is_official' => 1,
        ]);

        $this->assertGreaterThan(0, $listId, '词表创建失败');

        // 步骤2: 添加单词到全局单词库
        $words = [];
        for ($i = 0; $i < 5; $i++) {
            $wordId = $this->createTestWord([
                'word' => 'abandon' . $i,
                'phonetic' => '/əˈbændən/',
                'part_of_speech' => 'v.',
                'definition' => '放弃；抛弃',
                'example' => 'He abandoned his wife and children.',
            ]);
            $words[] = $wordId;
        }

        $this->assertCount(5, $words, '单词创建失败');

        // 步骤3: 关联单词到词表
        foreach ($words as $index => $wordId) {
            $relationId = $this->attachWordToList($listId, $wordId, $index);
            $this->assertGreaterThan(0, $relationId, '单词关联失败');
        }

        // 更新词表单词数量
        Db::name('vocabulary_list')->where('id', $listId)->update([
            'word_count' => count($words),
        ]);

        // 步骤4: 查询词表列表
        $vocabularyService = new VocabularyService();
        $lists = $vocabularyService->getVocabularyLists();

        $this->assertIsArray($lists);
        $this->assertNotEmpty($lists);

        // 查找我们创建的词表
        $targetList = null;
        foreach ($lists as $list) {
            if ($list['id'] == $listId) {
                $targetList = $list;
                break;
            }
        }

        $this->assertNotNull($targetList, '词表列表中找不到创建的词表');

        // 验证词表元数据
        $this->assertEquals('CET-4核心词汇', $targetList['name']);
        $this->assertEquals('大学英语四级核心词汇', $targetList['description']);
        $this->assertEquals('CET4', $targetList['category']);
        $this->assertEquals(2, $targetList['difficulty_level']);
        $this->assertEquals(5, $targetList['word_count']);
        $this->assertEquals(1, $targetList['is_official']);
        $this->assertArrayHasKey('created_at', $targetList);

        // 步骤5: 下载词表详情
        $listDetail = $vocabularyService->getVocabularyListDetail($listId);

        $this->assertIsArray($listDetail);
        $this->assertEquals($listId, $listDetail['id']);
        $this->assertArrayHasKey('words', $listDetail);
        $this->assertCount(5, $listDetail['words'], '词表应该包含5个单词');

        // 验证单词数据完整性
        foreach ($listDetail['words'] as $word) {
            $this->assertArrayHasKey('id', $word);
            $this->assertArrayHasKey('word', $word);
            $this->assertArrayHasKey('phonetic', $word);
            $this->assertArrayHasKey('part_of_speech', $word);
            $this->assertArrayHasKey('definition', $word);
            $this->assertArrayHasKey('example', $word);
            $this->assertArrayHasKey('sort_order', $word);
        }

        // 步骤6: 创建用户词表关联
        $userListId = $this->createUserVocabularyList($userId, $listId);
        $this->assertGreaterThan(0, $userListId, '用户词表关联创建失败');

        // 验证用户词表关联
        $userList = Db::name('user_vocabulary_list')
            ->where('user_id', $userId)
            ->where('vocabulary_list_id', $listId)
            ->find();

        $this->assertNotEmpty($userList);
        $this->assertEquals($userId, $userList['user_id']);
        $this->assertEquals($listId, $userList['vocabulary_list_id']);
        $this->assertNotEmpty($userList['downloaded_at']);
    }

    /**
     * @test
     * 测试单词全局一致性
     * 
     * 验证需求: 2.10
     * 同一单词在多个词表中数据应该一致
     */
    public function testWordGlobalConsistency()
    {
        // 创建一个共享单词
        $sharedWordId = $this->createTestWord([
            'word' => 'hello',
            'phonetic' => '/həˈləʊ/',
            'part_of_speech' => 'int.',
            'definition' => '你好；喂',
            'example' => 'Hello, how are you?',
        ]);

        // 创建两个词表
        $list1Id = $this->createTestVocabularyList(['name' => '词表1']);
        $list2Id = $this->createTestVocabularyList(['name' => '词表2']);

        // 将同一单词关联到两个词表
        $this->attachWordToList($list1Id, $sharedWordId, 0);
        $this->attachWordToList($list2Id, $sharedWordId, 0);

        // 从两个词表获取单词数据
        $vocabularyService = new VocabularyService();
        
        $list1Detail = $vocabularyService->getVocabularyListDetail($list1Id);
        $list2Detail = $vocabularyService->getVocabularyListDetail($list2Id);

        $word1 = $list1Detail['words'][0];
        $word2 = $list2Detail['words'][0];

        // 验证单词数据一致性
        $this->assertEquals($word1['id'], $word2['id'], '单词ID应该相同');
        $this->assertEquals($word1['word'], $word2['word'], '单词文本应该相同');
        $this->assertEquals($word1['phonetic'], $word2['phonetic'], '音标应该相同');
        $this->assertEquals($word1['part_of_speech'], $word2['part_of_speech'], '词性应该相同');
        $this->assertEquals($word1['definition'], $word2['definition'], '释义应该相同');
        $this->assertEquals($word1['example'], $word2['example'], '例句应该相同');
    }

    /**
     * @test
     * 测试单词多对多关联
     * 
     * 验证需求: 2.6
     * 一个单词可以属于多个词表
     */
    public function testWordBelongsToMultipleLists()
    {
        // 创建一个单词
        $wordId = $this->createTestWord(['word' => 'test']);

        // 创建3个词表
        $list1Id = $this->createTestVocabularyList(['name' => '词表A']);
        $list2Id = $this->createTestVocabularyList(['name' => '词表B']);
        $list3Id = $this->createTestVocabularyList(['name' => '词表C']);

        // 将单词关联到3个词表
        $this->attachWordToList($list1Id, $wordId);
        $this->attachWordToList($list2Id, $wordId);
        $this->attachWordToList($list3Id, $wordId);

        // 验证关联记录
        $relations = Db::name('vocabulary_list_word')
            ->where('word_id', $wordId)
            ->select();

        $this->assertCount(3, $relations, '单词应该关联到3个词表');

        // 验证每个关联记录
        $listIds = array_column($relations, 'vocabulary_list_id');
        $this->assertContains($list1Id, $listIds);
        $this->assertContains($list2Id, $listIds);
        $this->assertContains($list3Id, $listIds);
    }

    /**
     * @test
     * 测试词表按分类查询
     * 
     * 验证需求: 2.2, 2.8
     */
    public function testQueryVocabularyListsByCategory()
    {
        // 创建不同分类的词表
        $cet4ListId = $this->createTestVocabularyList([
            'name' => 'CET-4词汇',
            'category' => 'CET4',
        ]);

        $cet6ListId = $this->createTestVocabularyList([
            'name' => 'CET-6词汇',
            'category' => 'CET6',
        ]);

        $toeflListId = $this->createTestVocabularyList([
            'name' => 'TOEFL词汇',
            'category' => 'TOEFL',
        ]);

        // 查询CET4分类的词表
        $vocabularyService = new VocabularyService();
        $cet4Lists = $vocabularyService->getVocabularyLists(['category' => 'CET4']);

        $this->assertIsArray($cet4Lists);
        
        // 验证返回的都是CET4分类
        foreach ($cet4Lists as $list) {
            if (in_array($list['id'], [$cet4ListId, $cet6ListId, $toeflListId])) {
                $this->assertEquals('CET4', $list['category']);
            }
        }
    }

    /**
     * @test
     * 测试词表单词数量统计
     * 
     * 验证需求: 2.9
     */
    public function testVocabularyListWordCount()
    {
        // 创建词表
        $listId = $this->createTestVocabularyList(['name' => '测试词表']);

        // 添加10个单词
        $wordCount = 10;
        for ($i = 0; $i < $wordCount; $i++) {
            $wordId = $this->createTestWord(['word' => 'word' . $i]);
            $this->attachWordToList($listId, $wordId, $i);
        }

        // 更新词表单词数量
        Db::name('vocabulary_list')->where('id', $listId)->update([
            'word_count' => $wordCount,
        ]);

        // 查询词表
        $vocabularyService = new VocabularyService();
        $listDetail = $vocabularyService->getVocabularyListDetail($listId);

        // 验证单词数量
        $this->assertEquals($wordCount, $listDetail['word_count']);
        $this->assertCount($wordCount, $listDetail['words']);
    }

    /**
     * @test
     * 测试用户不能重复下载同一词表
     * 
     * 验证需求: 3.7
     */
    public function testUserCannotDownloadSameListTwice()
    {
        $userId = $this->createTestUser();
        $listId = $this->createTestVocabularyList();

        // 第一次下载
        $userListId1 = $this->createUserVocabularyList($userId, $listId);
        $this->assertGreaterThan(0, $userListId1);

        // 尝试第二次下载（应该检测到已存在）
        $existingRelation = Db::name('user_vocabulary_list')
            ->where('user_id', $userId)
            ->where('vocabulary_list_id', $listId)
            ->find();

        $this->assertNotEmpty($existingRelation, '应该检测到已存在的下载记录');

        // 验证只有一条关联记录
        $relationCount = Db::name('user_vocabulary_list')
            ->where('user_id', $userId)
            ->where('vocabulary_list_id', $listId)
            ->count();

        $this->assertEquals(1, $relationCount, '应该只有一条下载记录');
    }

    /**
     * @test
     * 测试词表单词按排序顺序返回
     * 
     * 验证需求: 2.5
     */
    public function testVocabularyListWordsReturnedInOrder()
    {
        $listId = $this->createTestVocabularyList();

        // 添加单词，指定不同的排序
        $words = [];
        for ($i = 0; $i < 5; $i++) {
            $wordId = $this->createTestWord(['word' => 'word' . $i]);
            $sortOrder = 5 - $i; // 倒序排列
            $this->attachWordToList($listId, $wordId, $sortOrder);
            $words[$sortOrder] = $wordId;
        }

        // 查询词表
        $vocabularyService = new VocabularyService();
        $listDetail = $vocabularyService->getVocabularyListDetail($listId);

        // 验证单词按sort_order排序
        $previousSortOrder = -1;
        foreach ($listDetail['words'] as $word) {
            $this->assertGreaterThan($previousSortOrder, $word['sort_order'], 
                '单词应该按sort_order升序排列');
            $previousSortOrder = $word['sort_order'];
        }
    }
}
