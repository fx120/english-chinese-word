<?php

namespace app\api\service;

use think\Db;
use think\Exception;

/**
 * 数据同步服务类
 * 处理学习进度同步、冲突解决、数据合并等业务逻辑
 */
class SyncService
{
    /**
     * 同步学习进度
     * 
     * @param int $userId 用户ID
     * @param array $progressData 学习进度数据数组
     * @return array ['success' => bool, 'message' => string, 'synced_count' => int, 'conflicts' => array]
     */
    public static function syncProgress($userId, $progressData)
    {
        if (empty($progressData) || !is_array($progressData)) {
            return [
                'success' => false,
                'message' => '学习进度数据不能为空',
                'synced_count' => 0,
                'conflicts' => []
            ];
        }
        
        $syncedCount = 0;
        $conflicts = [];
        
        // 开启事务
        Db::startTrans();
        try {
            foreach ($progressData as $progress) {
                // 验证必填字段
                if (empty($progress['word_id']) || empty($progress['vocabulary_list_id'])) {
                    continue;
                }
                
                // 查询服务器端的进度
                $serverProgress = Db::name('user_word_progress')
                    ->where('user_id', $userId)
                    ->where('word_id', $progress['word_id'])
                    ->where('vocabulary_list_id', $progress['vocabulary_list_id'])
                    ->find();
                
                if (!$serverProgress) {
                    // 服务器端不存在，直接插入
                    $insertData = [
                        'user_id' => $userId,
                        'word_id' => $progress['word_id'],
                        'vocabulary_list_id' => $progress['vocabulary_list_id'],
                        'status' => $progress['status'] ?? 'not_learned',
                        'learned_at' => $progress['learned_at'] ?? null,
                        'last_review_at' => $progress['last_review_at'] ?? null,
                        'next_review_at' => $progress['next_review_at'] ?? null,
                        'review_count' => $progress['review_count'] ?? 0,
                        'error_count' => $progress['error_count'] ?? 0,
                        'memory_level' => $progress['memory_level'] ?? 0,
                    ];
                    
                    Db::name('user_word_progress')->insert($insertData);
                    $syncedCount++;
                    
                } else {
                    // 服务器端存在，检查是否有冲突
                    $conflict = self::detectConflict($serverProgress, $progress);
                    
                    if ($conflict) {
                        // 有冲突，使用冲突解决策略
                        $resolved = self::resolveConflict($serverProgress, $progress);
                        
                        // 更新为解决后的数据
                        Db::name('user_word_progress')
                            ->where('id', $serverProgress['id'])
                            ->update($resolved);
                        
                        $conflicts[] = [
                            'word_id' => $progress['word_id'],
                            'vocabulary_list_id' => $progress['vocabulary_list_id'],
                            'server' => $serverProgress,
                            'client' => $progress,
                            'resolved' => $resolved
                        ];
                        
                        $syncedCount++;
                    } else {
                        // 无冲突，使用客户端数据更新
                        $updateData = [
                            'status' => $progress['status'] ?? $serverProgress['status'],
                            'learned_at' => $progress['learned_at'] ?? $serverProgress['learned_at'],
                            'last_review_at' => $progress['last_review_at'] ?? $serverProgress['last_review_at'],
                            'next_review_at' => $progress['next_review_at'] ?? $serverProgress['next_review_at'],
                            'review_count' => $progress['review_count'] ?? $serverProgress['review_count'],
                            'error_count' => $progress['error_count'] ?? $serverProgress['error_count'],
                            'memory_level' => $progress['memory_level'] ?? $serverProgress['memory_level'],
                        ];
                        
                        Db::name('user_word_progress')
                            ->where('id', $serverProgress['id'])
                            ->update($updateData);
                        
                        $syncedCount++;
                    }
                }
            }
            
            Db::commit();
            
            return [
                'success' => true,
                'message' => "成功同步{$syncedCount}条学习进度",
                'synced_count' => $syncedCount,
                'conflicts' => $conflicts
            ];
            
        } catch (Exception $e) {
            Db::rollback();
            return [
                'success' => false,
                'message' => '同步失败: ' . $e->getMessage(),
                'synced_count' => 0,
                'conflicts' => []
            ];
        }
    }
    
    /**
     * 检测冲突
     * 
     * @param array $serverData 服务器端数据
     * @param array $clientData 客户端数据
     * @return bool 是否有冲突
     */
    private static function detectConflict($serverData, $clientData)
    {
        // 如果记忆级别不同，认为有冲突
        if (isset($clientData['memory_level']) && 
            $serverData['memory_level'] != $clientData['memory_level']) {
            return true;
        }
        
        // 如果复习次数差异较大（超过5次），认为有冲突
        if (isset($clientData['review_count']) && 
            abs($serverData['review_count'] - $clientData['review_count']) > 5) {
            return true;
        }
        
        // 如果最后复习时间差异较大（超过7天），认为有冲突
        if (isset($clientData['last_review_at']) && 
            $serverData['last_review_at'] && 
            $clientData['last_review_at']) {
            $timeDiff = abs($serverData['last_review_at'] - $clientData['last_review_at']);
            if ($timeDiff > 7 * 86400) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * 解决冲突
     * 策略：保留学习进度更高的数据
     * 
     * @param array $serverData 服务器端数据
     * @param array $clientData 客户端数据
     * @return array 解决后的数据
     */
    private static function resolveConflict($serverData, $clientData)
    {
        $serverLevel = $serverData['memory_level'];
        $clientLevel = $clientData['memory_level'] ?? 0;
        
        // 比较记忆级别
        if ($clientLevel > $serverLevel) {
            // 客户端级别更高，使用客户端数据
            return [
                'status' => $clientData['status'] ?? $serverData['status'],
                'learned_at' => $clientData['learned_at'] ?? $serverData['learned_at'],
                'last_review_at' => $clientData['last_review_at'] ?? $serverData['last_review_at'],
                'next_review_at' => $clientData['next_review_at'] ?? $serverData['next_review_at'],
                'review_count' => $clientData['review_count'] ?? $serverData['review_count'],
                'error_count' => $clientData['error_count'] ?? $serverData['error_count'],
                'memory_level' => $clientLevel,
            ];
        } elseif ($serverLevel > $clientLevel) {
            // 服务器端级别更高，保留服务器端数据
            return [
                'status' => $serverData['status'],
                'learned_at' => $serverData['learned_at'],
                'last_review_at' => $serverData['last_review_at'],
                'next_review_at' => $serverData['next_review_at'],
                'review_count' => $serverData['review_count'],
                'error_count' => $serverData['error_count'],
                'memory_level' => $serverLevel,
            ];
        } else {
            // 记忆级别相同，比较复习次数
            $serverReviewCount = $serverData['review_count'];
            $clientReviewCount = $clientData['review_count'] ?? 0;
            
            if ($clientReviewCount > $serverReviewCount) {
                // 客户端复习次数更多
                return [
                    'status' => $clientData['status'] ?? $serverData['status'],
                    'learned_at' => $clientData['learned_at'] ?? $serverData['learned_at'],
                    'last_review_at' => $clientData['last_review_at'] ?? $serverData['last_review_at'],
                    'next_review_at' => $clientData['next_review_at'] ?? $serverData['next_review_at'],
                    'review_count' => $clientReviewCount,
                    'error_count' => $clientData['error_count'] ?? $serverData['error_count'],
                    'memory_level' => $clientLevel,
                ];
            } else {
                // 服务器端复习次数更多或相同，保留服务器端
                return [
                    'status' => $serverData['status'],
                    'learned_at' => $serverData['learned_at'],
                    'last_review_at' => $serverData['last_review_at'],
                    'next_review_at' => $serverData['next_review_at'],
                    'review_count' => $serverReviewCount,
                    'error_count' => $serverData['error_count'],
                    'memory_level' => $serverLevel,
                ];
            }
        }
    }
    
    /**
     * 同步排除单词
     * 
     * @param int $userId 用户ID
     * @param array $exclusions 排除单词数据数组
     * @return array ['success' => bool, 'message' => string, 'synced_count' => int]
     */
    public static function syncExclusions($userId, $exclusions)
    {
        if (empty($exclusions) || !is_array($exclusions)) {
            return [
                'success' => false,
                'message' => '排除单词数据不能为空',
                'synced_count' => 0
            ];
        }
        
        $syncedCount = 0;
        
        // 开启事务
        Db::startTrans();
        try {
            foreach ($exclusions as $exclusion) {
                // 验证必填字段
                if (empty($exclusion['word_id']) || empty($exclusion['vocabulary_list_id'])) {
                    continue;
                }
                
                // 检查是否已存在
                $exists = Db::name('user_word_exclusion')
                    ->where('user_id', $userId)
                    ->where('word_id', $exclusion['word_id'])
                    ->where('vocabulary_list_id', $exclusion['vocabulary_list_id'])
                    ->find();
                
                if (!$exists) {
                    // 不存在，插入
                    Db::name('user_word_exclusion')->insert([
                        'user_id' => $userId,
                        'word_id' => $exclusion['word_id'],
                        'vocabulary_list_id' => $exclusion['vocabulary_list_id'],
                        'excluded_at' => $exclusion['excluded_at'] ?? time(),
                    ]);
                    $syncedCount++;
                }
            }
            
            Db::commit();
            
            return [
                'success' => true,
                'message' => "成功同步{$syncedCount}条排除记录",
                'synced_count' => $syncedCount
            ];
            
        } catch (Exception $e) {
            Db::rollback();
            return [
                'success' => false,
                'message' => '同步失败: ' . $e->getMessage(),
                'synced_count' => 0
            ];
        }
    }
    
    /**
     * 获取用户的学习统计数据
     * 
     * @param int $userId 用户ID
     * @return array|null
     */
    public static function getStatistics($userId)
    {
        // 查询用户统计表
        $stats = Db::name('user_statistics')
            ->where('user_id', $userId)
            ->find();
        
        if (!$stats) {
            // 不存在则创建默认统计
            $stats = [
                'user_id' => $userId,
                'total_days' => 0,
                'continuous_days' => 0,
                'total_words_learned' => 0,
                'total_words_mastered' => 0,
                'last_learn_date' => null,
                'updated_at' => time()
            ];
            
            Db::name('user_statistics')->insert($stats);
        }
        
        // 查询最近7天的学习记录
        $sevenDaysAgo = date('Y-m-d', strtotime('-7 days'));
        $dailyRecords = Db::name('daily_learning_record')
            ->where('user_id', $userId)
            ->where('learn_date', '>=', $sevenDaysAgo)
            ->order('learn_date', 'desc')
            ->select();
        
        $stats['daily_records'] = $dailyRecords;
        
        return $stats;
    }
    
    /**
     * 更新用户学习统计
     * 
     * @param int $userId 用户ID
     * @param array $data 统计数据
     * @return array ['success' => bool, 'message' => string]
     */
    public static function updateStatistics($userId, $data)
    {
        // 查询现有统计
        $stats = Db::name('user_statistics')
            ->where('user_id', $userId)
            ->find();
        
        if (!$stats) {
            // 不存在则创建
            $insertData = [
                'user_id' => $userId,
                'total_days' => $data['total_days'] ?? 0,
                'continuous_days' => $data['continuous_days'] ?? 0,
                'total_words_learned' => $data['total_words_learned'] ?? 0,
                'total_words_mastered' => $data['total_words_mastered'] ?? 0,
                'last_learn_date' => $data['last_learn_date'] ?? null,
                'updated_at' => time()
            ];
            
            Db::name('user_statistics')->insert($insertData);
            
            return [
                'success' => true,
                'message' => '统计数据创建成功'
            ];
        }
        
        // 合并统计数据（取最大值）
        $updateData = [
            'total_days' => max($stats['total_days'], $data['total_days'] ?? 0),
            'continuous_days' => max($stats['continuous_days'], $data['continuous_days'] ?? 0),
            'total_words_learned' => max($stats['total_words_learned'], $data['total_words_learned'] ?? 0),
            'total_words_mastered' => max($stats['total_words_mastered'], $data['total_words_mastered'] ?? 0),
            'updated_at' => time()
        ];
        
        // 更新最后学习日期（取最新的）
        if (isset($data['last_learn_date'])) {
            if (!$stats['last_learn_date'] || 
                strtotime($data['last_learn_date']) > strtotime($stats['last_learn_date'])) {
                $updateData['last_learn_date'] = $data['last_learn_date'];
            }
        }
        
        Db::name('user_statistics')
            ->where('user_id', $userId)
            ->update($updateData);
        
        return [
            'success' => true,
            'message' => '统计数据更新成功'
        ];
    }
    
    /**
     * 获取用户的学习进度数据（用于下载到客户端）
     * 
     * @param int $userId 用户ID
     * @param int|null $listId 词表ID（可选，不传则返回所有）
     * @param int|null $since 时间戳，只返回此时间之后更新的数据
     * @return array
     */
    public static function getProgressData($userId, $listId = null, $since = null)
    {
        $where = ['user_id' => $userId];
        
        if ($listId) {
            $where['vocabulary_list_id'] = $listId;
        }
        
        $query = Db::name('user_word_progress')->where($where);
        
        if ($since) {
            $query->where('last_review_at', '>', $since);
        }
        
        return $query->select();
    }
    
    /**
     * 获取用户的排除单词数据（用于下载到客户端）
     * 
     * @param int $userId 用户ID
     * @param int|null $listId 词表ID（可选）
     * @return array
     */
    public static function getExclusionData($userId, $listId = null)
    {
        $where = ['user_id' => $userId];
        
        if ($listId) {
            $where['vocabulary_list_id'] = $listId;
        }
        
        return Db::name('user_word_exclusion')
            ->where($where)
            ->select();
    }
    
    /**
     * 计算连续学习天数
     * 
     * @param int $userId 用户ID
     * @return int
     */
    public static function calculateContinuousDays($userId)
    {
        // 获取所有学习记录，按日期降序
        $records = Db::name('daily_learning_record')
            ->where('user_id', $userId)
            ->order('learn_date', 'desc')
            ->column('learn_date');
        
        if (empty($records)) {
            return 0;
        }
        
        $today = date('Y-m-d');
        $yesterday = date('Y-m-d', strtotime('-1 day'));
        
        // 检查今天或昨天是否有学习记录
        if ($records[0] !== $today && $records[0] !== $yesterday) {
            return 0; // 连续记录已中断
        }
        
        $continuousDays = 0;
        $expectedDate = strtotime($records[0]);
        
        foreach ($records as $date) {
            $recordDate = strtotime($date);
            
            if ($recordDate === $expectedDate) {
                $continuousDays++;
                $expectedDate = strtotime('-1 day', $expectedDate);
            } else {
                break; // 连续记录中断
            }
        }
        
        return $continuousDays;
    }
    
    /**
     * 记录每日学习
     * 
     * @param int $userId 用户ID
     * @param string $date 日期 (Y-m-d)
     * @param int $newWordsCount 新学单词数
     * @param int $reviewWordsCount 复习单词数
     * @return bool
     */
    public static function recordDailyLearning($userId, $date, $newWordsCount, $reviewWordsCount)
    {
        // 检查是否已存在
        $exists = Db::name('daily_learning_record')
            ->where('user_id', $userId)
            ->where('learn_date', $date)
            ->find();
        
        if ($exists) {
            // 更新
            return Db::name('daily_learning_record')
                ->where('id', $exists['id'])
                ->update([
                    'new_words_count' => $exists['new_words_count'] + $newWordsCount,
                    'review_words_count' => $exists['review_words_count'] + $reviewWordsCount,
                ]);
        } else {
            // 插入
            return Db::name('daily_learning_record')->insert([
                'user_id' => $userId,
                'learn_date' => $date,
                'new_words_count' => $newWordsCount,
                'review_words_count' => $reviewWordsCount,
                'created_at' => time()
            ]);
        }
    }
}
