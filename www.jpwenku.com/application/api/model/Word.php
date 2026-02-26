<?php

namespace app\api\model;

use think\Model;

/**
 * 全局单词模型
 * 说明: 存储全局共享的单词数据，避免重复存储
 */
class Word extends Model
{
    // 表名
    protected $name = 'word';
    
    // 开启自动写入时间戳字段
    protected $autoWriteTimestamp = 'int';
    
    // 定义时间戳字段名
    protected $createTime = 'created_at';
    protected $updateTime = 'updated_at';
    
    // 定义字段类型
    protected $type = [
        'id' => 'integer',
        'created_at' => 'integer',
        'updated_at' => 'integer',
    ];
    
    /**
     * 定义与词表的多对多关系
     * 一个单词可以属于多个词表
     */
    public function vocabularyLists()
    {
        return $this->belongsToMany('VocabularyList', 'vocabulary_list_word', 'vocabulary_list_id', 'word_id');
    }
    
    /**
     * 定义与用户学习进度的一对多关系
     */
    public function userProgress()
    {
        return $this->hasMany('UserWordProgress', 'word_id');
    }
    
    /**
     * 定义与用户排除记录的一对多关系
     */
    public function userExclusions()
    {
        return $this->hasMany('UserWordExclusion', 'word_id');
    }
    
    /**
     * 根据单词文本查找或创建单词
     * @param string $word 单词文本
     * @param array $data 单词数据
     * @return Word
     */
    public static function findOrCreate($word, $data = [])
    {
        $model = self::where('word', $word)->find();
        
        if (!$model) {
            $data['word'] = $word;
            $model = self::create($data);
        }
        
        return $model;
    }
    
    /**
     * 批量查找或创建单词
     * @param array $words 单词数据数组
     * @return array 单词ID数组
     */
    public static function batchFindOrCreate($words)
    {
        $wordIds = [];
        
        foreach ($words as $wordData) {
            $word = self::findOrCreate($wordData['word'], $wordData);
            $wordIds[] = $word->id;
        }
        
        return $wordIds;
    }
}
