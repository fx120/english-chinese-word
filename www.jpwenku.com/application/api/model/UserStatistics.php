<?php

namespace app\api\model;

use think\Model;

/**
 * 用户学习统计模型
 * 说明: 记录用户的学习统计数据，用于展示学习进度和成就
 */
class UserStatistics extends Model
{
    // 表名
    protected $name = 'user_statistics';
    
    // 开启自动写入时间戳字段
    protected $autoWriteTimestamp = 'int';
    
    // 定义时间戳字段名
    protected $createTime = false; // 该表不需要创建时间
    protected $updateTime = 'updated_at';
    
    // 定义字段类型
    protected $type = [
        'id' => 'integer',
        'user_id' => 'integer',
        'total_days' => 'integer',
        'continuous_days' => 'integer',
        'total_words_learned' => 'integer',
        'total_words_mastered' => 'integer',
        'updated_at' => 'integer',
    ];
    
    /**
     * 定义与用户的关联关系
     */
    public function user()
    {
        return $this->belongsTo('User', 'user_id');
    }
    
    /**
     * 获取或创建用户统计记录
     * @param int $userId 用户ID
     * @return UserStatistics
     */
    public static function getOrCreate($userId)
    {
        $stats = self::where('user_id', $userId)->find();
        
        if (!$stats) {
            $stats = self::create([
                'user_id' => $userId,
                'total_days' => 0,
                'continuous_days' => 0,
                'total_words_learned' => 0,
                'total_words_mastered' => 0,
                'last_learn_date' => null
            ]);
        }
        
        return $stats;
    }
    
    /**
     * 更新学习统计
     * @param int $userId 用户ID
     * @return bool
     */
    public static function updateStatistics($userId)
    {
        $stats = self::getOrCreate($userId);
        
        // 计算总学习单词数
        $totalLearned = UserWordProgress::where('user_id', $userId)
            ->where('status', '<>', UserWordProgress::STATUS_NOT_LEARNED)
            ->count();
        
        // 计算已掌握单词数
        $totalMastered = UserWordProgress::where([
            'user_id' => $userId,
            'status' => UserWordProgress::STATUS_MASTERED
        ])->count();
        
        // 更新今日学习日期
        $today = date('Y-m-d');
        $lastLearnDate = $stats->last_learn_date;
        
        // 计算连续学习天数
        if ($lastLearnDate) {
            $yesterday = date('Y-m-d', strtotime('-1 day'));
            
            if ($lastLearnDate == $today) {
                // 今天已经学习过，不增加天数
            } elseif ($lastLearnDate == $yesterday) {
                // 昨天学习过，连续天数+1
                $stats->continuous_days += 1;
                $stats->total_days += 1;
                $stats->last_learn_date = $today;
            } else {
                // 中断了，重置连续天数
                $stats->continuous_days = 1;
                $stats->total_days += 1;
                $stats->last_learn_date = $today;
            }
        } else {
            // 第一次学习
            $stats->continuous_days = 1;
            $stats->total_days = 1;
            $stats->last_learn_date = $today;
        }
        
        $stats->total_words_learned = $totalLearned;
        $stats->total_words_mastered = $totalMastered;
        
        return $stats->save();
    }
    
    /**
     * 获取用户统计数据
     * @param int $userId 用户ID
     * @return array
     */
    public static function getUserStats($userId)
    {
        $stats = self::getOrCreate($userId);
        
        // 获取待复习单词数
        $needReview = UserWordProgress::where([
            'user_id' => $userId,
            'status' => UserWordProgress::STATUS_NEED_REVIEW
        ])->count();
        
        return [
            'total_days' => $stats->total_days,
            'continuous_days' => $stats->continuous_days,
            'total_words_learned' => $stats->total_words_learned,
            'total_words_mastered' => $stats->total_words_mastered,
            'need_review' => $needReview,
            'last_learn_date' => $stats->last_learn_date,
            'updated_at' => $stats->updated_at
        ];
    }
    
    /**
     * 检查并更新连续学习天数
     * @param int $userId 用户ID
     * @return bool
     */
    public static function checkContinuousDays($userId)
    {
        $stats = self::getOrCreate($userId);
        
        if (!$stats->last_learn_date) {
            return true;
        }
        
        $today = date('Y-m-d');
        $yesterday = date('Y-m-d', strtotime('-1 day'));
        
        // 如果最后学习日期不是今天也不是昨天，说明中断了
        if ($stats->last_learn_date != $today && $stats->last_learn_date != $yesterday) {
            $stats->continuous_days = 0;
            return $stats->save();
        }
        
        return true;
    }
}
