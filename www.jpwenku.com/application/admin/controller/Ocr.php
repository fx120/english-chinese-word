<?php

namespace app\admin\controller;

use app\common\controller\Backend;
use app\common\model\Config as ConfigModel;
use think\Db;

/**
 * OCR配置管理
 *
 * @icon fa fa-camera
 */
class Ocr extends Backend
{
    protected $noNeedRight = ['*'];

    /**
     * OCR配置页面
     */
    public function setting()
    {
        // 确保OCR配置项存在于fa_config表中
        $this->ensureConfigExists();

        if ($this->request->isPost()) {
            $params = $this->request->post('row/a');
            if ($params) {
                try {
                    $updates = [
                        'ocr_provider'         => $params['provider'] ?? 'baidu',
                        'ocr_baidu_app_id'     => $params['baidu_app_id'] ?? '',
                        'ocr_baidu_api_key'    => $params['baidu_api_key'] ?? '',
                        'ocr_baidu_secret_key' => $params['baidu_secret_key'] ?? '',
                    ];
                    foreach ($updates as $name => $value) {
                        Db::name('config')->where('name', $name)->update(['value' => $value]);
                    }
                    // 刷新site.php缓存文件
                    ConfigModel::refreshFile();
                    $this->success('配置保存成功');
                } catch (\think\exception\HttpResponseException $e) {
                    throw $e;
                } catch (\Exception $e) {
                    $this->error('保存失败: ' . $e->getMessage());
                }
            }
            $this->error('参数不能为空');
        }

        // 从fa_config表读取当前配置
        $configRows = Db::name('config')
            ->where('name', 'in', ['ocr_provider', 'ocr_baidu_app_id', 'ocr_baidu_api_key', 'ocr_baidu_secret_key'])
            ->column('value', 'name');

        $config = [
            'provider' => $configRows['ocr_provider'] ?? 'baidu',
            'baidu'    => [
                'app_id'     => $configRows['ocr_baidu_app_id'] ?? '',
                'api_key'    => $configRows['ocr_baidu_api_key'] ?? '',
                'secret_key' => $configRows['ocr_baidu_secret_key'] ?? '',
            ],
        ];

        $this->view->assign('config', $config);
        return $this->view->fetch();
    }

    /**
     * 确保OCR配置项存在于fa_config表中
     * 首次访问时自动创建，兼容从旧文件配置迁移
     */
    private function ensureConfigExists()
    {
        $exists = Db::name('config')->where('name', 'ocr_provider')->find();
        if ($exists) {
            return;
        }

        // 尝试从旧配置文件读取已有值
        $oldConfig = config('ocr');
        $oldProvider = $oldConfig['provider'] ?? 'baidu';
        $oldAppId = $oldConfig['baidu']['app_id'] ?? '';
        $oldApiKey = $oldConfig['baidu']['api_key'] ?? '';
        $oldSecretKey = $oldConfig['baidu']['secret_key'] ?? '';
        $oldMaxSize = $oldConfig['max_image_size'] ?? '4194304';

        // 确保configgroup中有ocr分组
        $this->ensureConfigGroup();

        // 插入配置项
        $items = [
            ['name' => 'ocr_provider', 'group' => 'ocr', 'title' => 'OCR服务商', 'tip' => '当前仅支持百度OCR', 'type' => 'select', 'visible' => '', 'value' => $oldProvider, 'content' => json_encode(['baidu' => '百度OCR']), 'rule' => 'required', 'extend' => ''],
            ['name' => 'ocr_baidu_app_id', 'group' => 'ocr', 'title' => '百度App ID', 'tip' => '百度智能云OCR应用的App ID', 'type' => 'string', 'visible' => '', 'value' => $oldAppId, 'content' => '', 'rule' => '', 'extend' => ''],
            ['name' => 'ocr_baidu_api_key', 'group' => 'ocr', 'title' => '百度API Key', 'tip' => '百度智能云OCR应用的API Key', 'type' => 'string', 'visible' => '', 'value' => $oldApiKey, 'content' => '', 'rule' => 'required', 'extend' => ''],
            ['name' => 'ocr_baidu_secret_key', 'group' => 'ocr', 'title' => '百度Secret Key', 'tip' => '百度智能云OCR应用的Secret Key', 'type' => 'string', 'visible' => '', 'value' => $oldSecretKey, 'content' => '', 'rule' => 'required', 'extend' => ''],
            ['name' => 'ocr_max_image_size', 'group' => 'ocr', 'title' => '最大图片大小(字节)', 'tip' => '默认4MB=4194304', 'type' => 'number', 'visible' => '', 'value' => $oldMaxSize, 'content' => '', 'rule' => '', 'extend' => ''],
        ];

        Db::name('config')->insertAll($items);
        // 刷新site.php
        ConfigModel::refreshFile();
    }

    /**
     * 确保configgroup中包含ocr分组
     */
    private function ensureConfigGroup()
    {
        $row = Db::name('config')->where('name', 'configgroup')->find();
        if (!$row) {
            return;
        }

        $value = (array)json_decode($row['value'], true);
        if (empty($value)) {
            // 可能是序列化格式，尝试其他方式
            $value = [];
        }

        if (!isset($value['ocr'])) {
            $value['ocr'] = 'OCR识别';
            Db::name('config')->where('name', 'configgroup')->update([
                'value' => json_encode($value, JSON_UNESCAPED_UNICODE),
            ]);
        }
    }
}
