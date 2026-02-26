<?php

/**
 * API路由配置
 * FastAdmin使用 /api/{controller}.php?action={method} 格式
 * 
 * 路由规则说明：
 * 1. 认证相关：/api/auth.php?action={method}
 * 2. 词表管理：/api/vocabulary.php?action={method}
 * 3. 单词管理：/api/word.php?action={method}
 * 4. 用户数据：/api/userdata.php?action={method}
 */

use think\Route;

// 认证相关路由
Route::get('api/auth/sendCode', 'api/auth/sendCode');
Route::post('api/auth/sendCode', 'api/auth/sendCode');
Route::post('api/auth/login', 'api/auth/login');
Route::post('api/auth/refresh', 'api/auth/refresh');

// 词表管理路由
Route::get('api/vocabulary/getList', 'api/vocabulary/getList');
Route::get('api/vocabulary/getDetail', 'api/vocabulary/getDetail');
Route::post('api/vocabulary/download', 'api/vocabulary/download');
Route::post('api/vocabulary/create', 'api/vocabulary/create');

// 单词管理路由
Route::post('api/word/addToList', 'api/word/addToList');
Route::post('api/word/update', 'api/word/update');

// 用户数据同步路由
Route::post('api/userdata/syncProgress', 'api/userdata/syncProgress');
Route::post('api/userdata/syncExclusions', 'api/userdata/syncExclusions');
Route::get('api/userdata/getStatistics', 'api/userdata/getStatistics');

return [];
