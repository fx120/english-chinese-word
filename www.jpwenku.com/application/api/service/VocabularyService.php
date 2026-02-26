<?php

namespace app\api\service;

use think\Db;
use think\Exception;
use app\api\model\VocabularyList;
use app\api\model\Word;
use app\api\model\VocabularyListWord;
use app\api\model\UserVocabularyList;

/**
 * 词表服务类
 * 处理词表CRUD、词表与单词关联管理、词表下载等业务逻辑
 */
class VocabularyService
{
    /**
     * 获取词表列表（支持分类筛选和分页）
     * 
     * @param array $params 查询参数 ['category' => string, 'page' => int, 'limit' => int]
     * @return array ['total' => int, 'page' => int, 'limit' => int, 'items' => array]
     */
    public static function getList($params = [])
    {
        $category = $params['category'] ?? '';
        $page = max(1, $params['page'] ?? 1);
        $limit = min(100, max(1, $params['limit'] ?? 20));
        
        // 构建查询条件
        $where = ['status' => 'normal'];
        
        if (!empty($category)) {
            $where['category'] = $category;
        }
        
        // 查询总数
        $total = Db::name('vocabulary_list')
            ->where($where)
            ->count();
        
        // 查询列表
        $items = Db::name('vocabulary_list')
            ->where($where)
            ->field('id,name,description,category,difficulty_level,word_count,is_official,created_at')
            ->order('created_at', 'desc')
            ->page($page, $limit)
            ->select();
        
        return [
            'total' => $total,
            'page' => $page,
            'limit' => $limit,
            'items' => $items
        ];
    }
    
    /**
     * 获取词表详情（包含关联的单词）
     * 
     * @param int $listId 词表ID
     * @param bool $includeWords 是否包含单词列表
     * @return array|null
     */
    public static function getDetail($listId, $includeWords = true)
    {
        // 查询词表信息
        $vocabularyList = Db::name('vocabulary_list')
            ->where('id', $listId)
            ->where('status', 'normal')
            ->find();
        
        if (!$vocabularyList) {
            return null;
        }
        
        // 如果需要包含单词列表
        if ($includeWords) {
            $words = Db::name('vocabulary_list_word')
                ->alias('vlw')
                ->join('word w', 'vlw.word_id = w.id')
                ->where('vlw.vocabulary_list_id', $listId)
                ->field('w.id,w.word,w.phonetic,w.part_of_speech,w.definition,w.example,vlw.sort_order')
                ->order('vlw.sort_order', 'asc')
                ->select();
            
            $vocabularyList['words'] = $words;
        }
        
        return $vocabularyList;
    }
    
    /**
     * 创建词表
     * 
     * @param array $data 词表数据
     * @param int $userId 用户ID（用于自定义词表）
     * @return array ['success' => bool, 'message' => string, 'list_id' => int|null]
     */
    public static function create($data, $userId = null)
    {
        // 验证必填字段
        if (empty($data['name'])) {
            return [
                'success' => false,
                'message' => '词表名称不能为空',
                'list_id' => null
            ];
        }
        
        // 开启事务
        Db::startTrans();
        try {
            // 创建词表
            $listData = [
                'name' => $data['name'],
                'description' => $data['description'] ?? '',
                'category' => $data['category'] ?? 'custom',
                'difficulty_level' => $data['difficulty_level'] ?? 1,
                'word_count' => 0, // 初始为0，后续更新
                'is_official' => $data['is_official'] ?? 0,
                'created_at' => time(),
                'updated_at' => time(),
                'status' => 'normal'
            ];
            
            $listId = Db::name('vocabulary_list')->insertGetId($listData);
            
            // 如果提供了用户ID，创建用户词表关联
            if ($userId) {
                Db::name('user_vocabulary_list')->insert([
                    'user_id' => $userId,
                    'vocabulary_list_id' => $listId,
                    'downloaded_at' => time(),
                    'is_custom' => 1
                ]);
            }
            
            Db::commit();
            
            return [
                'success' => true,
                'message' => '词表创建成功',
                'list_id' => $listId
            ];
            
        } catch (Exception $e) {
            Db::rollback();
            return [
                'success' => false,
                'message' => '词表创建失败: ' . $e->getMessage(),
                'list_id' => null
            ];
        }
    }
    
    /**
     * 更新词表信息
     * 
     * @param int $listId 词表ID
     * @param array $data 更新数据
     * @return array ['success' => bool, 'message' => string]
     */
    public static function update($listId, $data)
    {
        // 检查词表是否存在
        $list = Db::name('vocabulary_list')
            ->where('id', $listId)
            ->find();
        
        if (!$list) {
            return [
                'success' => false,
                'message' => '词表不存在'
            ];
        }
        
        // 准备更新数据
        $updateData = [];
        $allowedFields = ['name', 'description', 'category', 'difficulty_level'];
        
        foreach ($allowedFields as $field) {
            if (isset($data[$field])) {
                $updateData[$field] = $data[$field];
            }
        }
        
        if (empty($updateData)) {
            return [
                'success' => false,
                'message' => '没有需要更新的数据'
            ];
        }
        
        $updateData['updated_at'] = time();
        
        // 执行更新
        $result = Db::name('vocabulary_list')
            ->where('id', $listId)
            ->update($updateData);
        
        return [
            'success' => $result !== false,
            'message' => $result !== false ? '更新成功' : '更新失败'
        ];
    }
    
    /**
     * 删除词表
     * 
     * @param int $listId 词表ID
     * @return array ['success' => bool, 'message' => string]
     */
    public static function delete($listId)
    {
        // 检查词表是否存在
        $list = Db::name('vocabulary_list')
            ->where('id', $listId)
            ->find();
        
        if (!$list) {
            return [
                'success' => false,
                'message' => '词表不存在'
            ];
        }
        
        // 软删除：更新状态为hidden
        $result = Db::name('vocabulary_list')
            ->where('id', $listId)
            ->update([
                'status' => 'hidden',
                'updated_at' => time()
            ]);
        
        return [
            'success' => $result !== false,
            'message' => $result !== false ? '删除成功' : '删除失败'
        ];
    }
    
    /**
     * 添加单词到词表
     * 
     * @param int $listId 词表ID
     * @param array $wordIds 单词ID数组
     * @return array ['success' => bool, 'message' => string, 'added_count' => int]
     */
    public static function addWords($listId, $wordIds)
    {
        if (empty($wordIds) || !is_array($wordIds)) {
            return [
                'success' => false,
                'message' => '单词ID列表不能为空',
                'added_count' => 0
            ];
        }
        
        // 检查词表是否存在
        $list = Db::name('vocabulary_list')
            ->where('id', $listId)
            ->find();
        
        if (!$list) {
            return [
                'success' => false,
                'message' => '词表不存在',
                'added_count' => 0
            ];
        }
        
        // 获取当前最大排序号
        $maxSort = Db::name('vocabulary_list_word')
            ->where('vocabulary_list_id', $listId)
            ->max('sort_order');
        
        $sortOrder = $maxSort ? $maxSort + 1 : 1;
        $addedCount = 0;
        
        // 开启事务
        Db::startTrans();
        try {
            foreach ($wordIds as $wordId) {
                // 检查是否已存在
                $exists = Db::name('vocabulary_list_word')
                    ->where('vocabulary_list_id', $listId)
                    ->where('word_id', $wordId)
                    ->find();
                
                if (!$exists) {
                    Db::name('vocabulary_list_word')->insert([
                        'vocabulary_list_id' => $listId,
                        'word_id' => $wordId,
                        'sort_order' => $sortOrder,
                        'created_at' => time()
                    ]);
                    $sortOrder++;
                    $addedCount++;
                }
            }
            
            // 更新词表的单词数量
            self::updateWordCount($listId);
            
            Db::commit();
            
            return [
                'success' => true,
                'message' => "成功添加{$addedCount}个单词",
                'added_count' => $addedCount
            ];
            
        } catch (Exception $e) {
            Db::rollback();
            return [
                'success' => false,
                'message' => '添加单词失败: ' . $e->getMessage(),
                'added_count' => 0
            ];
        }
    }
    
    /**
     * 从词表移除单词
     * 
     * @param int $listId 词表ID
     * @param array $wordIds 单词ID数组
     * @return array ['success' => bool, 'message' => string, 'removed_count' => int]
     */
    public static function removeWords($listId, $wordIds)
    {
        if (empty($wordIds) || !is_array($wordIds)) {
            return [
                'success' => false,
                'message' => '单词ID列表不能为空',
                'removed_count' => 0
            ];
        }
        
        // 开启事务
        Db::startTrans();
        try {
            $removedCount = Db::name('vocabulary_list_word')
                ->where('vocabulary_list_id', $listId)
                ->where('word_id', 'in', $wordIds)
                ->delete();
            
            // 更新词表的单词数量
            self::updateWordCount($listId);
            
            Db::commit();
            
            return [
                'success' => true,
                'message' => "成功移除{$removedCount}个单词",
                'removed_count' => $removedCount
            ];
            
        } catch (Exception $e) {
            Db::rollback();
            return [
                'success' => false,
                'message' => '移除单词失败: ' . $e->getMessage(),
                'removed_count' => 0
            ];
        }
    }
    
    /**
     * 更新词表的单词数量
     * 
     * @param int $listId 词表ID
     * @return bool
     */
    public static function updateWordCount($listId)
    {
        $count = Db::name('vocabulary_list_word')
            ->where('vocabulary_list_id', $listId)
            ->count();
        
        return Db::name('vocabulary_list')
            ->where('id', $listId)
            ->update([
                'word_count' => $count,
                'updated_at' => time()
            ]);
    }
    
    /**
     * 用户下载词表
     * 
     * @param int $userId 用户ID
     * @param int $listId 词表ID
     * @return array ['success' => bool, 'message' => string, 'data' => array|null]
     */
    public static function download($userId, $listId)
    {
        // 检查词表是否存在
        $vocabularyList = self::getDetail($listId, false);
        
        if (!$vocabularyList) {
            return [
                'success' => false,
                'message' => '词表不存在',
                'data' => null
            ];
        }
        
        // 检查是否已下载
        $exists = Db::name('user_vocabulary_list')
            ->where('user_id', $userId)
            ->where('vocabulary_list_id', $listId)
            ->find();
        
        if ($exists) {
            return [
                'success' => false,
                'message' => '您已下载过该词表',
                'data' => null
            ];
        }
        
        // 开启事务
        Db::startTrans();
        try {
            // 创建用户词表关联
            Db::name('user_vocabulary_list')->insert([
                'user_id' => $userId,
                'vocabulary_list_id' => $listId,
                'downloaded_at' => time(),
                'is_custom' => 0
            ]);
            
            // 获取词表的所有单词
            $words = Db::name('vocabulary_list_word')
                ->alias('vlw')
                ->join('word w', 'vlw.word_id = w.id')
                ->where('vlw.vocabulary_list_id', $listId)
                ->field('w.id,w.word,w.phonetic,w.part_of_speech,w.definition,w.example,vlw.sort_order')
                ->order('vlw.sort_order', 'asc')
                ->select();
            
            Db::commit();
            
            return [
                'success' => true,
                'message' => '下载成功',
                'data' => [
                    'vocabulary_list' => $vocabularyList,
                    'words' => $words
                ]
            ];
            
        } catch (Exception $e) {
            Db::rollback();
            return [
                'success' => false,
                'message' => '下载失败: ' . $e->getMessage(),
                'data' => null
            ];
        }
    }
    
    /**
     * 获取用户的词表列表
     * 
     * @param int $userId 用户ID
     * @return array
     */
    public static function getUserLists($userId)
    {
        $lists = Db::name('user_vocabulary_list')
            ->alias('uvl')
            ->join('vocabulary_list vl', 'uvl.vocabulary_list_id = vl.id')
            ->where('uvl.user_id', $userId)
            ->where('vl.status', 'normal')
            ->field('vl.id,vl.name,vl.description,vl.category,vl.difficulty_level,vl.word_count,vl.is_official,uvl.is_custom,uvl.downloaded_at')
            ->order('uvl.downloaded_at', 'desc')
            ->select();
        
        return $lists;
    }
    
    /**
     * 检查用户是否已下载词表
     * 
     * @param int $userId 用户ID
     * @param int $listId 词表ID
     * @return bool
     */
    public static function hasDownloaded($userId, $listId)
    {
        $exists = Db::name('user_vocabulary_list')
            ->where('user_id', $userId)
            ->where('vocabulary_list_id', $listId)
            ->find();
        
        return !empty($exists);
    }
}
