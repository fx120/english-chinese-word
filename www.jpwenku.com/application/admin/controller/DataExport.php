<?php

namespace app\admin\controller;

use app\common\controller\Backend;
use think\Db;

/**
 * 词库数据导出
 * 
 * 导出词库数据为SQL种子文件，供其他人安装时导入
 *
 * @icon fa fa-database
 */
class DataExport extends Backend
{
    protected $noNeedRight = ['*'];

    /**
     * 导出页面
     */
    public function index()
    {
        // 统计信息
        $stats = [
            'word_count'  => Db::name('word')->count(),
            'list_count'  => Db::name('vocabulary_list')->count(),
            'link_count'  => Db::name('vocabulary_list_word')->count(),
        ];
        $lists = Db::name('vocabulary_list')
            ->field('id, name, category, word_count, is_official')
            ->order('id', 'asc')
            ->select();

        $this->view->assign('stats', $stats);
        $this->view->assign('lists', $lists);
        return $this->view->fetch();
    }

    /**
     * 导出词库SQL
     */
    public function export()
    {
        $listIds = $this->request->post('list_ids', '');
        $exportAll = $this->request->post('export_all/d', 0);

        try {
            $sql = "-- AI背单词 - 词库种子数据\n";
            $sql .= "-- 导出时间: " . date('Y-m-d H:i:s') . "\n";
            $sql .= "-- 使用方法: mysql -u root -p your_db < seed_data.sql\n\n";
            $sql .= "SET NAMES utf8mb4;\nSET FOREIGN_KEY_CHECKS = 0;\n\n";

            // 确定要导出的词表
            if ($exportAll) {
                $lists = Db::name('vocabulary_list')->select();
            } else {
                $ids = array_filter(explode(',', $listIds));
                if (empty($ids)) {
                    $this->error('请选择要导出的词表');
                }
                $lists = Db::name('vocabulary_list')->where('id', 'in', $ids)->select();
            }

            if (empty($lists)) {
                $this->error('没有可导出的词表');
            }

            // 收集所有相关的 word_id
            $listIdArr = array_column($lists, 'id');
            $links = Db::name('vocabulary_list_word')
                ->where('vocabulary_list_id', 'in', $listIdArr)
                ->select();
            $wordIds = array_unique(array_column($links, 'word_id'));

            // 导出单词
            if (!empty($wordIds)) {
                $words = Db::name('word')->where('id', 'in', $wordIds)->select();
                $sql .= "-- 单词数据 (" . count($words) . " 条)\n";
                $sql .= "TRUNCATE TABLE `fa_word`;\n";
                foreach (array_chunk($words, 500) as $chunk) {
                    $sql .= "INSERT INTO `fa_word` (`id`,`word`,`phonetic`,`part_of_speech`,`definition`,`example`,`created_at`,`updated_at`) VALUES\n";
                    $rows = [];
                    foreach ($chunk as $w) {
                        $rows[] = sprintf(
                            "(%d,%s,%s,%s,%s,%s,%s,%s)",
                            $w['id'],
                            self::quote($w['word']),
                            self::quote($w['phonetic']),
                            self::quote($w['part_of_speech']),
                            self::quote($w['definition']),
                            self::quote($w['example']),
                            $w['created_at'] ? $w['created_at'] : 'NULL',
                            $w['updated_at'] ? $w['updated_at'] : 'NULL'
                        );
                    }
                    $sql .= implode(",\n", $rows) . ";\n\n";
                }
            }

            // 导出词表
            $sql .= "-- 词表数据 (" . count($lists) . " 条)\n";
            $sql .= "TRUNCATE TABLE `fa_vocabulary_list`;\n";
            $sql .= "INSERT INTO `fa_vocabulary_list` (`id`,`name`,`description`,`category`,`difficulty_level`,`word_count`,`is_official`,`created_at`,`updated_at`,`status`) VALUES\n";
            $rows = [];
            foreach ($lists as $l) {
                $rows[] = sprintf(
                    "(%d,%s,%s,%s,%d,%d,%d,%s,%s,%s)",
                    $l['id'],
                    self::quote($l['name']),
                    self::quote($l['description']),
                    self::quote($l['category']),
                    $l['difficulty_level'] ?? 1,
                    $l['word_count'] ?? 0,
                    $l['is_official'] ?? 1,
                    $l['created_at'] ? $l['created_at'] : 'NULL',
                    $l['updated_at'] ? $l['updated_at'] : 'NULL',
                    self::quote($l['status'] ?? 'normal')
                );
            }
            $sql .= implode(",\n", $rows) . ";\n\n";

            // 导出关联
            if (!empty($links)) {
                $sql .= "-- 词表单词关联 (" . count($links) . " 条)\n";
                $sql .= "TRUNCATE TABLE `fa_vocabulary_list_word`;\n";
                foreach (array_chunk($links, 1000) as $chunk) {
                    $sql .= "INSERT INTO `fa_vocabulary_list_word` (`id`,`vocabulary_list_id`,`word_id`,`sort_order`,`created_at`) VALUES\n";
                    $rows = [];
                    foreach ($chunk as $lk) {
                        $rows[] = sprintf(
                            "(%d,%d,%d,%d,%s)",
                            $lk['id'],
                            $lk['vocabulary_list_id'],
                            $lk['word_id'],
                            $lk['sort_order'] ?? 0,
                            $lk['created_at'] ? $lk['created_at'] : 'NULL'
                        );
                    }
                    $sql .= implode(",\n", $rows) . ";\n\n";
                }
            }

            $sql .= "SET FOREIGN_KEY_CHECKS = 1;\n";

            // 返回文件下载
            $filename = 'seed_data_' . date('Ymd_His') . '.sql';
            header('Content-Type: application/sql');
            header('Content-Disposition: attachment; filename="' . $filename . '"');
            header('Content-Length: ' . strlen($sql));
            echo $sql;
            exit;

        } catch (\think\exception\HttpResponseException $e) {
            throw $e;
        } catch (\Exception $e) {
            $this->error('导出失败: ' . $e->getMessage());
        }
    }

    /**
     * SQL安全转义
     */
    private static function quote($value)
    {
        if ($value === null || $value === '') {
            return 'NULL';
        }
        return "'" . addslashes($value) . "'";
    }
}
