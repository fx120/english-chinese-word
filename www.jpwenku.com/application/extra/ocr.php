<?php

// OCR识别配置
// 可在FastAdmin后台 系统管理 > OCR配置 中修改
return [
    // OCR服务提供商: baidu
    'provider'       => 'baidu',

    // 百度OCR配置
    'baidu'          => [
        'app_id'     => '',
        'api_key'    => '',
        'secret_key' => '',
    ],

    // 通用设置
    'max_image_size' => 4194304, // 最大图片大小 4MB
    'allowed_types'  => 'jpg,jpeg,png,bmp',
];
