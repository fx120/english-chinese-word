<?php

namespace app\admin\model;

use think\Model;

class Word extends Model
{
    // 表名
    protected $name = 'word';
    // 自动写入时间戳字段
    protected $autoWriteTimestamp = 'int';
    // 定义时间戳字段名
    protected $createTime = 'created_at';
    protected $updateTime = 'updated_at';

    // 追加属性
    protected $append = [
        'created_at_text',
    ];

    public function getCreatedAtTextAttr($value, $data)
    {
        $value = $value ? $value : ($data['created_at'] ?? '');
        return is_numeric($value) ? date("Y-m-d H:i:s", $value) : $value;
    }
}
