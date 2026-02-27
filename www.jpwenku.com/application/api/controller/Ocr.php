<?php

namespace app\api\controller;

use app\common\controller\Api;
use app\common\library\OcrService;

/**
 * OCR识别接口
 */
class Ocr extends Api
{
    protected $noNeedLogin = ['recognize'];
    protected $noNeedRight = '*';

    public function _initialize()
    {
        $corsResponse = \app\api\library\Cors::handle();
        if ($corsResponse !== null) {
            $corsResponse->send();
            exit;
        }
        parent::_initialize();
    }

    /**
     * 识别图片中的单词
     *
     * @ApiMethod (POST)
     * @ApiParams (name="image", type="string", required=true, description="图片base64编码")
     */
    public function recognize()
    {
        \think\Log::info('[OCR] 开始识别请求');

        $image = $this->request->post('image');

        if (empty($image)) {
            // 尝试从php://input读取（兼容不同Content-Type）
            $rawInput = file_get_contents('php://input');
            if (!empty($rawInput)) {
                $jsonData = json_decode($rawInput, true);
                if ($jsonData && isset($jsonData['image'])) {
                    $image = $jsonData['image'];
                } else {
                    parse_str($rawInput, $parsedData);
                    if (isset($parsedData['image'])) {
                        $image = $parsedData['image'];
                    }
                }
            }
        }

        if (empty($image)) {
            $this->error('请提供图片数据');
        }

        // 去掉data:image前缀
        if (preg_match('/^data:image\/\w+;base64,/', $image)) {
            $image = preg_replace('/^data:image\/\w+;base64,/', '', $image);
        }

        // 检查图片大小
        $maxSize = config('site.ocr_max_image_size') ?: 4194304;
        $decoded = base64_decode($image);
        $imageSize = strlen($decoded);

        if ($imageSize > $maxSize) {
            $this->error('图片大小超过限制（最大' . round($maxSize / 1048576, 1) . 'MB）');
        }

        try {
            $result = OcrService::recognize($image);
            \think\Log::info('[OCR] 识别成功, 行数: ' . ($result['lines_count'] ?? 0) . ', 单词数: ' . ($result['words_count'] ?? 0));
            $this->success('识别成功', $result);
        } catch (\think\exception\HttpResponseException $e) {
            // FastAdmin的success()/error()通过抛出此异常返回响应，直接重新抛出
            throw $e;
        } catch (\Exception $e) {
            \think\Log::error('[OCR] 识别异常: ' . $e->getMessage());
            $this->error($e->getMessage());
        }
    }
}
