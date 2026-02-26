<?php

namespace app\admin\controller;

use app\common\controller\Backend;
use think\Db;
use think\Exception;

/**
 * 词表管理
 *
 * @icon fa fa-book
 */
class VocabularyList extends Backend
{
    /**
     * @var \app\admin\model\VocabularyList
     */
    protected $model = null;

    public function _initialize()
    {
        parent::_initialize();
        $this->model = new \app\admin\model\VocabularyList;
        $this->view->assign("statusList", $this->model->getStatusList());
        $this->view->assign("isOfficialList", $this->model->getIsOfficialList());
        $this->view->assign("categoryList", $this->model->getCategoryList());
    }

    /**
     * 查看
     */
    public function index()
    {
        $this->request->filter(['strip_tags', 'trim']);
        if ($this->request->isAjax()) {
            if ($this->request->request('keyField')) {
                return $this->selectpage();
            }
            list($where, $sort, $order, $offset, $limit) = $this->buildparams();
            $total = $this->model
                ->where($where)
                ->order($sort, $order)
                ->count();
            $list = $this->model
                ->where($where)
                ->order($sort, $order)
                ->limit($offset, $limit)
                ->select();
            $result = array("total" => $total, "rows" => $list);
            return json($result);
        }
        return $this->view->fetch();
    }

    /**
     * 添加
     */
    public function add()
    {
        if ($this->request->isPost()) {
            $params = $this->request->post("row/a");
            if ($params) {
                $params = $this->preExcludeFields($params);
                if (!isset($params['word_count'])) {
                    $params['word_count'] = 0;
                }
                try {
                    $result = $this->model->allowField(true)->save($params);
                    if ($result !== false) {
                        $this->success();
                    } else {
                        $this->error(__('No rows were inserted'));
                    }
                } catch (\think\exception\PDOException $e) {
                    $this->error($e->getMessage());
                } catch (\think\Exception $e) {
                    $this->error($e->getMessage());
                }
            }
            $this->error(__('Parameter %s can not be empty', ''));
        }
        return $this->view->fetch();
    }

    /**
     * 词表中的单词列表
     */
    public function words($ids = null)
    {
        $row = $this->model->get($ids);
        if (!$row) {
            $this->error(__('No Results were found'));
        }

        if ($this->request->isAjax()) {
            $sort = $this->request->get('sort', 'sort_order');
            $order = $this->request->get('order', 'asc');
            $offset = $this->request->get('offset/d', 0);
            $limit = $this->request->get('limit/d', 50);

            // 白名单限制排序字段
            $allowSort = ['sort_order', 'word', 'id'];
            if (!in_array($sort, $allowSort)) {
                $sort = 'sort_order';
            }
            $order = strtolower($order) === 'desc' ? 'desc' : 'asc';

            $total = Db::name('vocabulary_list_word')
                ->where('vocabulary_list_id', $ids)
                ->count();

            $sortField = in_array($sort, ['word']) ? 'w.' . $sort : 'vlw.' . $sort;
            $list = Db::name('vocabulary_list_word')
                ->alias('vlw')
                ->join('word w', 'vlw.word_id = w.id')
                ->where('vlw.vocabulary_list_id', $ids)
                ->field('vlw.id, w.id as word_id, w.word, w.phonetic, w.part_of_speech, w.definition, w.example, vlw.sort_order')
                ->order($sortField, $order)
                ->limit($offset, $limit)
                ->select();

            return json(["total" => $total, "rows" => $list]);
        }

        $this->view->assign("row", $row);
        return $this->view->fetch();
    }

    /**
     * 向词表添加单词
     */
    public function addword($ids = null)
    {
        $row = $this->model->get($ids);
        if (!$row) {
            $this->error(__('No Results were found'));
        }

        if ($this->request->isPost()) {
            $params = $this->request->post("row/a");
            if ($params) {
                Db::startTrans();
                try {
                    // 每个词表的单词独立创建，允许不同词表对同一单词有不同释义
                    $wordId = Db::name('word')->insertGetId([
                        'word' => $params['word'],
                        'phonetic' => $params['phonetic'] ?? null,
                        'part_of_speech' => $params['part_of_speech'] ?? null,
                        'definition' => $params['definition'],
                        'example' => $params['example'] ?? null,
                        'created_at' => time(),
                        'updated_at' => time(),
                    ]);

                    // 获取最大排序号
                    $maxSort = Db::name('vocabulary_list_word')
                        ->where('vocabulary_list_id', $ids)
                        ->max('sort_order');

                    // 添加关联
                    Db::name('vocabulary_list_word')->insert([
                        'vocabulary_list_id' => $ids,
                        'word_id' => $wordId,
                        'sort_order' => ($maxSort ?: 0) + 1,
                        'created_at' => time(),
                    ]);

                    // 更新词表单词数
                    $wordCount = Db::name('vocabulary_list_word')
                        ->where('vocabulary_list_id', $ids)
                        ->count();
                    $this->model->where('id', $ids)->update([
                        'word_count' => $wordCount,
                        'updated_at' => time(),
                    ]);

                    Db::commit();
                    $this->success();
                } catch (Exception $e) {
                    Db::rollback();
                    $this->error($e->getMessage());
                }
            }
            $this->error(__('Parameter %s can not be empty', ''));
        }

        $this->view->assign("row", $row);
        return $this->view->fetch();
    }

    /**
     * 从其他词表导入单词（支持选择性导入和TXT匹配导入）
     */
    public function importwords($ids = null)
    {
        $row = $this->model->get($ids);
        if (!$row) {
            $this->error(__('No Results were found'));
        }

        if ($this->request->isPost()) {
            $mode = (string)$this->request->post('mode');
            if ($mode === 'txt') {
                return $this->_importFromTxt($ids);
            } elseif ($mode === 'select') {
                return $this->_importSelectedWords($ids);
            }
            $this->error('未知的导入模式');
        }

        // GET: 获取可选的源词表列表
        $lists = Db::name('vocabulary_list')
            ->where('id', '<>', $ids)
            ->where('status', 'normal')
            ->field('id, name, category, word_count')
            ->order('name', 'asc')
            ->select();

        $this->view->assign("row", $row);
        $this->view->assign("lists", $lists);
        return $this->view->fetch();
    }

    /**
     * AJAX: 加载源词表的单词列表（供勾选导入）
     */
    public function loadwords()
    {
        $targetListId = intval($this->request->get('target_id'));
        $sourceListId = intval($this->request->get('source_id'));
        $keyword = (string)$this->request->get('keyword');

        if (!$sourceListId || !$targetListId) {
            $this->error('参数错误');
        }

        $existingWordIds = Db::name('vocabulary_list_word')
            ->where('vocabulary_list_id', $targetListId)
            ->column('word_id');

        $query = Db::name('vocabulary_list_word')
            ->alias('vlw')
            ->join('word w', 'vlw.word_id = w.id')
            ->where('vlw.vocabulary_list_id', $sourceListId);

        if (!empty($keyword)) {
            $query->where('w.word|w.definition', 'like', '%' . $keyword . '%');
        }

        $words = $query
            ->field('w.id, w.word, w.phonetic, w.definition')
            ->order('vlw.sort_order', 'asc')
            ->select();

        foreach ($words as &$w) {
            $w['exists'] = in_array($w['id'], $existingWordIds) ? 1 : 0;
        }

        $this->success('success', null, $words);
    }

    /**
     * TXT文本匹配导入
     */
    private function _importFromTxt($listId)
    {
        $content = (string)$this->request->post('txt_content');
        if (empty($content)) {
            $this->error('请输入或粘贴单词列表');
        }

        $lines = array_filter(array_map('trim', explode("\n", $content)));
        if (empty($lines)) {
            $this->error('未识别到有效单词');
        }

        $matched = Db::name('word')->where('word', 'in', $lines)->column('id', 'word');

        $existingWordIds = Db::name('vocabulary_list_word')
            ->where('vocabulary_list_id', $listId)
            ->column('word_id');

        $importedCount = 0;
        $skippedCount = 0;
        $notFoundWords = [];

        Db::startTrans();
        try {
            $maxSort = Db::name('vocabulary_list_word')
                ->where('vocabulary_list_id', $listId)
                ->max('sort_order') ?: 0;

            $insertData = [];
            foreach ($lines as $word) {
                $wordLower = strtolower(trim($word));
                $wordId = null;
                foreach ($matched as $dbWord => $dbId) {
                    if (strtolower($dbWord) === $wordLower) {
                        $wordId = $dbId;
                        break;
                    }
                }
                if ($wordId === null) {
                    $notFoundWords[] = $word;
                    continue;
                }
                if (in_array($wordId, $existingWordIds)) {
                    $skippedCount++;
                    continue;
                }
                $maxSort++;
                $insertData[] = [
                    'vocabulary_list_id' => (int)$listId,
                    'word_id' => (int)$wordId,
                    'sort_order' => $maxSort,
                    'created_at' => time(),
                ];
                $existingWordIds[] = $wordId;
                $importedCount++;
            }

            if (!empty($insertData)) {
                Db::name('vocabulary_list_word')->insertAll($insertData);
                $wordCount = Db::name('vocabulary_list_word')
                    ->where('vocabulary_list_id', $listId)
                    ->count();
                $this->model->where('id', $listId)->update([
                    'word_count' => $wordCount,
                    'updated_at' => time(),
                ]);
            }

            Db::commit();

            $msg = "成功导入 {$importedCount} 个单词";
            if ($skippedCount > 0) {
                $msg .= "，跳过 {$skippedCount} 个已存在的";
            }
            if (!empty($notFoundWords)) {
                $notFoundCount = count($notFoundWords);
                $msg .= "，{$notFoundCount} 个未在单词库中找到: " . implode(', ', array_slice($notFoundWords, 0, 20));
                if ($notFoundCount > 20) {
                    $msg .= '...';
                }
            }
            $this->success($msg);
        } catch (Exception $e) {
            Db::rollback();
            $this->error($e->getMessage());
        }
    }

    /**
     * 从其他词表选择性导入
     */
    private function _importSelectedWords($listId)
    {
        $wordIds = $this->request->post('word_ids/a', []);
        if (empty($wordIds)) {
            $this->error('请至少选择一个单词');
        }

        $existingWordIds = Db::name('vocabulary_list_word')
            ->where('vocabulary_list_id', $listId)
            ->column('word_id');

        $newWordIds = array_diff($wordIds, $existingWordIds);
        if (empty($newWordIds)) {
            $this->error('所选单词已全部存在于当前词表中');
        }

        Db::startTrans();
        try {
            $maxSort = Db::name('vocabulary_list_word')
                ->where('vocabulary_list_id', $listId)
                ->max('sort_order') ?: 0;

            $insertData = [];
            foreach ($newWordIds as $wordId) {
                $maxSort++;
                $insertData[] = [
                    'vocabulary_list_id' => (int)$listId,
                    'word_id' => (int)$wordId,
                    'sort_order' => $maxSort,
                    'created_at' => time(),
                ];
            }
            Db::name('vocabulary_list_word')->insertAll($insertData);

            $wordCount = Db::name('vocabulary_list_word')
                ->where('vocabulary_list_id', $listId)
                ->count();
            $this->model->where('id', $listId)->update([
                'word_count' => $wordCount,
                'updated_at' => time(),
            ]);

            Db::commit();
            $skipped = count($wordIds) - count($newWordIds);
            $msg = '成功导入 ' . count($newWordIds) . ' 个单词';
            if ($skipped > 0) {
                $msg .= '（跳过 ' . $skipped . ' 个已存在的）';
            }
            $this->success($msg);
        } catch (Exception $e) {
            Db::rollback();
            $this->error($e->getMessage());
        }
    }

    /**
     * JSON词表导入（创建新词表并批量导入单词）
     */
    public function importjson()
    {
        if ($this->request->isPost()) {
            $jsonUrl = (string)$this->request->post('json_url');
            $name = (string)$this->request->post('name');
            $category = (string)$this->request->post('category');
            $description = (string)$this->request->post('description');

            if (empty($jsonUrl)) {
                $this->error('请先上传JSON文件');
            }

            // 如果是相对路径，拼接CDN域名
            if (strpos($jsonUrl, 'http') !== 0) {
                $config = get_addon_config('alioss');
                $cdnUrl = rtrim($config['cdnurl'] ?? '', '/');
                $jsonUrl = $cdnUrl . '/' . ltrim($jsonUrl, '/');
            }

            // 从OSS读取文件内容，设置较长超时
            $ctx = stream_context_create(['http' => ['timeout' => 120]]);
            $content = @file_get_contents($jsonUrl, false, $ctx);
            if (empty($content)) {
                $this->error('无法读取文件内容，请检查文件URL是否正确');
            }

            $entries = $this->_parseJsonVocabulary($content);
            if (empty($entries)) {
                $this->error('未解析到有效的单词数据，请检查JSON格式');
            }

            // 按bookId分组
            $grouped = [];
            foreach ($entries as $entry) {
                $bookId = $entry['bookId'] ?? 'unknown';
                $grouped[$bookId][] = $entry;
            }
            foreach ($grouped as &$group) {
                usort($group, function ($a, $b) {
                    return ($a['wordRank'] ?? 0) - ($b['wordRank'] ?? 0);
                });
            }
            unset($group);

            Db::startTrans();
            try {
                $createdLists = [];
                foreach ($grouped as $bookId => $wordEntries) {
                    $listName = $name;
                    if (count($grouped) > 1) {
                        $bookLabel = $this->_bookIdToName($bookId);
                        $listName = $name ? "{$name} - {$bookLabel}" : $bookLabel;
                    } elseif (empty($listName)) {
                        $listName = $this->_bookIdToName($bookId);
                    }

                    $listId = Db::name('vocabulary_list')->insertGetId([
                        'name'             => $listName,
                        'description'      => $description ?: '从JSON文件导入 (' . count($wordEntries) . '词)',
                        'category'         => $category ?: 'custom',
                        'difficulty_level' => 1,
                        'word_count'       => 0,
                        'is_official'      => 1,
                        'status'           => 'normal',
                        'created_at'       => time(),
                        'updated_at'       => time(),
                    ]);

                    $importedCount = 0;
                    $sortOrder = 0;
                    foreach ($wordEntries as $entry) {
                        $wordText = $entry['headWord'];
                        $phonetic = $entry['phonetic'] ?? null;
                        $partOfSpeech = $entry['partOfSpeech'] ?? null;
                        $definition = $entry['definition'] ?? '';
                        $example = $entry['example'] ?? null;

                        if (empty($wordText) || empty($definition)) {
                            continue;
                        }

                        // 每个词表的单词独立创建，允许不同词表对同一单词有不同释义
                        $wordId = Db::name('word')->insertGetId([
                            'word'           => $wordText,
                            'phonetic'       => $phonetic,
                            'part_of_speech' => $partOfSpeech,
                            'definition'     => $definition,
                            'example'        => $example,
                            'created_at'     => time(),
                            'updated_at'     => time(),
                        ]);

                        $sortOrder++;
                        Db::name('vocabulary_list_word')->insert([
                            'vocabulary_list_id' => $listId,
                            'word_id'            => $wordId,
                            'sort_order'         => $sortOrder,
                            'created_at'         => time(),
                        ]);
                        $importedCount++;
                    }

                    Db::name('vocabulary_list')->where('id', $listId)->update([
                        'word_count'  => $importedCount,
                        'updated_at'  => time(),
                    ]);
                    $createdLists[] = ['name' => $listName, 'count' => $importedCount];
                }

                Db::commit();
                $totalWords = array_sum(array_column($createdLists, 'count'));
                $listCount = count($createdLists);
                $this->success("导入成功：创建了 {$listCount} 个词表，共 {$totalWords} 个单词");
            } catch (Exception $e) {
                Db::rollback();
                $this->error('导入失败: ' . $e->getMessage());
            }
        }

        $categoryList = (new \app\admin\model\VocabularyList)->getCategoryList();
        $this->view->assign("categoryList", $categoryList);
        return $this->view->fetch();
    }

    /**
     * 解析JSON词表内容
     */
    private function _parseJsonVocabulary($content)
    {
        $entries = [];

        // 尝试作为JSON数组
        $decoded = json_decode($content, true);
        if (is_array($decoded) && isset($decoded[0])) {
            foreach ($decoded as $item) {
                $entry = $this->_parseSingleJsonEntry($item);
                if ($entry) {
                    $entries[] = $entry;
                }
            }
            return $entries;
        }

        // 尝试按行解析
        $lines = explode("\n", $content);
        if (count($lines) > 1) {
            foreach ($lines as $line) {
                $line = trim($line);
                if (empty($line)) {
                    continue;
                }
                $item = json_decode($line, true);
                if (is_array($item)) {
                    $entry = $this->_parseSingleJsonEntry($item);
                    if ($entry) {
                        $entries[] = $entry;
                    }
                }
            }
            if (!empty($entries)) {
                return $entries;
            }
        }

        // 尝试拆分连续JSON对象
        $depth = 0;
        $start = 0;
        $len = strlen($content);
        for ($i = 0; $i < $len; $i++) {
            $ch = $content[$i];
            if ($ch === '{') {
                if ($depth === 0) {
                    $start = $i;
                }
                $depth++;
            } elseif ($ch === '}') {
                $depth--;
                if ($depth === 0) {
                    $jsonStr = substr($content, $start, $i - $start + 1);
                    $item = json_decode($jsonStr, true);
                    if (is_array($item)) {
                        $entry = $this->_parseSingleJsonEntry($item);
                        if ($entry) {
                            $entries[] = $entry;
                        }
                    }
                }
            }
        }
        return $entries;
    }

    /**
     * 解析单个JSON词条
     */
    private function _parseSingleJsonEntry($json)
    {
        $headWord = $json['headWord'] ?? null;
        if (empty($headWord)) {
            return null;
        }

        $bookId = $json['bookId'] ?? 'unknown';
        $wordRank = $json['wordRank'] ?? 0;
        $wordContent = $json['content']['word']['content'] ?? [];

        $phonetic = $wordContent['usphone'] ?? $wordContent['ukphone'] ?? $wordContent['phone'] ?? null;

        $trans = $wordContent['trans'] ?? [];
        $partOfSpeech = '';
        $definition = '';
        if (!empty($trans)) {
            $parts = [];
            $posList = [];
            foreach ($trans as $t) {
                $pos = $t['pos'] ?? '';
                $cn = $t['tranCn'] ?? '';
                if (!empty($cn)) {
                    if (!empty($pos)) {
                        $parts[] = "{$pos}. {$cn}";
                        if (!in_array($pos, $posList)) {
                            $posList[] = $pos;
                        }
                    } else {
                        $parts[] = $cn;
                    }
                }
            }
            $definition = implode('；', $parts);
            $partOfSpeech = implode('/', $posList);
        }
        if (empty($definition)) {
            return null;
        }

        $example = null;
        $sentences = $wordContent['sentence']['sentences'] ?? [];
        if (!empty($sentences)) {
            $s = $sentences[0];
            $en = $s['sContent'] ?? '';
            $cn = $s['sCn'] ?? '';
            if (!empty($en)) {
                $example = !empty($cn) ? "{$en}\n{$cn}" : $en;
            }
        }

        return [
            'headWord'     => $headWord,
            'bookId'       => $bookId,
            'wordRank'     => $wordRank,
            'phonetic'     => $phonetic,
            'partOfSpeech' => $partOfSpeech,
            'definition'   => $definition,
            'example'      => $example,
        ];
    }

    /**
     * bookId转可读名称
     */
    private function _bookIdToName($bookId)
    {
        $map = [
            'GaoZhongluan_2'  => '高中核心词汇',
            'ChuZhongluan_2'  => '初中核心词汇',
            'CET4luan_2'      => '四级核心词汇',
            'CET6luan_2'      => '六级核心词汇',
            'KaoYanluan_2'    => '考研核心词汇',
        ];
        return $map[$bookId] ?? str_replace(['_', 'luan'], [' ', ''], $bookId);
    }

    /**
     * 从词表移除单词
     */
    public function delword()
    {
        $vocabulary_list_id = $this->request->post('vocabulary_list_id/d', 0);
        $word_id = $this->request->post('word_id/d', 0);

        if (!$vocabulary_list_id || !$word_id) {
            $this->error('参数错误');
        }

        Db::startTrans();
        try {
            Db::name('vocabulary_list_word')
                ->where('vocabulary_list_id', $vocabulary_list_id)
                ->where('word_id', $word_id)
                ->delete();

            // 更新词表单词数
            $wordCount = Db::name('vocabulary_list_word')
                ->where('vocabulary_list_id', $vocabulary_list_id)
                ->count();
            $this->model->where('id', $vocabulary_list_id)->update([
                'word_count' => $wordCount,
                'updated_at' => time(),
            ]);

            Db::commit();
            $this->success();
        } catch (Exception $e) {
            Db::rollback();
            $this->error($e->getMessage());
        }
    }
}
