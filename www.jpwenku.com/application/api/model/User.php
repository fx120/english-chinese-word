<?php

namespace app\api\model;

use app\common\model\User as CommonUser;

/**
 * API用户模型
 * 说明: 扩展通用用户模型，添加API特定的方法
 */
class User extends CommonUser
{
    /**
     * 定义与词表的多对多关系
     * 一个用户可以下载多个词表
     */
    public function vocabularyLists()
    {
        return $this->belongsToMany('VocabularyList', 'user_vocabulary_list', 'vocabulary_list_id', 'user_id')
            ->withField('downloaded_at,is_custom');
    }
    
    /**
     * 定义与学习进度的一对多关系
     */
    public function wordProgress()
    {
        return $this->hasMany('UserWordProgress', 'user_id');
    }
    
    /**
     * 定义与排除单词的一对多关系
     */
    public function wordExclusions()
    {
        return $this->hasMany('UserWordExclusion', 'user_id');
    }
    
    /**
     * 定义与统计数据的一对一关系
     */
    public function statistics()
    {
        return $this->hasOne('UserStatistics', 'user_id');
    }
    
    /**
     * 根据手机号获取用户
     * @param string $mobile 手机号
     * @return User|null
     */
    public static function getByMobile($mobile)
    {
        return self::where('mobile', $mobile)->find();
    }
    
    /**
     * 创建或获取用户
     * @param string $mobile 手机号
     * @param array $data 用户数据
     * @return User
     */
    public static function createOrGet($mobile, $data = [])
    {
        $user = self::getByMobile($mobile);
        
        if (!$user) {
            $data['mobile'] = $mobile;
            $data['status'] = 'normal';
            $data['created_at'] = time();
            $data['updated_at'] = time();
            
            // 如果没有昵称，使用手机号生成
            if (!isset($data['nickname'])) {
                $data['nickname'] = '用户' . substr($mobile, -4);
            }
            
            $user = self::create($data);
        }
        
        return $user;
    }
}
