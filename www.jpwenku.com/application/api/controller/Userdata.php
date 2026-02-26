<?php

namespace app\api\controller;

use app\common\controller\Api;
use think\Db;
use think\Exception;

/**
 * 用户数据同步控制器
 * 处理用户学习进度、排除单词、学习统计的同步功能
 */
class Userdata extends Api
{
    /**
     * 无需登录的方法
     * @var array
     */
    protected $noNeedLogin = [];
    
    /**
     * 无需鉴权的方法
     * @var array
     */
    protected $noNeedRight = '*';
    
    /**
     * 初始化
     */
    public function _initialize()
    {
        // 处理CORS跨域请求
        $corsResponse = \app\api\library\Cors::handle();
        if ($corsResponse !== null) {
            // OPTIONS预检请求直接返回
            $corsResponse->send();
            exit;
        }
        
        parent::_initialize();
    }
    
    /**
     * 同步学习进度
     * 将客户端的学习进度数据同步到服务器
     * 冲突解决策略：保留记忆级别更高的数据
     * 
     * @ApiMethod (POST)
     * @ApiHeaders (name="Authorization", type="string", required=true, description="Bearer {token}")
     * @ApiParams (name="progress_data", type="array", required=true, description="学习进度数据列表")
     * @return void
     */
    public function syncProgress()
    {
        $progressData = $this->request->post('progress_data/a', []);
        
        // 验证必填字段
        if (empty($progressData) || !is_array($progressData)) {
            $this->error('学习进度数据不能为空');
        }
        
        // 获取当前用户ID
        $userId = $this->auth->id;
        
        // 开启事务
        Db::startTrans();
        try {
            $syncedCount = 0;
            $conflicts = [];
            
            foreach ($progressData as $progress) {
                // 验证必填字段
                if (empty($progress['word_id']) || empty($progress['vocabulary_list_id'])) {
                    throw new Exception('单词ID和词表ID不能为空');
                }
                
                $wordId = $progress['word_id'];
                $vocabularyListId = $progress['vocabulary_list_id'];
                
                // 检查服务器端是否已有该记录
                $existingProgress = Db::name('user_word_progress')
                    ->where('user_id', $userId)
                    ->where('word_id', $wordId)
                    ->where('vocabulary_list_id', $vocabularyListId)
                    ->find();
                
                if ($existingProgress) {
                    // 存在冲突，需要解决
                    $resolved = $this->resolveProgressConflict($existingProgress, $progress);
                    
                    if ($resolved['updated']) {
                        // 更新服务器端数据
                        Db::name('user_word_progress')
                            ->where('id', $existingProgress['id'])
                            ->update($resolved['data']);
                        
                        $syncedCount++;
                        
                        if ($resolved['conflict']) {
                            $conflicts[] = [
                                'word_id' => $wordId,
                                'vocabulary_list_id' => $vocabularyListId,
                                'resolution' => $resolved['resolution']
                            ];
                        }
                    }
                } else {
                    // 不存在，直接插入
                    $insertData = [
                        'user_id' => $userId,
                        'word_id' => $wordId,
                        'vocabulary_list_id' => $vocabularyListId,
                        'status' => $progress['status'] ?? 'not_learned',
                        'learned_at' => $progress['learned_at'] ?? null,
                        'last_review_at' => $progress['last_review_at'] ?? null,
                        'next_review_at' => $progress['next_review_at'] ?? null,
                        'review_count' => $progress['review_count'] ?? 0,
                        'error_count' => $progress['error_count'] ?? 0,
                        'memory_level' => $progress['memory_level'] ?? 0
                    ];
                    
                    Db::name('user_word_progress')->insert($insertData);
                    $syncedCount++;
                }
            }
            
            Db::commit();
            
            $this->success('同步成功', [
                'synced_count' => $syncedCount,
                'conflicts' => $conflicts
            ]);
            
        } catch (Exception $e) {
            Db::rollback();
            $this->error('同步失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 同步排除单词
     * 将客户端的排除单词数据同步到服务器
     * 
     * @ApiMethod (POST)
     * @ApiHeaders (name="Authorization", type="string", required=true, description="Bearer {token}")
     * @ApiParams (name="exclusions", type="array", required=true, description="排除单词数据列表")
     * @return void
     */
    public function syncExclusions()
    {
        $exclusions = $this->request->post('exclusions/a', []);
        
        // 验证必填字段
        if (empty($exclusions) || !is_array($exclusions)) {
            $this->error('排除单词数据不能为空');
        }
        
        // 获取当前用户ID
        $userId = $this->auth->id;
        
        // 开启事务
        Db::startTrans();
        try {
            $syncedCount = 0;
            
            foreach ($exclusions as $exclusion) {
                // 验证必填字段
                if (empty($exclusion['word_id']) || empty($exclusion['vocabulary_list_id'])) {
                    throw new Exception('单词ID和词表ID不能为空');
                }
                
                $wordId = $exclusion['word_id'];
                $vocabularyListId = $exclusion['vocabulary_list_id'];
                
                // 检查是否已存在
                $existingExclusion = Db::name('user_word_exclusion')
                    ->where('user_id', $userId)
                    ->where('word_id', $wordId)
                    ->where('vocabulary_list_id', $vocabularyListId)
                    ->find();
                
                if (!$existingExclusion) {
                    // 不存在，插入新记录
                    Db::name('user_word_exclusion')->insert([
                        'user_id' => $userId,
                        'word_id' => $wordId,
                        'vocabulary_list_id' => $vocabularyListId,
                        'excluded_at' => $exclusion['excluded_at'] ?? time()
                    ]);
                    
                    $syncedCount++;
                }
            }
            
            Db::commit();
            
            $this->success('同步成功', [
                'synced_count' => $syncedCount
            ]);
            
        } catch (Exception $e) {
            Db::rollback();
            $this->error('同步失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 获取学习统计
     * 返回用户的学习统计数据和每日学习记录
     * 
     * @ApiMethod (GET)
     * @ApiHeaders (name="Authorization", type="string", required=true, description="Bearer {token}")
     * @return void
     */
    public function getStatistics()
    {
        // 获取当前用户ID
        $userId = $this->auth->id;
        
        try {
            // 查询用户统计数据
            $statistics = Db::name('user_statistics')
                ->where('user_id', $userId)
                ->find();
            
            if (!$statistics) {
                // 如果不存在，创建默认统计数据
                $statistics = [
                    'total_days' => 0,
                    'continuous_days' => 0,
                    'total_words_learned' => 0,
                    'total_words_mastered' => 0,
                    'last_learn_date' => null,
                    'updated_at' => time()
                ];
            }
            
            // 查询最近30天的每日学习记录
            $dailyRecords = $this->getDailyRecords($userId, 30);
            
            // 计算实时统计数据（从学习进度表）
            $realtimeStats = $this->calculateRealtimeStatistics($userId);
            
            // 合并统计数据（使用实时数据更新）
            $statistics['total_words_learned'] = $realtimeStats['total_words_learned'];
            $statistics['total_words_mastered'] = $realtimeStats['total_words_mastered'];
            
            $this->success('success', [
                'total_days' => (int)$statistics['total_days'],
                'continuous_days' => (int)$statistics['continuous_days'],
                'total_words_learned' => (int)$statistics['total_words_learned'],
                'total_words_mastered' => (int)$statistics['total_words_mastered'],
                'last_learn_date' => $statistics['last_learn_date'],
                'daily_records' => $dailyRecords
            ]);
            
        } catch (Exception $e) {
            $this->error('获取统计数据失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 解决学习进度同步冲突
     * 策略：保留记忆级别更高的数据；如果记忆级别相同，保留复习次数更多的数据
     * 
     * @param array $serverData 服务器端数据
     * @param array $clientData 客户端数据
     * @return array 解决结果
     */
    private function resolveProgressConflict($serverData, $clientData)
    {
        $serverMemoryLevel = (int)$serverData['memory_level'];
        $clientMemoryLevel = (int)($clientData['memory_level'] ?? 0);
        
        $serverReviewCount = (int)$serverData['review_count'];
        $clientReviewCount = (int)($clientData['review_count'] ?? 0);
        
        $conflict = false;
        $resolution = '';
        $updated = false;
        $data = [];
        
        // 比较记忆级别
        if ($clientMemoryLevel > $serverMemoryLevel) {
            // 客户端记忆级别更高，使用客户端数据
            $conflict = true;
            $resolution = 'client_higher_memory_level';
            $updated = true;
            $data = [
                'status' => $clientData['status'] ?? $serverData['status'],
                'learned_at' => $clientData['learned_at'] ?? $serverData['learned_at'],
                'last_review_at' => $clientData['last_review_at'] ?? $serverData['last_review_at'],
                'next_review_at' => $clientData['next_review_at'] ?? $serverData['next_review_at'],
                'review_count' => $clientReviewCount,
                'error_count' => $clientData['error_count'] ?? $serverData['error_count'],
                'memory_level' => $clientMemoryLevel
            ];
        } elseif ($clientMemoryLevel < $serverMemoryLevel) {
            // 服务器端记忆级别更高，保留服务器端数据
            $conflict = true;
            $resolution = 'server_higher_memory_level';
            $updated = false;
        } else {
            // 记忆级别相同，比较复习次数
            if ($clientReviewCount > $serverReviewCount) {
                // 客户端复习次数更多，使用客户端数据
                $conflict = true;
                $resolution = 'client_higher_review_count';
                $updated = true;
                $data = [
                    'status' => $clientData['status'] ?? $serverData['status'],
                    'learned_at' => $clientData['learned_at'] ?? $serverData['learned_at'],
                    'last_review_at' => $clientData['last_review_at'] ?? $serverData['last_review_at'],
                    'next_review_at' => $clientData['next_review_at'] ?? $serverData['next_review_at'],
                    'review_count' => $clientReviewCount,
                    'error_count' => $clientData['error_count'] ?? $serverData['error_count'],
                    'memory_level' => $clientMemoryLevel
                ];
            } elseif ($clientReviewCount < $serverReviewCount) {
                // 服务器端复习次数更多，保留服务器端数据
                $conflict = true;
                $resolution = 'server_higher_review_count';
                $updated = false;
            } else {
                // 记忆级别和复习次数都相同，比较最后复习时间
                $serverLastReview = $serverData['last_review_at'] ?? 0;
                $clientLastReview = $clientData['last_review_at'] ?? 0;
                
                if ($clientLastReview > $serverLastReview) {
                    // 客户端更新时间更晚，使用客户端数据
                    $conflict = true;
                    $resolution = 'client_more_recent';
                    $updated = true;
                    $data = [
                        'status' => $clientData['status'] ?? $serverData['status'],
                        'learned_at' => $clientData['learned_at'] ?? $serverData['learned_at'],
                        'last_review_at' => $clientLastReview,
                        'next_review_at' => $clientData['next_review_at'] ?? $serverData['next_review_at'],
                        'review_count' => $clientReviewCount,
                        'error_count' => $clientData['error_count'] ?? $serverData['error_count'],
                        'memory_level' => $clientMemoryLevel
                    ];
                } else {
                    // 服务器端更新时间更晚或相同，保留服务器端数据
                    $updated = false;
                }
            }
        }
        
        return [
            'conflict' => $conflict,
            'resolution' => $resolution,
            'updated' => $updated,
            'data' => $data
        ];
    }
    
    /**
     * 获取每日学习记录
     * 
     * @param int $userId 用户ID
     * @param int $days 天数
     * @return array 每日学习记录列表
     */
    private function getDailyRecords($userId, $days = 30)
    {
        // 计算起始日期
        $startDate = date('Y-m-d', strtotime("-{$days} days"));
        
        // 查询每日学习记录
        // 注意：这里假设有一个daily_learning_record表，如果没有则需要从user_word_progress表统计
        $records = Db::name('user_word_progress')
            ->where('user_id', $userId)
            ->where('learned_at', '>=', strtotime($startDate))
            ->field('FROM_UNIXTIME(learned_at, "%Y-%m-%d") as date, COUNT(*) as new_words_count')
            ->group('date')
            ->order('date', 'desc')
            ->select();
        
        // 格式化返回数据
        $dailyRecords = [];
        foreach ($records as $record) {
            $dailyRecords[] = [
                'date' => $record['date'],
                'new_words_count' => (int)$record['new_words_count'],
                'review_words_count' => 0 // 这里可以进一步统计复习单词数
            ];
        }
        
        return $dailyRecords;
    }
    
    /**
     * 计算实时统计数据
     * 从user_word_progress表统计实时数据
     * 
     * @param int $userId 用户ID
     * @return array 统计数据
     */
    private function calculateRealtimeStatistics($userId)
    {
        // 统计总学习单词数（learned_at不为空）
        $totalWordsLearned = Db::name('user_word_progress')
            ->where('user_id', $userId)
            ->where('learned_at', 'not null')
            ->count();
        
        // 统计已掌握单词数（status = 'mastered'）
        $totalWordsMastered = Db::name('user_word_progress')
            ->where('user_id', $userId)
            ->where('status', 'mastered')
            ->count();
        
        return [
            'total_words_learned' => $totalWordsLearned,
            'total_words_mastered' => $totalWordsMastered
        ];
    }
}
