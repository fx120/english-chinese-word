<?php

namespace app\admin\model;

use think\Model;

class VocabularyList extends Model
{
    // 表名
    protected $name = 'vocabulary_list';
    // 自动写入时间戳字段
    protected $autoWriteTimestamp = 'int';
    // 定义时间戳字段名
    protected $createTime = 'created_at';
    protected $updateTime = 'updated_at';

    // 追加属性
    protected $append = [
        'status_text',
        'is_official_text',
        'created_at_text',
    ];

    public function getStatusList()
    {
        return ['normal' => __('Normal'), 'hidden' => __('Hidden')];
    }

    public function getIsOfficialList()
    {
        return ['0' => '自定义', '1' => '官方'];
    }

    public function getCategoryList()
    {
        return [
            '高中' => '高中',
            '初中' => '初中',
            'CET4' => 'CET4',
            'CET6' => 'CET6',
            '考研' => '考研',
            'TOEFL' => 'TOEFL',
            'IELTS' => 'IELTS',
            '人教版' => '人教版',
            '外研社版' => '外研社版',
            'custom' => '自定义',
        ];
    }

    public function getStatusTextAttr($value, $data)
    {
        $list = $this->getStatusList();
        return isset($list[$data['status']]) ? $list[$data['status']] : '';
    }

    public function getIsOfficialTextAttr($value, $data)
    {
        $list = $this->getIsOfficialList();
        return isset($list[$data['is_official']]) ? $list[$data['is_official']] : '';
    }

    public function getCreatedAtTextAttr($value, $data)
    {
        $value = $value ? $value : ($data['created_at'] ?? '');
        return is_numeric($value) ? date("Y-m-d H:i:s", $value) : $value;
    }
}
