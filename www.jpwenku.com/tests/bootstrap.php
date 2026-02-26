<?php
/**
 * PHPUnit Bootstrap File
 * 初始化测试环境
 */

// 定义应用目录
define('APP_PATH', __DIR__ . '/../application/');

// 定义测试环境
define('RUNTIME_PATH', __DIR__ . '/../runtime/');

// 加载框架引导文件
require __DIR__ . '/../thinkphp/base.php';

// 加载Composer自动加载
require __DIR__ . '/../vendor/autoload.php';

// 设置时区
date_default_timezone_set('Asia/Shanghai');

// 初始化应用
\think\App::initCommon();

// 设置测试环境配置
\think\Config::set([
    'app_debug' => true,
    'app_trace' => false,
]);
