<?php

namespace app\api\service;

use think\Db;
use think\Exception;
use app\api\model\Word;

/**
 * 单词服务类
 * 处理单词CRUD、单词去重、单词批量导入等业务逻辑
 */
class WordService
{
    /**
     * 创建单词（如果已存在则返回现有单词）
     * 
     * @param array $data 单词数据
     * @return array ['success' => bool, 'message' => string, 'word_id' => int|null, 'is_new' => bool]
     */
    public static function create($data)
    {
        // 验证必填字段
        if (empty($data['word'])) {
            return [
                'success' => false,
                'message' => '单词不能为空',
                'word_id' => null,
                'is_new' => false
            ];
        }
        
        if (empty($data['definition'])) {
            return [
                'success' => false,
                'message' => '释义不能为空',
                'word_id' => null,
                'is_new' => false
            ];
        }
        
        // 检查单词是否已存在
        $existingWord = Db::name('word')
            ->where('word', $data['word'])
            ->find();
        
        if ($existingWord) {
            return [
                'success' => true,
                'message' => '单词已存在',
                'word_id' => $existingWord['id'],
                'is_new' => false
            ];
        }
        
        // 创建新单词
        try {
            $wordData = [
                'word' => $data['word'],
                'phonetic' => $data['phonetic'] ?? null,
                'part_of_speech' => $data['part_of_speech'] ?? null,
                'definition' => $data['definition'],
                'example' => $data['example'] ?? null,
                'created_at' => time(),
                'updated_at' => time()
            ];
            
            $wordId = Db::name('word')->insertGetId($wordData);
            
            return [
                'success' => true,
                'message' => '单词创建成功',
                'word_id' => $wordId,
                'is_new' => true
            ];
            
        } catch (Exception $e) {
            return [
                'success' => false,
                'message' => '单词创建失败: ' . $e->getMessage(),
                'word_id' => null,
                'is_new' => false
            ];
        }
    }
    
    /**
     * 查找或创建单词
     * 
     * @param string $word 单词文本
     * @param array $data 单词数据（如果需要创建）
     * @return array ['success' => bool, 'message' => string, 'word_id' => int|null]
     */
    public static function findOrCreate($word, $data = [])
    {
        // 先查找
        $existingWord = Db::name('word')
            ->where('word', $word)
            ->find();
        
        if ($existingWord) {
            return [
                'success' => true,
                'message' => '单词已存在',
                'word_id' => $existingWord['id']
            ];
        }
        
        // 不存在则创建
        $data['word'] = $word;
        $result = self::create($data);
        
        return [
            'success' => $result['success'],
            'message' => $result['message'],
            'word_id' => $result['word_id']
        ];
    }
    
    /**
     * 批量创建或查找单词
     * 
     * @param array $words 单词数据数组
     * @return array ['success' => bool, 'message' => string, 'word_ids' => array, 'stats' => array]
     */
    public static function batchCreate($words)
    {
        if (empty($words) || !is_array($words)) {
            return [
                'success' => false,
                'message' => '单词列表不能为空',
                'word_ids' => [],
                'stats' => ['total' => 0, 'created' => 0, 'existing' => 0, 'failed' => 0]
            ];
        }
        
        $wordIds = [];
        $stats = [
            'total' => count($words),
            'created' => 0,
            'existing' => 0,
            'failed' => 0
        ];
        
        // 开启事务
        Db::startTrans();
        try {
            foreach ($words as $wordData) {
                $result = self::create($wordData);
                
                if ($result['success']) {
                    $wordIds[] = $result['word_id'];
                    if ($result['is_new']) {
                        $stats['created']++;
                    } else {
                        $stats['existing']++;
                    }
                } else {
                    $stats['failed']++;
                }
            }
            
            Db::commit();
            
            return [
                'success' => true,
                'message' => "成功处理{$stats['total']}个单词，新建{$stats['created']}个，已存在{$stats['existing']}个",
                'word_ids' => $wordIds,
                'stats' => $stats
            ];
            
        } catch (Exception $e) {
            Db::rollback();
            return [
                'success' => false,
                'message' => '批量创建失败: ' . $e->getMessage(),
                'word_ids' => [],
                'stats' => $stats
            ];
        }
    }
    
    /**
     * 更新单词信息
     * 
     * @param int $wordId 单词ID
     * @param array $data 更新数据
     * @return array ['success' => bool, 'message' => string]
     */
    public static function update($wordId, $data)
    {
        // 检查单词是否存在
        $word = Db::name('word')
            ->where('id', $wordId)
            ->find();
        
        if (!$word) {
            return [
                'success' => false,
                'message' => '单词不存在'
            ];
        }
        
        // 准备更新数据
        $updateData = [];
        $allowedFields = ['phonetic', 'part_of_speech', 'definition', 'example'];
        
        foreach ($allowedFields as $field) {
            if (isset($data[$field])) {
                $updateData[$field] = $data[$field];
            }
        }
        
        // 不允许修改单词文本（word字段）
        if (isset($data['word']) && $data['word'] !== $word['word']) {
            return [
                'success' => false,
                'message' => '不允许修改单词文本'
            ];
        }
        
        if (empty($updateData)) {
            return [
                'success' => false,
                'message' => '没有需要更新的数据'
            ];
        }
        
        $updateData['updated_at'] = time();
        
        // 执行更新
        $result = Db::name('word')
            ->where('id', $wordId)
            ->update($updateData);
        
        return [
            'success' => $result !== false,
            'message' => $result !== false ? '更新成功' : '更新失败'
        ];
    }
    
    /**
     * 删除单词（物理删除，谨慎使用）
     * 注意：这会删除全局单词数据，影响所有词表
     * 
     * @param int $wordId 单词ID
     * @return array ['success' => bool, 'message' => string]
     */
    public static function delete($wordId)
    {
        // 检查单词是否存在
        $word = Db::name('word')
            ->where('id', $wordId)
            ->find();
        
        if (!$word) {
            return [
                'success' => false,
                'message' => '单词不存在'
            ];
        }
        
        // 检查是否有词表引用
        $refCount = Db::name('vocabulary_list_word')
            ->where('word_id', $wordId)
            ->count();
        
        if ($refCount > 0) {
            return [
                'success' => false,
                'message' => "该单词被{$refCount}个词表引用，无法删除"
            ];
        }
        
        // 开启事务
        Db::startTrans();
        try {
            // 删除单词
            Db::name('word')
                ->where('id', $wordId)
                ->delete();
            
            // 删除相关的学习进度
            Db::name('user_word_progress')
                ->where('word_id', $wordId)
                ->delete();
            
            // 删除相关的排除记录
            Db::name('user_word_exclusion')
                ->where('word_id', $wordId)
                ->delete();
            
            Db::commit();
            
            return [
                'success' => true,
                'message' => '删除成功'
            ];
            
        } catch (Exception $e) {
            Db::rollback();
            return [
                'success' => false,
                'message' => '删除失败: ' . $e->getMessage()
            ];
        }
    }
    
    /**
     * 获取单词详情
     * 
     * @param int $wordId 单词ID
     * @return array|null
     */
    public static function getDetail($wordId)
    {
        return Db::name('word')
            ->where('id', $wordId)
            ->find();
    }
    
    /**
     * 根据单词文本查找
     * 
     * @param string $word 单词文本
     * @return array|null
     */
    public static function findByWord($word)
    {
        return Db::name('word')
            ->where('word', $word)
            ->find();
    }
    
    /**
     * 搜索单词
     * 
     * @param string $keyword 关键词
     * @param int $limit 返回数量限制
     * @return array
     */
    public static function search($keyword, $limit = 20)
    {
        if (empty($keyword)) {
            return [];
        }
        
        return Db::name('word')
            ->where('word', 'like', "%{$keyword}%")
            ->whereOr('definition', 'like', "%{$keyword}%")
            ->limit($limit)
            ->select();
    }
    
    /**
     * 合并重复单词
     * 将sourceWordId的所有引用合并到targetWordId
     * 
     * @param int $sourceWordId 源单词ID（将被删除）
     * @param int $targetWordId 目标单词ID（保留）
     * @return array ['success' => bool, 'message' => string, 'merged_count' => int]
     */
    public static function merge($sourceWordId, $targetWordId)
    {
        if ($sourceWordId === $targetWordId) {
            return [
                'success' => false,
                'message' => '源单词和目标单词不能相同',
                'merged_count' => 0
            ];
        }
        
        // 检查两个单词是否都存在
        $sourceWord = self::getDetail($sourceWordId);
        $targetWord = self::getDetail($targetWordId);
        
        if (!$sourceWord || !$targetWord) {
            return [
                'success' => false,
                'message' => '单词不存在',
                'merged_count' => 0
            ];
        }
        
        // 开启事务
        Db::startTrans();
        try {
            $mergedCount = 0;
            
            // 1. 更新词表单词关联
            $listWords = Db::name('vocabulary_list_word')
                ->where('word_id', $sourceWordId)
                ->select();
            
            foreach ($listWords as $lw) {
                // 检查目标单词是否已在该词表中
                $exists = Db::name('vocabulary_list_word')
                    ->where('vocabulary_list_id', $lw['vocabulary_list_id'])
                    ->where('word_id', $targetWordId)
                    ->find();
                
                if (!$exists) {
                    // 更新为目标单词
                    Db::name('vocabulary_list_word')
                        ->where('id', $lw['id'])
                        ->update(['word_id' => $targetWordId]);
                    $mergedCount++;
                } else {
                    // 已存在，删除源单词的关联
                    Db::name('vocabulary_list_word')
                        ->where('id', $lw['id'])
                        ->delete();
                }
            }
            
            // 2. 更新学习进度（保留进度更高的）
            $progressList = Db::name('user_word_progress')
                ->where('word_id', $sourceWordId)
                ->select();
            
            foreach ($progressList as $progress) {
                $targetProgress = Db::name('user_word_progress')
                    ->where('user_id', $progress['user_id'])
                    ->where('word_id', $targetWordId)
                    ->where('vocabulary_list_id', $progress['vocabulary_list_id'])
                    ->find();
                
                if (!$targetProgress) {
                    // 更新为目标单词
                    Db::name('user_word_progress')
                        ->where('id', $progress['id'])
                        ->update(['word_id' => $targetWordId]);
                } else {
                    // 保留记忆级别更高的
                    if ($progress['memory_level'] > $targetProgress['memory_level']) {
                        Db::name('user_word_progress')
                            ->where('id', $targetProgress['id'])
                            ->update([
                                'memory_level' => $progress['memory_level'],
                                'review_count' => $progress['review_count'],
                                'last_review_at' => $progress['last_review_at'],
                                'next_review_at' => $progress['next_review_at']
                            ]);
                    }
                    // 删除源单词的进度
                    Db::name('user_word_progress')
                        ->where('id', $progress['id'])
                        ->delete();
                }
            }
            
            // 3. 更新排除记录
            $exclusions = Db::name('user_word_exclusion')
                ->where('word_id', $sourceWordId)
                ->select();
            
            foreach ($exclusions as $exclusion) {
                $targetExclusion = Db::name('user_word_exclusion')
                    ->where('user_id', $exclusion['user_id'])
                    ->where('word_id', $targetWordId)
                    ->where('vocabulary_list_id', $exclusion['vocabulary_list_id'])
                    ->find();
                
                if (!$targetExclusion) {
                    Db::name('user_word_exclusion')
                        ->where('id', $exclusion['id'])
                        ->update(['word_id' => $targetWordId]);
                } else {
                    Db::name('user_word_exclusion')
                        ->where('id', $exclusion['id'])
                        ->delete();
                }
            }
            
            // 4. 删除源单词
            Db::name('word')
                ->where('id', $sourceWordId)
                ->delete();
            
            Db::commit();
            
            return [
                'success' => true,
                'message' => '合并成功',
                'merged_count' => $mergedCount
            ];
            
        } catch (Exception $e) {
            Db::rollback();
            return [
                'success' => false,
                'message' => '合并失败: ' . $e->getMessage(),
                'merged_count' => 0
            ];
        }
    }
    
    /**
     * 查找重复的单词
     * 
     * @return array 重复单词的分组列表
     */
    public static function findDuplicates()
    {
        $duplicates = Db::name('word')
            ->field('word, COUNT(*) as count')
            ->group('word')
            ->having('count > 1')
            ->select();
        
        $result = [];
        foreach ($duplicates as $dup) {
            $words = Db::name('word')
                ->where('word', $dup['word'])
                ->select();
            $result[] = [
                'word' => $dup['word'],
                'count' => $dup['count'],
                'items' => $words
            ];
        }
        
        return $result;
    }
    
    /**
     * 批量导入单词到词表
     * 
     * @param int $listId 词表ID
     * @param array $words 单词数据数组
     * @return array ['success' => bool, 'message' => string, 'stats' => array]
     */
    public static function batchImportToList($listId, $words)
    {
        // 先批量创建单词
        $createResult = self::batchCreate($words);
        
        if (!$createResult['success']) {
            return [
                'success' => false,
                'message' => $createResult['message'],
                'stats' => $createResult['stats']
            ];
        }
        
        // 将单词添加到词表
        $addResult = VocabularyService::addWords($listId, $createResult['word_ids']);
        
        return [
            'success' => $addResult['success'],
            'message' => $addResult['message'],
            'stats' => array_merge($createResult['stats'], [
                'added_to_list' => $addResult['added_count']
            ])
        ];
    }
}
