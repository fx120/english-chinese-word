<?php

namespace app\api\model;

use think\Model;

/**
 * 用户词表关联模型
 * 说明: 记录用户下载或创建的词表
 */
class UserVocabularyList extends Model
{
    // 表名
    protected $name = 'user_vocabulary_list';
    
    // 开启自动写入时间戳字段
    protected $autoWriteTimestamp = false; // 手动管理时间戳
    
    // 定义字段类型
    protected $type = [
        'id' => 'integer',
        'user_id' => 'integer',
        'vocabulary_list_id' => 'integer',
        'downloaded_at' => 'integer',
        'is_custom' => 'integer',
    ];
    
    /**
     * 定义与用户的关联关系
     */
    public function user()
    {
        return $this->belongsTo('User', 'user_id');
    }
    
    /**
     * 定义与词表的关联关系
     */
    public function vocabularyList()
    {
        return $this->belongsTo('VocabularyList', 'vocabulary_list_id');
    }
    
    /**
     * 用户下载词表
     * @param int $userId 用户ID
     * @param int $listId 词表ID
     * @param bool $isCustom 是否自定义词表
     * @return bool|UserVocabularyList
     */
    public static function downloadList($userId, $listId, $isCustom = false)
    {
        // 检查是否已下载
        $exists = self::where([
            'user_id' => $userId,
            'vocabulary_list_id' => $listId
        ])->find();
        
        if ($exists) {
            return false; // 已下载
        }
        
        return self::create([
            'user_id' => $userId,
            'vocabulary_list_id' => $listId,
            'downloaded_at' => time(),
            'is_custom' => $isCustom ? 1 : 0
        ]);
    }
    
    /**
     * 检查用户是否已下载词表
     * @param int $userId 用户ID
     * @param int $listId 词表ID
     * @return bool
     */
    public static function hasDownloaded($userId, $listId)
    {
        return self::where([
            'user_id' => $userId,
            'vocabulary_list_id' => $listId
        ])->count() > 0;
    }
    
    /**
     * 获取用户的所有词表ID
     * @param int $userId 用户ID
     * @return array
     */
    public static function getUserListIds($userId)
    {
        return self::where('user_id', $userId)->column('vocabulary_list_id');
    }
    
    /**
     * 获取用户的词表列表（带词表详情）
     * @param int $userId 用户ID
     * @return array
     */
    public static function getUserLists($userId)
    {
        return self::where('user_id', $userId)
            ->with('vocabularyList')
            ->order('downloaded_at', 'desc')
            ->select();
    }
}
