<?php

namespace app\admin\controller;

use app\common\controller\Backend;

/**
 * 单词管理
 *
 * @icon fa fa-font
 */
class Word extends Backend
{
    /**
     * @var \app\admin\model\Word
     */
    protected $model = null;

    public function _initialize()
    {
        parent::_initialize();
        $this->model = new \app\admin\model\Word;
    }

    /**
     * 默认生成的控制器所继承的父类中有index/add/edit/del/multi五个基础方法
     * 因此在当前控制器中可不用编写增删改查的代码，如需自定义某个方法，复制对应方法到当前控制器即可
     */

    /**
     * 查看
     */
    public function index()
    {
        // 设置过滤方法
        $this->request->filter(['strip_tags', 'trim']);
        if ($this->request->isAjax()) {
            // 如果发送的来源是Selectpage，则转发到selectpage
            if ($this->request->request('keyField')) {
                return $this->selectpage();
            }
            list($where, $sort, $order, $offset, $limit) = $this->buildparams();
            $total = $this->model
                ->where($where)
                ->order($sort, $order)
                ->count();
            $list = $this->model
                ->where($where)
                ->order($sort, $order)
                ->limit($offset, $limit)
                ->select();
            $result = array("total" => $total, "rows" => $list);
            return json($result);
        }
        return $this->view->fetch();
    }
}
