<?php

namespace app\api\model;

use think\Model;

/**
 * 词表定义模型
 * 说明: 存储词表的元信息，包括官方词表和用户自定义词表
 */
class VocabularyList extends Model
{
    // 表名
    protected $name = 'vocabulary_list';
    
    // 开启自动写入时间戳字段
    protected $autoWriteTimestamp = 'int';
    
    // 定义时间戳字段名
    protected $createTime = 'created_at';
    protected $updateTime = 'updated_at';
    
    // 定义字段类型
    protected $type = [
        'id' => 'integer',
        'difficulty_level' => 'integer',
        'word_count' => 'integer',
        'is_official' => 'integer',
        'created_at' => 'integer',
        'updated_at' => 'integer',
    ];
    
    /**
     * 定义与单词的多对多关系
     * 一个词表包含多个单词
     */
    public function words()
    {
        return $this->belongsToMany('Word', 'vocabulary_list_word', 'word_id', 'vocabulary_list_id')
            ->withField('sort_order,created_at')
            ->order('sort_order', 'asc');
    }
    
    /**
     * 定义与用户的多对多关系
     * 一个词表可以被多个用户下载
     */
    public function users()
    {
        return $this->belongsToMany('User', 'user_vocabulary_list', 'user_id', 'vocabulary_list_id')
            ->withField('downloaded_at,is_custom');
    }
    
    /**
     * 定义与词表单词关联的一对多关系
     */
    public function listWords()
    {
        return $this->hasMany('VocabularyListWord', 'vocabulary_list_id');
    }
    
    /**
     * 定义与用户词表关联的一对多关系
     */
    public function userLists()
    {
        return $this->hasMany('UserVocabularyList', 'vocabulary_list_id');
    }
    
    /**
     * 定义与用户学习进度的一对多关系
     */
    public function userProgress()
    {
        return $this->hasMany('UserWordProgress', 'vocabulary_list_id');
    }
    
    /**
     * 定义与用户排除记录的一对多关系
     */
    public function userExclusions()
    {
        return $this->hasMany('UserWordExclusion', 'vocabulary_list_id');
    }
    
    /**
     * 获取词表的单词数量
     * @param int $listId 词表ID
     * @return int
     */
    public static function getWordCount($listId)
    {
        return VocabularyListWord::where('vocabulary_list_id', $listId)->count();
    }
    
    /**
     * 更新词表的单词数量
     * @param int $listId 词表ID
     */
    public static function updateWordCount($listId)
    {
        $count = self::getWordCount($listId);
        self::where('id', $listId)->update(['word_count' => $count]);
    }
}
