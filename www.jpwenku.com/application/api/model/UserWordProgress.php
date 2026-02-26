<?php

namespace app\api\model;

use think\Model;

/**
 * 用户单词学习进度模型
 * 说明: 记录用户对每个单词的学习进度和复习计划
 */
class UserWordProgress extends Model
{
    // 表名
    protected $name = 'user_word_progress';
    
    // 开启自动写入时间戳字段
    protected $autoWriteTimestamp = false; // 手动管理时间戳
    
    // 定义字段类型
    protected $type = [
        'id' => 'integer',
        'user_id' => 'integer',
        'word_id' => 'integer',
        'vocabulary_list_id' => 'integer',
        'learned_at' => 'integer',
        'last_review_at' => 'integer',
        'next_review_at' => 'integer',
        'review_count' => 'integer',
        'error_count' => 'integer',
        'memory_level' => 'integer',
    ];
    
    // 学习状态常量
    const STATUS_NOT_LEARNED = 'not_learned';
    const STATUS_MASTERED = 'mastered';
    const STATUS_NEED_REVIEW = 'need_review';
    
    // 记忆级别常量
    const MAX_MEMORY_LEVEL = 5;
    
    // 记忆曲线间隔（天）
    const REVIEW_INTERVALS = [
        0 => 0,
        1 => 1,
        2 => 2,
        3 => 4,
        4 => 7,
        5 => 15,
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
     * 标记单词为已认识
     * @param int $userId 用户ID
     * @param int $wordId 单词ID
     * @param int $listId 词表ID
     * @return bool|UserWordProgress
     */
    public static function markAsKnown($userId, $wordId, $listId)
    {
        $progress = self::getOrCreate($userId, $wordId, $listId);
        
        $now = time();
        $nextLevel = min($progress->memory_level + 1, self::MAX_MEMORY_LEVEL);
        $intervalDays = self::REVIEW_INTERVALS[$nextLevel];
        
        $progress->status = $nextLevel >= self::MAX_MEMORY_LEVEL ? self::STATUS_MASTERED : self::STATUS_NEED_REVIEW;
        $progress->learned_at = $progress->learned_at ?: $now;
        $progress->last_review_at = $now;
        $progress->next_review_at = $now + ($intervalDays * 86400);
        $progress->review_count = $progress->review_count + 1;
        $progress->memory_level = $nextLevel;
        
        return $progress->save();
    }
    
    /**
     * 标记单词为不认识
     * @param int $userId 用户ID
     * @param int $wordId 单词ID
     * @param int $listId 词表ID
     * @return bool|UserWordProgress
     */
    public static function markAsUnknown($userId, $wordId, $listId)
    {
        $progress = self::getOrCreate($userId, $wordId, $listId);
        
        $now = time();
        $intervalDays = self::REVIEW_INTERVALS[1];
        
        $progress->status = self::STATUS_NEED_REVIEW;
        $progress->learned_at = $progress->learned_at ?: $now;
        $progress->last_review_at = $now;
        $progress->next_review_at = $now + ($intervalDays * 86400);
        $progress->error_count = $progress->error_count + 1;
        $progress->memory_level = 1; // 重置到第一级
        
        return $progress->save();
    }
    
    /**
     * 获取或创建学习进度记录
     * @param int $userId 用户ID
     * @param int $wordId 单词ID
     * @param int $listId 词表ID
     * @return UserWordProgress
     */
    public static function getOrCreate($userId, $wordId, $listId)
    {
        $progress = self::where([
            'user_id' => $userId,
            'word_id' => $wordId,
            'vocabulary_list_id' => $listId
        ])->find();
        
        if (!$progress) {
            $progress = new self();
            $progress->user_id = $userId;
            $progress->word_id = $wordId;
            $progress->vocabulary_list_id = $listId;
            $progress->status = self::STATUS_NOT_LEARNED;
            $progress->review_count = 0;
            $progress->error_count = 0;
            $progress->memory_level = 0;
        }
        
        return $progress;
    }
    
    /**
     * 获取待复习的单词
     * @param int $userId 用户ID
     * @param int $listId 词表ID
     * @return array
     */
    public static function getDueReviews($userId, $listId)
    {
        $now = time();
        return self::where([
            'user_id' => $userId,
            'vocabulary_list_id' => $listId,
            'status' => self::STATUS_NEED_REVIEW
        ])
        ->where('next_review_at', '<=', $now)
        ->order('next_review_at', 'asc')
        ->select();
    }
    
    /**
     * 获取错题列表
     * @param int $userId 用户ID
     * @param int $listId 词表ID
     * @return array
     */
    public static function getWrongWords($userId, $listId)
    {
        return self::where([
            'user_id' => $userId,
            'vocabulary_list_id' => $listId
        ])
        ->where('error_count', '>', 0)
        ->order('error_count', 'desc')
        ->select();
    }
    
    /**
     * 获取学习统计
     * @param int $userId 用户ID
     * @param int $listId 词表ID
     * @return array
     */
    public static function getStatistics($userId, $listId)
    {
        $total = VocabularyList::getWordCount($listId);
        $mastered = self::where([
            'user_id' => $userId,
            'vocabulary_list_id' => $listId,
            'status' => self::STATUS_MASTERED
        ])->count();
        
        $needReview = self::where([
            'user_id' => $userId,
            'vocabulary_list_id' => $listId,
            'status' => self::STATUS_NEED_REVIEW
        ])->count();
        
        $notLearned = $total - $mastered - $needReview;
        
        return [
            'total' => $total,
            'mastered' => $mastered,
            'need_review' => $needReview,
            'not_learned' => max(0, $notLearned),
            'progress' => $total > 0 ? round(($mastered / $total) * 100, 2) : 0
        ];
    }
}
