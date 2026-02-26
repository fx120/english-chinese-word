<?php

namespace addons\alisms;

use think\Addons;

/**
 * Alisms
 */
class Alisms extends Addons
{

    /**
     * 插件安装方法
     * @return bool
     */
    public function install()
    {
        return true;
    }

    /**
     * 插件卸载方法
     * @return bool
     */
    public function uninstall()
    {
        return true;
    }

    /**
     * 短信发送行为
     * @param array $params 必须包含mobile,event,code
     * @return  boolean
     */
    public function smsSend(&$params)
    {
        $config = get_addon_config('alisms');
        \think\Log::info('[Alisms::smsSend] 收到发送请求, params: ' . json_encode(is_object($params) ? $params->toArray() : $params));
        \think\Log::info('[Alisms::smsSend] 插件配置template: ' . json_encode($config['template'] ?? []));
        
        $event = is_object($params) ? $params->event : ($params['event'] ?? '');
        if (!isset($config['template'][$event])) {
            \think\Log::error('[Alisms::smsSend] 模板未配置, event=' . $event . ', 可用模板: ' . implode(',', array_keys($config['template'] ?? [])));
            return false;
        }
        \think\Log::info('[Alisms::smsSend] 使用模板: ' . $config['template'][$event] . ', event=' . $event);
        
        $mobile = is_object($params) ? $params->mobile : $params['mobile'];
        $code = is_object($params) ? $params->code : $params['code'];
        
        $alisms = new \addons\alisms\library\Alisms();
        $result = $alisms->mobile($mobile)
            ->template($config['template'][$event])
            ->param(['code' => $code])
            ->send();
        
        \think\Log::info('[Alisms::smsSend] 阿里云API返回: ' . var_export($result, true) . ', error: ' . $alisms->getError());
        return $result;
    }

    /**
     * 短信发送通知
     * @param array $params 必须包含 mobile,event,msg
     * @return  boolean
     */
    public function smsNotice(&$params)
    {
        $config = get_addon_config('alisms');
        $alisms = \addons\alisms\library\Alisms::instance();
        if (isset($params['msg'])) {
            if (is_array($params['msg'])) {
                $param = $params['msg'];
            } else {
                parse_str($params['msg'], $param);
            }
        } else {
            $param = [];
        }
        $param = $param ? $param : [];
        $params['template'] = $params['template'] ?? (isset($params['event']) && isset($config['template'][$params['event']]) ? $config['template'][$params['event']] : '');
        $result = $alisms->mobile($params['mobile'])
            ->template($params['template'])
            ->param($param)
            ->send();
        return $result;
    }

    /**
     * 检测验证是否正确
     * @param   $params
     * @return  boolean
     */
    public function smsCheck(&$params)
    {
        return true;
    }
}
