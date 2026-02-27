<?php

namespace app\common\library;

use think\Config;
use think\Log;

/**
 * OCR识别服务
 * 支持百度OCR API，用于识别课本单词表图片
 */
class OcrService
{
    /**
     * 百度access_token缓存
     */
    private static $accessToken = null;
    private static $tokenExpireTime = 0;

    /**
     * 识别图片中的文字
     *
     * @param string $imageBase64 图片base64编码（不含data:image前缀）
     * @return array ['lines' => [...], 'words' => [...]]
     */
    public static function recognize($imageBase64)
    {
        $provider = self::getConfig('ocr_provider', 'baidu');

        if ($provider === 'baidu') {
            $baiduConfig = [
                'app_id'     => self::getConfig('ocr_baidu_app_id', ''),
                'api_key'    => self::getConfig('ocr_baidu_api_key', ''),
                'secret_key' => self::getConfig('ocr_baidu_secret_key', ''),
            ];
            return self::baiduOcr($imageBase64, $baiduConfig);
        }

        throw new \Exception('不支持的OCR服务商: ' . $provider);
    }

    /**
     * 读取OCR配置项
     * 优先从fa_config表(site配置)读取，兼容旧的extra/ocr.php文件配置
     */
    private static function getConfig($key, $default = '')
    {
        // 优先从fa_config表读取（通过site配置）
        $value = config('site.' . $key);
        if ($value !== null && $value !== '') {
            return $value;
        }

        // 兼容旧配置文件 application/extra/ocr.php
        $ocrConfig = Config::get('ocr');
        if ($ocrConfig) {
            $map = [
                'ocr_provider'          => 'provider',
                'ocr_baidu_app_id'      => ['baidu', 'app_id'],
                'ocr_baidu_api_key'     => ['baidu', 'api_key'],
                'ocr_baidu_secret_key'  => ['baidu', 'secret_key'],
                'ocr_max_image_size'    => 'max_image_size',
            ];
            if (isset($map[$key])) {
                $path = $map[$key];
                if (is_array($path)) {
                    return $ocrConfig[$path[0]][$path[1]] ?? $default;
                }
                return $ocrConfig[$path] ?? $default;
            }
        }

        return $default;
    }

    /**
     * 百度OCR通用文字识别（高精度版）
     */
    private static function baiduOcr($imageBase64, $baiduConfig)
    {
        $apiKey = $baiduConfig['api_key'] ?? '';
        $secretKey = $baiduConfig['secret_key'] ?? '';

        if (empty($apiKey) || empty($secretKey)) {
            throw new \Exception('百度OCR未配置，请在后台设置API Key和Secret Key');
        }

        // 获取access_token
        $accessToken = self::getBaiduAccessToken($apiKey, $secretKey);

        // 调用通用文字识别（高精度含位置版）
        $url = 'https://aip.baidubce.com/rest/2.0/ocr/v1/accurate?access_token=' . $accessToken;

        $postData = [
            'image'            => $imageBase64,
            'detect_direction' => 'true',
            'paragraph'        => 'true',
        ];

        $response = self::httpPost($url, http_build_query($postData), [
            'Content-Type: application/x-www-form-urlencoded',
        ]);

        $result = json_decode($response, true);

        if (isset($result['error_code'])) {
            Log::error('[OCR] 百度OCR错误: ' . json_encode($result));
            throw new \Exception('OCR识别失败: ' . ($result['error_msg'] ?? '未知错误'));
        }

        // 提取文字行（带位置坐标）
        $rawItems = [];
        if (isset($result['words_result']) && is_array($result['words_result'])) {
            foreach ($result['words_result'] as $item) {
                $text = trim($item['words'] ?? '');
                if (!empty($text)) {
                    $loc = $item['location'] ?? [];
                    $rawItems[] = [
                        'text' => $text,
                        'left' => $loc['left'] ?? 0,
                        'top'  => $loc['top'] ?? 0,
                    ];
                }
            }
        }

        // 按双列排版重排序：先左列后右列，各列内按从上到下
        $rawItems = self::reorderByColumns($rawItems);

        $lines = array_map(function ($item) {
            return $item['text'];
        }, $rawItems);

        // 解析单词表
        Log::info('[OCR] 识别到的原始文字行: ' . json_encode($lines, JSON_UNESCAPED_UNICODE));
        $words = self::parseVocabularyLines($lines);
        Log::info('[OCR] 解析出单词数: ' . count($words));

        // 从数据库匹配音标，替换OCR识别的不准确音标
        $words = self::enrichFromDatabase($words);

        return [
            'lines'      => $lines,
            'words'      => $words,
            'words_count' => count($words),
            'lines_count' => count($lines),
        ];
    }

    /**
     * 获取百度access_token
     */
    private static function getBaiduAccessToken($apiKey, $secretKey)
    {
        // 检查缓存
        if (self::$accessToken && time() < self::$tokenExpireTime) {
            return self::$accessToken;
        }

        // 尝试从缓存文件读取
        $cacheFile = RUNTIME_PATH . 'baidu_ocr_token.json';
        if (file_exists($cacheFile)) {
            $cached = json_decode(file_get_contents($cacheFile), true);
            if ($cached && isset($cached['access_token']) && time() < ($cached['expire_time'] ?? 0)) {
                self::$accessToken = $cached['access_token'];
                self::$tokenExpireTime = $cached['expire_time'];
                return self::$accessToken;
            }
        }

        $url = 'https://aip.baidubce.com/oauth/2.0/token';
        $postData = http_build_query([
            'grant_type'    => 'client_credentials',
            'client_id'     => $apiKey,
            'client_secret' => $secretKey,
        ]);

        $response = self::httpPost($url, $postData, [
            'Content-Type: application/x-www-form-urlencoded',
        ]);

        $result = json_decode($response, true);

        if (!isset($result['access_token'])) {
            Log::error('[OCR] 获取百度access_token失败: ' . json_encode($result));
            throw new \Exception('获取OCR授权失败，请检查API Key和Secret Key配置');
        }

        self::$accessToken = $result['access_token'];
        self::$tokenExpireTime = time() + ($result['expires_in'] ?? 2592000) - 600;

        // 写入缓存文件
        @file_put_contents($cacheFile, json_encode([
            'access_token' => self::$accessToken,
            'expire_time'  => self::$tokenExpireTime,
        ]));

        return self::$accessToken;
    }

    /**
     * 解析OCR识别的文字行为单词列表
     * 
     * 支持常见课本词表格式：
     * - "word 释义"
     * - "word  /fəˈnetɪk/  释义"
     * - "1. word 释义"
     * - "word n./v./adj. 释义"
     * - "candy/'kaendi/糖果" (课本斜杠分隔格式)
     * - "classroom/'kla:sru:m/教室  p.5"
     * - "teacher's desk讲台"
     */
    private static function parseVocabularyLines($lines)
    {
        $words = [];
        foreach ($lines as $line) {
            $parsed = self::parseSingleLine($line);
            if ($parsed) {
                $words[] = $parsed;
            }
        }
        return $words;
    }

    /**
     * 解析单行文本为单词条目
     */
    private static function parseSingleLine($line)
    {
        $line = trim($line);
        if (empty($line)) {
            return null;
        }

        // 去掉行首星号 "*whose" → "whose"（课本中*表示重点词）
        $line = preg_replace('/^\*+\s*/', '', $line);

        // 去掉行首序号 "1." "1、" "1)" "(1)"
        $line = preg_replace('/^[\(\（]?\d+[\.\、\)\）]\s*/', '', $line);

        // 去掉行尾页码 "p.18" "p.5" "P18"
        $line = preg_replace('/\s*[pP]\.?\s*\d+\s*$/', '', $line);
        $line = trim($line);

        if (empty($line)) {
            return null;
        }

        // 跳过纯中文行、标题行、说明行
        if (preg_match('/^[\x{4e00}-\x{9fff}\x{ff00}-\x{ffef}\s\(\)（）：:，,。\.、；;！!？?]+$/u', $line)) {
            return null;
        }
        // 跳过 "Unit 1" 等章节标题
        if (preg_match('/^Unit\s+\d+$/i', $line)) {
            return null;
        }
        // 跳过纯英文标题行
        if (preg_match('/^[A-Z][a-z]+(\s+[a-z]+)*$/', $line) && !preg_match('/[\x{4e00}-\x{9fff}\/]/u', $line)) {
            return null;
        }
        // 跳过纯数字
        if (preg_match('/^\d+$/', $line)) {
            return null;
        }

        // ===== 模式1: 课本斜杠格式 =====
        // candy/'kaendi/糖果
        // classroom/'kla:sru:m/教室
        // window /'windeu/窗户
        // computer/kem'pju:te(r)/计算机
        // really/'rieli/(表示兴趣或惊讶)真的
        // so much /mvtf/非常地
        if (preg_match('/^([a-zA-Z][a-zA-Z\s\-\'\.]+?)\s*\/([^\/]+)\/(.+)$/u', $line, $matches)) {
            $word = trim($matches[1]);
            $phonetic = trim($matches[2]);
            $definition = trim($matches[3]);

            // 过滤太长的（可能是句子）
            if (strlen($word) < 1 || strlen($word) > 50) {
                return null;
            }

            // 释义可能以中文开头，也可能以(开头如 (lose的过去式形式)
            // 去掉释义中可能残留的页码
            $definition = preg_replace('/\s*[pP]\.?\s*\d+\s*$/', '', $definition);
            $definition = trim($definition);

            if (empty($definition)) {
                return null;
            }

            return [
                'word'           => $word,
                'phonetic'       => $phonetic,
                'part_of_speech' => null,
                'definition'     => $definition,
            ];
        }

        // ===== 模式2: 英文单词 + 空格/音标/词性 + 中文释义 =====
        // word /phonetic/ pos. 释义
        if (preg_match('/^([a-zA-Z][a-zA-Z\s\-\']*?)\s+(?:\/([^\/]+)\/\s+)?(?:((?:n|v|adj|adv|prep|conj|pron|det|int|vi|vt|aux)\.(?:\s*\/\s*(?:n|v|adj|adv|prep|conj|pron|det|int|vi|vt|aux)\.)*)\s+)?([\x{4e00}-\x{9fff}\(（].+)$/u', $line, $matches)) {
            $word = trim($matches[1]);
            if (strlen($word) < 1 || strlen($word) > 40 || str_word_count($word) > 5) {
                return null;
            }
            $def = trim($matches[4]);
            $def = preg_replace('/\s*[pP]\.?\s*\d+\s*$/', '', $def);
            if (empty($def)) {
                return null;
            }
            return [
                'word'           => $word,
                'phonetic'       => !empty($matches[2]) ? $matches[2] : null,
                'part_of_speech' => !empty($matches[3]) ? $matches[3] : null,
                'definition'     => $def,
            ];
        }

        // ===== 模式3: 英文单词直接跟中文（无分隔符） =====
        // teacher's desk讲台
        // storybook故事书
        if (preg_match('/^([a-zA-Z][a-zA-Z\s\-\'\.]*[a-zA-Z])([\x{4e00}-\x{9fff}].+)$/u', $line, $matches)) {
            $word = trim($matches[1]);
            $definition = trim($matches[2]);
            if (strlen($word) < 1 || strlen($word) > 40) {
                return null;
            }
            $definition = preg_replace('/\s*[pP]\.?\s*\d+\s*$/', '', $definition);
            if (empty($definition)) {
                return null;
            }
            return [
                'word'           => $word,
                'phonetic'       => null,
                'part_of_speech' => null,
                'definition'     => $definition,
            ];
        }

        // ===== 模式4: 纯英文单词 + 空格 + 中文 =====
        if (preg_match('/^([a-zA-Z][a-zA-Z\-\']*)\s+([\x{4e00}-\x{9fff}\(（].+)$/u', $line, $matches)) {
            $word = trim($matches[1]);
            if (strlen($word) < 1 || strlen($word) > 30) {
                return null;
            }
            $def = trim($matches[2]);
            $def = preg_replace('/\s*[pP]\.?\s*\d+\s*$/', '', $def);
            if (empty($def)) {
                return null;
            }
            return [
                'word'           => $word,
                'phonetic'       => null,
                'part_of_speech' => null,
                'definition'     => $def,
            ];
        }

        return null;
    }

    /**
     * 根据坐标信息将双列排版重排为：左列从上到下，然后右列从上到下
     * 
     * 课本单词表通常是双列排版，OCR默认逐行扫描会交替读取左右列。
     * 通过分析x坐标，将文字分成左右两列，分别按y坐标排序后拼接。
     */
    private static function reorderByColumns($items)
    {
        if (count($items) < 4) {
            return $items;
        }

        // 收集所有x坐标，用中位数判断分列阈值
        $xValues = array_map(function ($item) {
            return $item['left'];
        }, $items);
        sort($xValues);

        $minX = $xValues[0];
        $maxX = end($xValues);
        $xRange = $maxX - $minX;

        // 如果x范围太小，说明不是双列排版，直接按y排序返回
        if ($xRange < 100) {
            usort($items, function ($a, $b) {
                return $a['top'] - $b['top'];
            });
            return $items;
        }

        // 用x范围的中点作为分列阈值
        $threshold = $minX + $xRange * 0.4;

        $leftCol = [];
        $rightCol = [];

        foreach ($items as $item) {
            if ($item['left'] < $threshold) {
                $leftCol[] = $item;
            } else {
                $rightCol[] = $item;
            }
        }

        // 各列按y坐标从上到下排序
        usort($leftCol, function ($a, $b) {
            return $a['top'] - $b['top'];
        });
        usort($rightCol, function ($a, $b) {
            return $a['top'] - $b['top'];
        });

        // 左列在前，右列在后
        return array_merge($leftCol, $rightCol);
    }

    /**
     * 从数据库匹配单词，用准确的音标替换OCR识别结果
     */
    private static function enrichFromDatabase($words)
    {
        if (empty($words)) {
            return $words;
        }

        try {
            // 收集所有单词名
            $wordTexts = [];
            foreach ($words as $w) {
                $wordTexts[] = strtolower(trim($w['word']));
            }
            $wordTexts = array_values(array_unique($wordTexts));

            if (empty($wordTexts)) {
                return $words;
            }

            // 批量查询数据库
            $placeholders = implode(',', array_fill(0, count($wordTexts), '?'));
            $dbWords = \think\Db::query(
                "SELECT word, phonetic, part_of_speech, definition, example FROM fa_word WHERE LOWER(word) IN ({$placeholders})",
                $wordTexts
            );

            if (empty($dbWords)) {
                return $words;
            }

            // 建立查找映射 (小写单词 => 数据库记录)
            $dbMap = [];
            foreach ($dbWords as $row) {
                $dbMap[strtolower($row['word'])] = $row;
            }

            $matchCount = 0;
            // 用索引循环直接修改原数组
            for ($i = 0; $i < count($words); $i++) {
                $key = strtolower(trim($words[$i]['word']));
                if (isset($dbMap[$key])) {
                    $dbRow = $dbMap[$key];
                    // 音标：优先用数据库的
                    if (!empty($dbRow['phonetic'])) {
                        $words[$i]['phonetic'] = $dbRow['phonetic'];
                    }
                    // 词性：如果OCR没识别到，用数据库的
                    if (empty($words[$i]['part_of_speech']) && !empty($dbRow['part_of_speech'])) {
                        $words[$i]['part_of_speech'] = $dbRow['part_of_speech'];
                    }
                    // 例句：从数据库补充
                    if (!empty($dbRow['example'])) {
                        $words[$i]['example'] = $dbRow['example'];
                    }
                    $matchCount++;
                }
            }

            Log::info('[OCR] 数据库匹配音标: ' . $matchCount . '/' . count($words) . ' 个单词');
        } catch (\Exception $e) {
            // 数据库匹配失败不影响主流程
            Log::warning('[OCR] 数据库匹配音标失败: ' . $e->getMessage());
        }

        return $words;
    }

    /**
     * HTTP POST请求
     */
    private static function httpPost($url, $data, $headers = [])
    {
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        if (!empty($headers)) {
            curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        }
        $response = curl_exec($ch);
        if (curl_errno($ch)) {
            $error = curl_error($ch);
            curl_close($ch);
            throw new \Exception('网络请求失败: ' . $error);
        }
        curl_close($ch);
        return $response;
    }
}
