define(['jquery', 'bootstrap', 'backend', 'table', 'form'], function ($, undefined, Backend, Table, Form) {

    var Controller = {
        index: function () {
            Table.api.init({
                extend: {
                    index_url: 'word/index',
                    add_url: 'word/add',
                    edit_url: 'word/edit',
                    del_url: 'word/del',
                    multi_url: 'word/multi',
                    table: 'word',
                }
            });

            var table = $("#table");
            table.bootstrapTable({
                url: $.fn.bootstrapTable.defaults.extend.index_url,
                pk: 'id',
                sortName: 'id',
                columns: [
                    [
                        {checkbox: true},
                        {field: 'id', title: 'ID', sortable: true},
                        {field: 'word', title: '单词', operate: 'LIKE', sortable: true},
                        {field: 'phonetic', title: '音标', operate: false},
                        {field: 'part_of_speech', title: '词性', operate: 'LIKE'},
                        {field: 'definition', title: '释义', operate: 'LIKE'},
                        {field: 'example', title: '例句', operate: false},
                        {field: 'created_at_text', title: '创建时间', operate: false, sortable: true},
                        {field: 'operate', title: '操作', table: table, events: Table.api.events.operate, formatter: Table.api.formatter.operate}
                    ]
                ]
            });

            Table.api.bindevent(table);
        },
        add: function () {
            Controller.api.bindevent();
        },
        edit: function () {
            Controller.api.bindevent();
        },
        api: {
            bindevent: function () {
                Form.api.bindevent($("form[role=form]"));
            }
        }
    };
    return Controller;
});
