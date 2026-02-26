<?php

namespace app\api\model;

use think\Model;

/**
 * 词表单词关联模型
 * 说明: 建立词表和单词的多对多关系，一个单词可以属于多个词表
 */
class VocabularyListWord extends Model
{
    // 表名
    protected $name = 'vocabulary_list_word';
    
    // 开启自动写入时间戳字段
    protected $autoWriteTimestamp = 'int';
    
    // 定义时间戳字段名
    protected $createTime = 'created_at';
    protected $updateTime = false; // 该表不需要更新时间
    
    // 定义字段类型
    protected $type = [
        'id' => 'integer',
        'vocabulary_list_id' => 'integer',
        'word_id' => 'integer',
        'sort_order' => 'integer',
        'created_at' => 'integer',
    ];
    
    /**
     * 定义与词表的关联关系
     */
    public function vocabularyList()
    {
        return $this->belongsTo('VocabularyList', 'vocabulary_list_id');
    }
    
    /**
     * 定义与单词的关联关系
     */
    public function word()
    {
        return $this->belongsTo('Word', 'word_id');
    }
    
    /**
     * 批量添加单词到词表
     * @param int $listId 词表ID
     * @param array $wordIds 单词ID数组
     * @return int 添加的数量
     */
    public static function batchAdd($listId, $wordIds)
    {
        $count = 0;
        $maxSortOrder = self::where('vocabulary_list_id', $listId)->max('sort_order') ?: 0;
        
        foreach ($wordIds as $wordId) {
            // 检查是否已存在
            $exists = self::where([
                'vocabulary_list_id' => $listId,
                'word_id' => $wordId
            ])->find();
            
            if (!$exists) {
                $maxSortOrder++;
                self::create([
                    'vocabulary_list_id' => $listId,
                    'word_id' => $wordId,
                    'sort_order' => $maxSortOrder
                ]);
                $count++;
            }
        }
        
        // 更新词表的单词数量
        VocabularyList::updateWordCount($listId);
        
        return $count;
    }
    
    /**
     * 从词表中移除单词
     * @param int $listId 词表ID
     * @param int $wordId 单词ID
     * @return bool
     */
    public static function removeWord($listId, $wordId)
    {
        $result = self::where([
            'vocabulary_list_id' => $listId,
            'word_id' => $wordId
        ])->delete();
        
        if ($result) {
            // 更新词表的单词数量
            VocabularyList::updateWordCount($listId);
        }
        
        return $result;
    }
    
    /**
     * 获取词表中的所有单词ID
     * @param int $listId 词表ID
     * @return array
     */
    public static function getWordIds($listId)
    {
        return self::where('vocabulary_list_id', $listId)
            ->order('sort_order', 'asc')
            ->column('word_id');
    }
}
