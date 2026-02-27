<?php

namespace app\api\controller;

use app\common\controller\Api;
use think\Db;
use think\Exception;

/**
 * 词表管理控制器
 * 处理词表列表查询、详情查询、下载、创建等功能
 */
class Vocabulary extends Api
{
    /**
     * 无需登录的方法
     * @var array
     */
    protected $noNeedLogin = ['getList', 'getDetail', 'searchWord'];
    
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
            $corsResponse->send();
            exit;
        }
        
        // Debug: 记录收到的token
        $token = $this->request->server('HTTP_TOKEN', $this->request->request('token', \think\Cookie::get('token')));
        \think\Log::info('[Vocabulary] 收到token: ' . var_export($token, true));
        \think\Log::info('[Vocabulary] 所有headers: ' . json_encode($this->request->header()));
        
        parent::_initialize();
    }
    
    /**
     * 获取词表列表
     * 支持分类筛选和分页
     * 
     * @ApiMethod (GET)
     * @ApiHeaders (name="Authorization", type="string", required=true, description="Bearer {token}")
     * @ApiParams (name="category", type="string", required=false, description="分类筛选")
     * @ApiParams (name="page", type="int", required=false, description="页码，默认1")
     * @ApiParams (name="limit", type="int", required=false, description="每页数量，默认20")
     * @return void
     */
    public function getList()
    {
        $category = $this->request->get('category', '');
        $page = $this->request->get('page/d', 1);
        $limit = $this->request->get('limit/d', 20);
        
        // 验证分页参数
        if ($page < 1) {
            $page = 1;
        }
        if ($limit < 1 || $limit > 100) {
            $limit = 20;
        }
        
        // 构建查询
        $where = [
            'status' => 'normal'
        ];
        
        if (!empty($category)) {
            $where['category'] = $category;
        }
        
        // 查询总数
        $total = Db::name('vocabulary_list')
            ->where($where)
            ->count();
        
        // 查询列表
        $items = Db::name('vocabulary_list')
            ->where($where)
            ->field('id,name,description,category,difficulty_level,word_count,is_official,created_at')
            ->order('created_at', 'desc')
            ->page($page, $limit)
            ->select();
        
        $this->success('success', [
            'total' => $total,
            'page' => $page,
            'limit' => $limit,
            'items' => $items
        ]);
    }

    /**
     * 获取词表详情
     * 包含词表信息和关联的所有单词
     * 
     * @ApiMethod (GET)
     * @ApiHeaders (name="Authorization", type="string", required=true, description="Bearer {token}")
     * @ApiParams (name="id", type="int", required=true, description="词表ID")
     * @return void
     */
    public function getDetail()
    {
        $id = $this->request->get('id/d', 0);
        
        if (!$id) {
            $this->error('词表ID不能为空');
        }
        
        // 查询词表信息
        $vocabularyList = Db::name('vocabulary_list')
            ->where('id', $id)
            ->where('status', 'normal')
            ->find();
        
        if (!$vocabularyList) {
            $this->error('词表不存在');
        }
        
        // 查询关联的单词
        $words = Db::name('vocabulary_list_word')
            ->alias('vlw')
            ->join('word w', 'vlw.word_id = w.id')
            ->where('vlw.vocabulary_list_id', $id)
            ->field('w.id,w.word,w.phonetic,w.part_of_speech,w.definition,w.example,w.created_at,w.updated_at,vlw.sort_order')
            ->order('vlw.sort_order', 'asc')
            ->select();
        
        // 组装返回数据
        $vocabularyList['words'] = $words;
        
        $this->success('success', $vocabularyList);
    }
    
    /**
     * 下载词表
     * 创建用户与词表的关联关系
     * 
     * @ApiMethod (POST)
     * @ApiHeaders (name="Authorization", type="string", required=true, description="Bearer {token}")
     * @ApiParams (name="id", type="int", required=true, description="词表ID")
     * @return void
     */
    public function download()
    {
        $id = $this->request->post('id/d', 0);
        
        if (!$id) {
            $this->error('词表ID不能为空');
        }
        
        // 获取当前用户ID
        $userId = $this->auth->id;
        
        // 查询词表信息
        $vocabularyList = Db::name('vocabulary_list')
            ->where('id', $id)
            ->where('status', 'normal')
            ->find();
        
        if (!$vocabularyList) {
            $this->error('词表不存在');
        }
        
        // 查询词表的所有单词
        $words = Db::name('vocabulary_list_word')
            ->alias('vlw')
            ->join('word w', 'vlw.word_id = w.id')
            ->where('vlw.vocabulary_list_id', $id)
            ->field('w.id,w.word,w.phonetic,w.part_of_speech,w.definition,w.example,w.created_at,w.updated_at,vlw.sort_order')
            ->order('vlw.sort_order', 'asc')
            ->select();
        
        // 记录下载关联（如果不存在则插入）
        $exists = Db::name('user_vocabulary_list')
            ->where('user_id', $userId)
            ->where('vocabulary_list_id', $id)
            ->find();
        
        if (!$exists) {
            try {
                Db::name('user_vocabulary_list')->insert([
                    'user_id' => $userId,
                    'vocabulary_list_id' => $id,
                    'downloaded_at' => time(),
                    'is_custom' => 0
                ]);
            } catch (Exception $e) {
                // 忽略重复插入错误
            }
        }
        
        $this->success('下载成功', [
            'vocabulary_list' => $vocabularyList,
            'words' => $words
        ]);
    }
    
    /**
     * 创建自定义词表
     * 
     * @ApiMethod (POST)
     * @ApiHeaders (name="Authorization", type="string", required=true, description="Bearer {token}")
     * @ApiParams (name="name", type="string", required=true, description="词表名称")
     * @ApiParams (name="description", type="string", required=false, description="词表描述")
     * @ApiParams (name="category", type="string", required=false, description="分类")
     * @ApiParams (name="words", type="array", required=true, description="单词列表")
     * @return void
     */
    public function create()
    {
        $name = $this->request->post('name');
        $description = $this->request->post('description', '');
        $category = $this->request->post('category', 'custom');
        $words = $this->request->post('words/a', []);
        
        // 验证必填字段
        if (empty($name)) {
            $this->error('词表名称不能为空');
        }
        
        if (empty($words) || !is_array($words)) {
            $this->error('单词列表不能为空');
        }
        
        // 获取当前用户ID
        $userId = $this->auth->id;
        
        // 开启事务
        Db::startTrans();
        try {
            // 创建词表
            $vocabularyListId = Db::name('vocabulary_list')->insertGetId([
                'name' => $name,
                'description' => $description,
                'category' => $category,
                'difficulty_level' => 1,
                'word_count' => count($words),
                'is_official' => 0,
                'created_at' => time(),
                'updated_at' => time(),
                'status' => 'normal'
            ]);
            
            // 处理单词列表
            $wordIds = [];
            $sortOrder = 1;
            
            foreach ($words as $wordData) {
                // 验证单词数据
                if (empty($wordData['word']) || empty($wordData['definition'])) {
                    throw new Exception('单词或释义不能为空');
                }
                
                // 检查单词是否已存在
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
                
                // 创建词表单词关联
                Db::name('vocabulary_list_word')->insert([
                    'vocabulary_list_id' => $vocabularyListId,
                    'word_id' => $wordId,
                    'sort_order' => $sortOrder,
                    'created_at' => time()
                ]);
                
                $wordIds[] = $wordId;
                $sortOrder++;
            }
            
            // 创建用户词表关联
            Db::name('user_vocabulary_list')->insert([
                'user_id' => $userId,
                'vocabulary_list_id' => $vocabularyListId,
                'downloaded_at' => time(),
                'is_custom' => 1
            ]);
            
            Db::commit();
            
            $this->success('创建成功', [
                'id' => $vocabularyListId,
                'name' => $name,
                'word_count' => count($words)
            ]);
            
        } catch (Exception $e) {
            Db::rollback();
            $this->error('创建失败: ' . $e->getMessage());
        }
    }
    
    /**
     * 搜索单词（云端词典）
     * 无需登录，支持模糊搜索
     * 
     * @ApiMethod (GET)
     * @ApiParams (name="keyword", type="string", required=true, description="搜索关键词")
     * @ApiParams (name="page", type="int", required=false, description="页码，默认1")
     * @ApiParams (name="limit", type="int", required=false, description="每页数量，默认20")
     * @return void
     */
    public function searchWord()
    {
        $keyword = $this->request->get('keyword', '');
        $page = $this->request->get('page/d', 1);
        $limit = $this->request->get('limit/d', 20);
        
        if (empty($keyword)) {
            $this->error('请输入搜索关键词');
        }
        
        if ($page < 1) $page = 1;
        if ($limit < 1 || $limit > 50) $limit = 20;
        
        $keyword = trim($keyword);
        
        // 搜索 word 和 definition 字段
        $where = function($query) use ($keyword) {
            $query->where('w.word', 'like', '%' . $keyword . '%')
                  ->whereOr('w.definition', 'like', '%' . $keyword . '%');
        };
        
        // 按单词名去重：取每组中信息最完整的一条（优先有音标和例句的）
        // 先查去重后的总数
        $total = Db::name('word')->alias('w')->where($where)
            ->group('LOWER(w.word)')
            ->count('DISTINCT LOWER(w.word)');
        
        // 查去重后的单词（每组取id最小的，通常是最早导入、信息最全的）
        $subQuery = Db::name('word')->alias('w2')->where($where)
            ->field('MIN(w2.id) as min_id')
            ->group('LOWER(w2.word)');
        
        // 由于ThinkPHP子查询写法限制，用原生SQL更清晰
        $offset = ($page - 1) * $limit;
        $likeKeyword = '%' . addslashes($keyword) . '%';
        
        $sql = "SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.definition, w.example
                FROM fa_word w
                INNER JOIN (
                    SELECT MIN(id) as min_id
                    FROM fa_word
                    WHERE word LIKE ? OR definition LIKE ?
                    GROUP BY LOWER(word)
                ) t ON w.id = t.min_id
                ORDER BY w.word ASC
                LIMIT ?, ?";
        
        $words = Db::query($sql, [$likeKeyword, $likeKeyword, $offset, $limit]);
        
        // 查询每个单词所属的词表名称
        if (!empty($words)) {
            $wordNames = array_map(function($w) { return strtolower($w['word']); }, $words);
            $wordNames = array_values(array_unique($wordNames));
            
            // 通过 vocabulary_list_word 关联查出词表名
            $placeholders = implode(',', array_fill(0, count($wordNames), '?'));
            $listSql = "SELECT LOWER(w.word) as word_lower, GROUP_CONCAT(DISTINCT vl.name ORDER BY vl.name SEPARATOR '、') as list_names
                        FROM fa_word w
                        INNER JOIN fa_vocabulary_list_word vlw ON vlw.word_id = w.id
                        INNER JOIN fa_vocabulary_list vl ON vl.id = vlw.vocabulary_list_id
                        WHERE LOWER(w.word) IN ({$placeholders})
                        GROUP BY LOWER(w.word)";
            $listRows = Db::query($listSql, $wordNames);
            
            $listMap = [];
            foreach ($listRows as $row) {
                $listMap[$row['word_lower']] = $row['list_names'];
            }
            
            // 附加词表来源信息
            foreach ($words as &$w) {
                $key = strtolower($w['word']);
                $w['list_names'] = $listMap[$key] ?? '';
            }
            unset($w);
        }
        
        $this->success('success', [
            'total' => $total,
            'page' => $page,
            'limit' => $limit,
            'items' => $words
        ]);
    }
}
