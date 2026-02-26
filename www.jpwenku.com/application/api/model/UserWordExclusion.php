<?php

namespace app\api\model;

use think\Model;

/**
 * 用户单词排除模型
 * 说明: 记录用户在特定词表中删除(排除)的单词，实现软删除
 */
class UserWordExclusion extends Model
{
    // 表名
    protected $name = 'user_word_exclusion';
    
    // 开启自动写入时间戳字段
    protected $autoWriteTimestamp = false; // 手动管理时间戳
    
    // 定义字段类型
    protected $type = [
        'id' => 'integer',
        'user_id' => 'integer',
        'word_id' => 'integer',
        'vocabulary_list_id' => 'integer',
        'excluded_at' => 'integer',
    ];
    
    /**
     * 定义与用户的关联关系
     */
    public function user()
    {
        return $this->belongsTo('User', 'user_id');
    }
    
    /**
     * 定义与单词的关联关系
     */
    public function word()
    {
        return $this->belongsTo('Word', 'word_id');
    }
    
    /**
     * 定义与词表的关联关系
     */
    public function vocabularyList()
    {
        return $this->belongsTo('VocabularyList', 'vocabulary_list_id');
    }
    
    /**
     * 排除单词（软删除）
     * @param int $userId 用户ID
     * @param int $wordId 单词ID
     * @param int $listId 词表ID
     * @return bool|UserWordExclusion
     */
    public static function excludeWord($userId, $wordId, $listId)
    {
        // 检查是否已排除
        $exists = self::where([
            'user_id' => $userId,
            'word_id' => $wordId,
            'vocabulary_list_id' => $listId
        ])->find();
        
        if ($exists) {
            return false; // 已排除
        }
        
        return self::create([
            'user_id' => $userId,
            'word_id' => $wordId,
            'vocabulary_list_id' => $listId,
            'excluded_at' => time()
        ]);
    }
    
    /**
     * 恢复单词（取消排除）
     * @param int $userId 用户ID
     * @param int $wordId 单词ID
     * @param int $listId 词表ID
     * @return bool
     */
    public static function restoreWord($userId, $wordId, $listId)
    {
        return self::where([
            'user_id' => $userId,
            'word_id' => $wordId,
            'vocabulary_list_id' => $listId
        ])->delete();
    }
    
    /**
     * 检查单词是否被排除
     * @param int $userId 用户ID
     * @param int $wordId 单词ID
     * @param int $listId 词表ID
     * @return bool
     */
    public static function isExcluded($userId, $wordId, $listId)
    {
        return self::where([
            'user_id' => $userId,
            'word_id' => $wordId,
            'vocabulary_list_id' => $listId
        ])->count() > 0;
    }
    
    /**
     * 获取用户在词表中排除的所有单词ID
     * @param int $userId 用户ID
     * @param int $listId 词表ID
     * @return array
     */
    public static function getExcludedWordIds($userId, $listId)
    {
        return self::where([
            'user_id' => $userId,
            'vocabulary_list_id' => $listId
        ])->column('word_id');
    }
    
    /**
     * 批量排除单词
     * @param int $userId 用户ID
     * @param array $wordIds 单词ID数组
     * @param int $listId 词表ID
     * @return int 排除的数量
     */
    public static function batchExclude($userId, $wordIds, $listId)
    {
        $count = 0;
        foreach ($wordIds as $wordId) {
            if (self::excludeWord($userId, $wordId, $listId)) {
                $count++;
            }
        }
        return $count;
    }
}
