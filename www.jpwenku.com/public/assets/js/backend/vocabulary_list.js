define(['jquery', 'bootstrap', 'backend', 'table', 'form'], function ($, undefined, Backend, Table, Form) {

    var Controller = {
        index: function () {
            Table.api.init({
                extend: {
                    index_url: 'vocabulary_list/index',
                    add_url: 'vocabulary_list/add',
                    edit_url: 'vocabulary_list/edit',
                    del_url: 'vocabulary_list/del',
                    multi_url: 'vocabulary_list/multi',
                    table: 'vocabulary_list',
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
                        {field: 'name', title: '词表名称', operate: 'LIKE'},
                        {field: 'category', title: '分类', searchList: {'高中':'高中','初中':'初中','CET4':'CET4','CET6':'CET6','考研':'考研','TOEFL':'TOEFL','IELTS':'IELTS','人教版':'人教版','外研社版':'外研社版','custom':'自定义'}, formatter: Table.api.formatter.label},
                        {field: 'difficulty_level', title: '难度', sortable: true},
                        {field: 'word_count', title: '单词数', sortable: true},
                        {field: 'is_official', title: '类型', searchList: {'0':'自定义','1':'官方'}, formatter: function(value) {
                            return value == 1 ? '<span class="label label-success">官方</span>' : '<span class="label label-info">自定义</span>';
                        }},
                        {field: 'status', title: '状态', searchList: {'normal':'正常','hidden':'隐藏'}, formatter: Table.api.formatter.status},
                        {field: 'created_at_text', title: '创建时间', operate: false, sortable: true},
                        {field: 'operate', title: '操作', table: table, events: Table.api.events.operate,
                            buttons: [
                                {
                                    name: 'words',
                                    text: '管理单词',
                                    title: '管理单词',
                                    classname: 'btn btn-xs btn-success btn-dialog',
                                    icon: 'fa fa-list',
                                    url: 'vocabulary_list/words',
                                    extend: 'data-area=\'["95%","90%"]\''
                                }
                            ],
                            formatter: Table.api.formatter.operate
                        }
                    ]
                ]
            });

            Table.api.bindevent(table);

            // JSON导入按钮
            $(document).on('click', '.btn-import-json', function (e) {
                e.preventDefault();
                Fast.api.open('vocabulary_list/importjson', '导入JSON词表', {
                    area: ['650px', '500px'],
                    callback: function () {
                        table.bootstrapTable('refresh');
                    }
                });
            });
        },
        add: function () {
            Controller.api.bindCategoryCustom();
            Controller.api.bindevent();
        },
        edit: function () {
            Controller.api.bindCategoryCustom();
            Controller.api.bindevent();
        },
        words: function () {
            var vocabularyListId = Fast.api.query('ids') || new URLSearchParams(window.location.search).get('ids');

            // 绑定添加单词按钮
            $(document).on('click', '.btn-add-word', function () {
                var url = $(this).data('url');
                Fast.api.open(url, '添加单词', {
                    callback: function () {
                        $("#table").bootstrapTable('refresh');
                    }
                });
            });

            // 绑定从其他词表导入按钮
            $(document).on('click', '.btn-import-words', function (e) {
                e.preventDefault();
                var url = $(this).attr('data-url');
                if (!url) return false;
                Fast.api.open(url, '从其他词表导入单词', {
                    area: ['700px', '650px'],
                    callback: function () {
                        $("#table").bootstrapTable('refresh');
                    }
                });
                return false;
            });

            var table = $("#table");
            table.bootstrapTable({
                url: 'vocabulary_list/words/ids/' + vocabularyListId,
                pk: 'id',
                sortName: 'sort_order',
                sortOrder: 'asc',
                search: false,
                commonSearch: false,
                sidePagination: 'server',
                pagination: true,
                pageSize: 50,
                pageList: [50, 100, 200],
                columns: [
                    [
                        {field: 'sort_order', title: '序号', sortable: true},
                        {field: 'word', title: '单词'},
                        {field: 'phonetic', title: '音标'},
                        {field: 'part_of_speech', title: '词性'},
                        {field: 'definition', title: '释义'},
                        {field: 'example', title: '例句'},
                        {field: 'operate', title: '操作', formatter: function(value, row) {
                            return '<a href="javascript:;" class="btn btn-xs btn-danger btn-delword" data-word-id="' + row.word_id + '" data-list-id="' + vocabularyListId + '"><i class="fa fa-trash"></i> 移除</a>';
                        }}
                    ]
                ]
            });

            // 绑定移除单词按钮
            $(document).on('click', '.btn-delword', function () {
                var wordId = $(this).data('word-id');
                var listId = $(this).data('list-id');
                Layer.confirm('确定要从词表中移除该单词吗？', function (index) {
                    $.ajax({
                        url: 'vocabulary_list/delword',
                        type: 'POST',
                        data: {vocabulary_list_id: listId, word_id: wordId},
                        dataType: 'json',
                        success: function (ret) {
                            if (ret.code === 1) {
                                Toastr.success(ret.msg);
                                $("#table").bootstrapTable('refresh');
                            } else {
                                Toastr.error(ret.msg);
                            }
                        }
                    });
                    Layer.close(index);
                });
            });

            // 刷新按钮
            $(document).on('click', '.btn-refresh', function () {
                $("#table").bootstrapTable('refresh');
            });
        },
        addword: function () {
            Controller.api.bindevent();
        },
        importjson: function () {
            // 用 FastAdmin 标准上传组件初始化按钮
            require(['upload'], function (Upload) {
                Upload.api.upload('#faupload-json');
            });

            // 监听上传成功后input值变化
            $(document).on('change', '#c-json-url', function () {
                if ($.trim($(this).val())) {
                    $('#uploaded-info').show();
                    $('#btn-do-import').prop('disabled', false);
                }
            });

            // 分类下拉框：选择"手动输入"时显示文本框
            $(document).on('change', '#category-select', function () {
                if ($(this).val() === '__custom__') {
                    $('#custom-category').show().focus();
                } else {
                    $('#custom-category').hide().val('');
                }
            });

            function showResult(msg, isSuccess) {
                $('#import-json-result').removeClass('success error')
                  .addClass(isSuccess ? 'success' : 'error')
                  .html(msg).show();
            }

            // 开始导入
            $(document).on('click', '#btn-do-import', function () {
                var btn = $(this);
                var jsonUrl = $.trim($('#c-json-url').val());
                if (!jsonUrl) {
                    Toastr.error('请先上传JSON文件');
                    return;
                }

                // 获取分类：如果选了自定义则用文本框的值
                var category = $('#category-select').val();
                if (category === '__custom__') {
                    category = $.trim($('#custom-category').val());
                    if (!category) {
                        Toastr.error('请输入自定义分类名称');
                        return;
                    }
                }

                btn.prop('disabled', true).html('<i class="fa fa-spinner fa-spin"></i> 导入中（大文件可能需要较长时间）...');
                $('#import-json-result').hide();

                $.ajax({
                    url: Fast.api.fixurl('vocabulary_list/importjson'),
                    type: 'POST',
                    data: {
                        json_url: jsonUrl,
                        name: $.trim($('input[name="name"]').val()),
                        category: category,
                        description: $.trim($('textarea[name="description"]').val())
                    },
                    dataType: 'json',
                    timeout: 300000,
                    success: function (ret) {
                        if (ret.code === 1) {
                            showResult(ret.msg, true);
                        } else {
                            showResult(ret.msg || '导入失败', false);
                        }
                    },
                    error: function (xhr) {
                        var msg = '请求失败，请重试';
                        try { var r = JSON.parse(xhr.responseText); if (r.msg) msg = r.msg; } catch(e) {}
                        showResult(msg, false);
                    },
                    complete: function () {
                        btn.prop('disabled', false).html('<i class="fa fa-download"></i> 开始导入');
                    }
                });
            });
        },
        importwords: function () {
            var targetId = Fast.api.query('ids') || new URLSearchParams(window.location.search).get('ids');
            var allWords = [];

            // Tab switching
            $(document).on('click', '.import-tab', function () {
                var tab = $(this).data('tab');
                $('.import-tab').removeClass('active');
                $(this).addClass('active');
                $('.import-panel').removeClass('active');
                $('.import-panel[data-panel="' + tab + '"]').addClass('active');
            });

            // Show result helper
            function showResult(el, msg, isSuccess) {
                $(el).removeClass('success error').addClass(isSuccess ? 'success' : 'error').html(msg).show();
            }

            // ===== TXT Mode =====
            $(document).on('click', '.btn-import-txt', function () {
                var btn = $(this);
                var content = $.trim($('#txt-content').val());
                if (!content) { Toastr.error('请输入单词'); return; }
                btn.prop('disabled', true).html('<i class="fa fa-spinner fa-spin"></i> 导入中...');
                $.ajax({
                    url: 'vocabulary_list/importwords/ids/' + targetId,
                    type: 'POST',
                    data: { mode: 'txt', txt_content: content },
                    dataType: 'json',
                    success: function (ret) {
                        if (ret.code === 1) {
                            showResult('#txt-result', ret.msg, true);
                        } else {
                            showResult('#txt-result', ret.msg, false);
                        }
                    },
                    error: function () { showResult('#txt-result', '请求失败，请重试', false); },
                    complete: function () { btn.prop('disabled', false).html('<i class="fa fa-upload"></i> 匹配并导入'); }
                });
            });

            // ===== Select Mode =====
            // Load words when source list changes
            $(document).on('change', '#source-list', function () {
                var sourceId = $(this).val();
                if (!sourceId) { $('#select-area').hide(); return; }
                $('#select-area').hide();
                $('#select-loading').show();
                $.ajax({
                    url: 'vocabulary_list/loadwords',
                    type: 'GET',
                    data: { target_id: targetId, source_id: sourceId },
                    dataType: 'json',
                    success: function (ret) {
                        if (ret.code === 1) {
                            allWords = ret.data || [];
                            renderWordList(allWords);
                            $('#select-area').show();
                        } else {
                            Toastr.error(ret.msg);
                        }
                    },
                    error: function () { Toastr.error('加载失败'); },
                    complete: function () { $('#select-loading').hide(); }
                });
            });

            // Render word list
            function renderWordList(words) {
                var keyword = $.trim($('#search-word').val()).toLowerCase();
                var html = '';
                var count = 0;
                for (var i = 0; i < words.length; i++) {
                    var w = words[i];
                    if (keyword && w.word.toLowerCase().indexOf(keyword) === -1 && (!w.definition || w.definition.toLowerCase().indexOf(keyword) === -1)) continue;
                    var cls = w.exists ? ' exists' : '';
                    var checked = w._checked && !w.exists ? ' checked' : '';
                    var disabled = w.exists ? ' disabled' : '';
                    var statusHtml = w.exists ? '<span class="text-warning" style="font-size:11px;">已存在</span>' : '';
                    html += '<label class="word-item' + cls + '" style="margin:0;cursor:pointer;">'
                        + '<input type="checkbox" class="word-cb" value="' + w.id + '"' + checked + disabled + ' style="margin-right:8px;">'
                        + '<span class="word-text">' + w.word + '</span>'
                        + '<span class="word-def">' + (w.definition || '') + '</span>'
                        + '<span class="word-status">' + statusHtml + '</span>'
                        + '</label>';
                    count++;
                }
                if (!count) html = '<div style="padding:20px;text-align:center;color:#999;">没有匹配的单词</div>';
                $('#word-list').html(html);
                updateSelectedCount();
            }

            // Search filter
            $(document).on('input', '#search-word', function () {
                // Save checked state
                $('#word-list .word-cb:not(:disabled)').each(function () {
                    var id = $(this).val();
                    for (var i = 0; i < allWords.length; i++) {
                        if (String(allWords[i].id) === id) { allWords[i]._checked = $(this).is(':checked'); break; }
                    }
                });
                renderWordList(allWords);
            });

            // Select all / none
            $(document).on('click', '.btn-select-all', function () {
                $('#word-list .word-cb:not(:disabled)').prop('checked', true);
                syncCheckedState();
            });
            $(document).on('click', '.btn-select-none', function () {
                $('#word-list .word-cb:not(:disabled)').prop('checked', false);
                syncCheckedState();
            });

            // Update count on checkbox change
            $(document).on('change', '.word-cb', function () {
                syncCheckedState();
            });

            function syncCheckedState() {
                $('#word-list .word-cb:not(:disabled)').each(function () {
                    var id = $(this).val();
                    for (var i = 0; i < allWords.length; i++) {
                        if (String(allWords[i].id) === id) { allWords[i]._checked = $(this).is(':checked'); break; }
                    }
                });
                updateSelectedCount();
            }

            function updateSelectedCount() {
                var count = 0;
                for (var i = 0; i < allWords.length; i++) {
                    if (allWords[i]._checked && !allWords[i].exists) count++;
                }
                $('#selected-count').text(count);
            }

            // Import selected words
            $(document).on('click', '.btn-import-selected', function () {
                var btn = $(this);
                // Collect all checked word IDs (including filtered-out ones)
                var ids = [];
                for (var i = 0; i < allWords.length; i++) {
                    if (allWords[i]._checked && !allWords[i].exists) ids.push(allWords[i].id);
                }
                if (!ids.length) { Toastr.error('请至少选择一个单词'); return; }
                btn.prop('disabled', true).html('<i class="fa fa-spinner fa-spin"></i> 导入中...');
                $.ajax({
                    url: 'vocabulary_list/importwords/ids/' + targetId,
                    type: 'POST',
                    data: { mode: 'select', word_ids: ids },
                    dataType: 'json',
                    success: function (ret) {
                        if (ret.code === 1) {
                            showResult('#select-result', ret.msg, true);
                            // Refresh the word list to update exists status
                            $('#source-list').trigger('change');
                        } else {
                            showResult('#select-result', ret.msg, false);
                        }
                    },
                    error: function () { showResult('#select-result', '请求失败，请重试', false); },
                    complete: function () { btn.prop('disabled', false).html('<i class="fa fa-upload"></i> 导入选中单词'); }
                });
            });
        },
        api: {
            bindevent: function () {
                Form.api.bindevent($("form[role=form]"));
            },
            bindCategoryCustom: function () {
                // 分类下拉框：选择"手动输入"时显示文本框
                $(document).on('change', '#c-category', function () {
                    if ($(this).val() === '__custom__') {
                        $('#custom-category').show().focus();
                    } else {
                        $('#custom-category').hide().val('');
                    }
                });
                // 表单提交前，如果选了自定义分类，替换select的值
                $("form[role=form]").on('submit', function (e) {
                    var sel = $('#c-category');
                    if (sel.val() === '__custom__') {
                        var custom = $.trim($('#custom-category').val());
                        if (custom) {
                            // 动态添加option并选中
                            sel.append('<option value="' + custom + '" selected>' + custom + '</option>');
                            sel.val(custom);
                        }
                    }
                });
            }
        }
    };
    return Controller;
});
