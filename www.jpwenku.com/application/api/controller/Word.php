<?php

namespace app\api\controller;

use app\common\controller\Api;
use think\Db;
use think\Exception;

/**
 * 单词管理控制器
 * 处理单词的批量添加和更新功能
 */
class Word extends Api
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
     * 批量添加单词到词表
     * 确保单词全局唯一性（通过word字段）
     * 
     * @ApiMethod (POST)
     * @ApiHeaders (name="Authorization", type="string", required=true, description="Bearer {token}")
     * @ApiParams (name="list_id", type="int", required=true, description="词表ID")
     * @ApiParams (name="words", type="array", required=true, description="单词列表")
     * @return void
     */
    public function addToList()
    {
        $listId = $this->request->post('list_id/d', 0);
        $words = $this->request->post('words/a', []);
        
        // 验证必填字段
        if (!$listId) {
            $this->error('词表ID不能为空');
        }
        
        if (empty($words) || !is_array($words)) {
            $this->error('单词列表不能为空');
        }
        
        // 获取当前用户ID
        $userId = $this->auth->id;
        
        // 验证词表是否存在且用户有权限
        $vocabularyList = Db::name('vocabulary_list')
            ->where('id', $listId)
            ->where('status', 'normal')
            ->find();
        
        if (!$vocabularyList) {
            $this->error('词表不存在');
        }
        
        // 检查用户是否有该词表的权限（已下载或是自定义词表的创建者）
        $userVocabularyList = Db::name('user_vocabulary_list')
            ->where('user_id', $userId)
            ->where('vocabulary_list_id', $listId)
            ->find();
        
        if (!$userVocabularyList) {
            $this->error('您没有权限操作该词表');
        }
        
        // 开启事务
        Db::startTrans();
        try {
            $addedCount = 0;
            $wordIds = [];
            
            // 获取当前词表的最大排序号
            $maxSortOrder = Db::name('vocabulary_list_word')
                ->where('vocabulary_list_id', $listId)
                ->max('sort_order');
            
            $sortOrder = $maxSortOrder ? $maxSortOrder + 1 : 1;
            
            foreach ($words as $wordData) {
                // 验证单词数据
                if (empty($wordData['word']) || empty($wordData['definition'])) {
                    throw new Exception('单词或释义不能为空');
                }
                
                // 检查单词是否已存在（全局唯一性）
                $existingWord = Db::name('word')
                    ->where('word', $wordData['word'])
                    ->find();
                
                if ($existingWord) {
                    // 单词已存在，使用现有ID
                    $wordId = $existingWord['id'];
                } else {
                    // 创建新单词
                    $wordId = Db::name('word')->insertGetId([
                        'word' => $wordData['word'],
                        'phonetic' => $wordData['phonetic'] ?? null,
                        'part_of_speech' => $wordData['part_of_speech'] ?? null,
                        'definition' => $wordData['definition'],
                        'example' => $wordData['example'] ?? null,
                        'created_at' => time(),
                        'updated_at' => time()
                    ]);
                }
                
                // 检查单词是否已在该词表中
                $existingRelation = Db::name('vocabulary_list_word')
                    ->where('vocabulary_list_id', $listId)
                    ->where('word_id', $wordId)
                    ->find();
                
                if (!$existingRelation) {
                    // 创建词表单词关联
                    Db::name('vocabulary_list_word')->insert([
                        'vocabulary_list_id' => $listId,
                        'word_id' => $wordId,
                        'sort_order' => $sortOrder,
                        'created_at' => time()
                    ]);
                    
                    $addedCount++;
                    $sortOrder++;
                }
                
                $wordIds[] = $wordId;
            }
            
            // 更新词表的单词总数
            $totalWordCount = Db::name('vocabulary_list_word')
                ->where('vocabulary_list_id', $listId)
                ->count();
            
            Db::name('vocabulary_list')
                ->where('id', $listId)
                ->update([
                    'word_count' => $totalWordCount,
                    'updated_at' => time()
                ]);
            
            Db::commit();
            
            $this->success('添加成功', [
                'added_count' => $addedCount,
                'word_ids' => $wordIds
            ]);
            
        } catch (Exception $e) {
            Db::rollback();
            $this->error('添加失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 更新单词信息
     * 
     * @ApiMethod (POST)
     * @ApiHeaders (name="Authorization", type="string", required=true, description="Bearer {token}")
     * @ApiParams (name="id", type="int", required=true, description="单词ID")
     * @ApiParams (name="phonetic", type="string", required=false, description="音标")
     * @ApiParams (name="part_of_speech", type="string", required=false, description="词性")
     * @ApiParams (name="definition", type="string", required=false, description="释义")
     * @ApiParams (name="example", type="string", required=false, description="例句")
     * @return void
     */
    public function update()
    {
        $id = $this->request->post('id/d', 0);
        
        if (!$id) {
            $this->error('单词ID不能为空');
        }
        
        // 查询单词是否存在
        $word = Db::name('word')
            ->where('id', $id)
            ->find();
        
        if (!$word) {
            $this->error('单词不存在');
        }
        
        // 获取更新数据
        $updateData = [];
        
        // 只更新提供的字段
        if ($this->request->has('phonetic')) {
            $updateData['phonetic'] = $this->request->post('phonetic');
        }
        
        if ($this->request->has('part_of_speech')) {
            $updateData['part_of_speech'] = $this->request->post('part_of_speech');
        }
        
        if ($this->request->has('definition')) {
            $definition = $this->request->post('definition');
            if (empty($definition)) {
                $this->error('释义不能为空');
            }
            $updateData['definition'] = $definition;
        }
        
        if ($this->request->has('example')) {
            $updateData['example'] = $this->request->post('example');
        }
        
        if (empty($updateData)) {
            $this->error('没有需要更新的字段');
        }
        
        // 添加更新时间
        $updateData['updated_at'] = time();
        
        // 开启事务
        Db::startTrans();
        try {
            // 更新单词信息
            Db::name('word')
                ->where('id', $id)
                ->update($updateData);
            
            // 查询更新后的单词信息
            $updatedWord = Db::name('word')
                ->where('id', $id)
                ->find();
            
            Db::commit();
            
            $this->success('更新成功', $updatedWord);
            
        } catch (Exception $e) {
            Db::rollback();
            $this->error('更新失败: ' . $e->getMessage());
        }
    }
}
