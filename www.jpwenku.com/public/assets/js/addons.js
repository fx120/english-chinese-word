define([], function () {
    if (typeof Config.upload.storage !== 'undefined' && Config.upload.storage === 'alioss') {
    require(['upload'], function (Upload) {
        //获取文件MD5值
        var getFileMd5 = function (file, cb) {
            //如果savekey中未检测到md5，则无需获取文件md5，直接返回upload的uuid
            if (!Config.upload.savekey.match(/\{(file)?md5\}/)) {
                cb && cb(file.upload.uuid);
                return;
            }
            require(['../addons/alioss/js/spark'], function (SparkMD5) {
                var blobSlice = File.prototype.slice || File.prototype.mozSlice || File.prototype.webkitSlice,
                    chunkSize = 10 * 1024 * 1024,
                    chunks = Math.ceil(file.size / chunkSize),
                    currentChunk = 0,
                    spark = new SparkMD5.ArrayBuffer(),
                    fileReader = new FileReader();

                fileReader.onload = function (e) {
                    spark.append(e.target.result);
                    currentChunk++;
                    if (currentChunk < chunks) {
                        loadNext();
                    } else {
                        cb && cb(spark.end());
                    }
                };

                fileReader.onerror = function () {
                    console.warn('文件读取错误');
                };

                function loadNext() {
                    var start = currentChunk * chunkSize,
                        end = ((start + chunkSize) >= file.size) ? file.size : start + chunkSize;

                    fileReader.readAsArrayBuffer(blobSlice.call(file, start, end));
                }

                loadNext();

            });
        };

        var _onInit = Upload.events.onInit;
        //初始化中完成判断
        Upload.events.onInit = function () {
            _onInit.apply(this, Array.prototype.slice.apply(arguments));
            //如果上传接口不是阿里OSS，则不处理
            if (this.options.url !== Config.upload.uploadurl) {
                return;
            }
            $.extend(this.options, {
                //关闭自动处理队列功能
                autoQueue: false,
                params: function (files, xhr, chunk) {
                    var params = Config.upload.multipart;
                    if (chunk) {
                        return $.extend({}, params, {
                            filesize: chunk.file.size,
                            filename: chunk.file.name,
                            chunkid: chunk.file.upload.uuid,
                            chunkindex: chunk.index,
                            chunkcount: chunk.file.upload.totalChunkCount,
                            chunksize: this.options.chunkSize,
                            chunkfilesize: chunk.dataBlock.data.size,
                            width: chunk.file.width || 0,
                            height: chunk.file.height || 0,
                            type: chunk.file.type,
                            uploadId: chunk.file.uploadId,
                            key: chunk.file.key,
                        });
                    } else {
                        params = $.extend({}, params, files[0].params);
                        params.category = files[0].category || '';
                    }
                    return params;
                },
                chunkSuccess: function (chunk, file, response) {
                    var etag = chunk.xhr.getResponseHeader("ETag").replace(/(^")|("$)/g, '');
                    file.etags = file.etags ? file.etags : [];
                    file.etags[chunk.index] = etag;
                },
                chunksUploaded: function (file, done) {
                    var that = this;
                    Fast.api.ajax({
                        url: "/addons/alioss/index/upload",
                        data: {
                            action: 'merge',
                            filesize: file.size,
                            filename: file.name,
                            chunkid: file.upload.uuid,
                            chunkcount: file.upload.totalChunkCount,
                            md5: file.md5,
                            key: file.key,
                            uploadId: file.uploadId,
                            etags: file.etags,
                            category: file.category || '',
                            aliosstoken: Config.upload.multipart.aliosstoken,
                        },
                    }, function (data, ret) {
                        done(JSON.stringify(ret));
                        return false;
                    }, function (data, ret) {
                        file.accepted = false;
                        that._errorProcessing([file], ret.msg);
                        return false;
                    });

                },
            });

            var _success = this.options.success;
            //先移除已有的事件
            this.off("success", _success).on("success", function (file, response) {
                var that = this;
                var ret = {code: 0, msg: response};
                try {
                    if (response) {
                        ret = typeof response === 'string' ? JSON.parse(response) : response;
                    }
                    if (file.xhr.status === 200) {
                        if (Config.upload.uploadmode === 'client') {
                            var url = '/' + file.key;
                            ret = {code: 1, msg: '', data: {url: url, fullurl: Fast.api.cdnurl(url, true), filename: file.name, filesize: file.size, mimetype: file.type, category: file.category || ''}};
                            Fast.api.ajax({
                                url: "/addons/alioss/index/notify",
                                data: {name: file.name, url: url, md5: file.md5, size: file.size, width: file.width || 0, height: file.height || 0, type: file.type, category: file.category || '', aliosstoken: Config.upload.multipart.aliosstoken}
                            }, function (data, notifyRet) {
                                // 如果notify有返回则使用notify返回
                                _success.call(that, file, data ? notifyRet : ret);
                                return false;
                            }, function (data, ret) {
                                Toastr.error("发生错误:" + (ret.msg || "未知错误"));
                                return false;
                            });
                        } else {
                            _success.call(that, file, ret);
                        }
                    } else {
                        console.error(file.xhr);
                        Toastr.error("发生未知错误");
                    }
                } catch (e) {
                    console.error(e);
                    Toastr.error("发生未知错误");
                }
            });

            this.on("addedfile", function (file) {
                var that = this;
                setTimeout(function () {
                    if (file.status === 'error') {
                        return;
                    }
                    getFileMd5(file, function (md5) {
                        var chunk = that.options.chunking && file.size > that.options.chunkSize ? 1 : 0;
                        var params = $(that.element).data("params") || {};
                        var category = typeof params.category !== 'undefined' ? params.category : ($(that.element).data("category") || '');
                        category = typeof category === 'function' ? category.call(that, file) : category;
                        Fast.api.ajax({
                            url: "/addons/alioss/index/params",
                            data: {method: 'POST', category: category, md5: md5, name: file.name, type: file.type, size: file.size, chunk: chunk, chunksize: that.options.chunkSize, aliosstoken: Config.upload.multipart.aliosstoken},
                        }, function (data) {
                            file.md5 = md5;
                            file.id = data.id;
                            file.key = data.key;
                            file.date = data.date;
                            file.uploadId = data.uploadId;
                            file.policy = data.policy;
                            file.signature = data.signature;
                            file.partsAuthorization = data.partsAuthorization;
                            file.params = data;
                            file.category = category;

                            if (file.status != 'error') {
                                //开始上传
                                that.enqueueFile(file);
                            } else {
                                that.removeFile(file);
                            }
                            return false;
                        }, function () {
                            that.removeFile(file);
                        });
                    });
                }, 0);
            });

            if (Config.upload.uploadmode === 'client') {
                var _method = this.options.method;
                var _url = this.options.url;
                this.options.method = function (files) {
                    if (files[0].upload.chunked) {
                        var chunk = null;
                        files[0].upload.chunks.forEach(function (item) {
                            if (item.status === 'uploading') {
                                chunk = item;
                            }
                        });
                        if (!chunk) {
                            return "POST";
                        } else {
                            return "PUT";
                        }
                    }
                    return _method;
                };
                this.options.url = function (files) {
                    if (files[0].upload.chunked) {
                        var chunk = null;
                        files[0].upload.chunks.forEach(function (item) {
                            if (item.status === 'uploading') {
                                chunk = item;
                            }
                        });
                        var index = chunk.dataBlock.chunkIndex;
                        // debugger;
                        this.options.headers = {"Authorization": "OSS " + files[0]['id'] + ":" + files[0]['partsAuthorization'][index], "x-oss-date": files[0]['date']};
                        if (!chunk) {
                            return Config.upload.uploadurl + "/" + files[0].key + "?uploadId=" + files[0].uploadId;
                        } else {
                            return Config.upload.uploadurl + "/" + files[0].key + "?partNumber=" + (index + 1) + "&uploadId=" + files[0].uploadId;
                        }
                    }
                    return _url;
                };
                this.on("sending", function (file, xhr, formData) {
                    var that = this;
                    if (file.upload.chunked) {
                        var _send = xhr.send;
                        xhr.send = function () {
                            var chunk = null;
                            file.upload.chunks.forEach(function (item) {
                                if (item.status == 'uploading') {
                                    chunk = item;
                                }
                            });
                            if (chunk) {
                                _send.call(xhr, chunk.dataBlock.data);
                            }
                        };
                    }
                });
            }
        };
    });
}

require.config({
    paths: {
        'bootstrap-markdown': '../addons/markdown/js/bootstrap-markdown.min',
        'hyperdown': '../addons/markdown/js/hyperdown.min',
        'turndown': '../addons/markdown/js/turndown',
    },
    shim: {
        'bootstrap-markdown': {
            deps: [
                'jquery',
                'css!../addons/markdown/css/bootstrap-markdown.css'
            ],
            exports: '$.fn.markdown'
        }
    }
});
require(['form', 'upload'], function (Form, Upload) {
    var _bindevent = Form.events.bindevent;
    Form.events.bindevent = function (form) {
        _bindevent.apply(this, [form]);
        var insert = function (e, url, type) {
            var urlArr = url.split(/\,/);
            $.each(urlArr, function () {
                var url = Fast.api.cdnurl(this, true);
                if (type && type == 'image') {
                    e.replaceSelection("\n" + '![输入图片说明](' + url + ')');
                } else {
                    e.replaceSelection("\n" + '[输入链接说明](' + url + ')');
                }
            });
            e.change(e);
            // e.$element.blur();
            // e.$element.focus();
        };
        try {
            if ($(Config.markdown.classname || '.editor', form).length > 0) {
                require(['bootstrap-markdown', 'hyperdown', 'turndown'], function (undefined, undefined, Turndown) {
                    $.fn.markdown.messages.zh = {
                        Bold: "粗体",
                        Italic: "斜体",
                        Heading: "标题",
                        "URL/Link": "链接",
                        Image: "图片",
                        List: "列表",
                        "Unordered List": "无序列表",
                        "Ordered List": "有序列表",
                        Code: "代码",
                        Quote: "引用",
                        Preview: "预览",
                        "strong text": "粗体",
                        "emphasized text": "强调",
                        "heading text": "标题",
                        "enter link description here": "输入链接说明",
                        "Insert Hyperlink": "URL地址",
                        "enter image description here": "输入图片说明",
                        "Insert Image Hyperlink": "图片URL地址",
                        "enter image title here": "在这里输入图片标题",
                        "list text here": "这里是列表文本",
                        "code text here": "这里输入代码",
                        "quote here": "这里输入引用文本"
                    };
                    var parser = new HyperDown();
                    window.marked = function (text) {
                        return parser.makeHtml(text);
                    };
                    var uploadFiles;
                    uploadFiles = async function (files) {
                        var self = this;
                        for (var i = 0; i < files.length; i++) {
                            try {
                                await new Promise((resolve) => {
                                    var url, html, file;
                                    file = files[i];
                                    Upload.api.send(file, function (data) {
                                        url = Fast.api.cdnurl(data.url, true);
                                        if (file.type.indexOf("image") !== -1) {
                                            insert(self, url, 'image');
                                        } else {
                                            insert(self, url, 'file');
                                        }
                                        resolve();
                                    }, function () {
                                        resolve();
                                    });
                                });
                            } catch (e) {

                            }
                        }
                    };

                    $(Config.markdown.classname || '.editor', form).each(function () {
                        var options = $(this).data("markdown-options") || {};
                        var editor = $(this);
                        var format = typeof options.format !== 'undefined' ? options.format : Config.markdown.format;
                        if (format === 'html') {
                            var origin = editor;
                            var turndownService = new TurndownService();
                            turndownService.use(turndownPluginGfm.gfm);
                            var content = turndownService.turndown(origin.val());

                            editor = origin.clone().removeAttr("name").removeAttr("id").val(content);
                            origin.css("display", "none");
                            editor.data("markdown-origin", origin);
                            editor.insertAfter(origin);
                        }
                        (function (editor) {
                            editor.markdown($.extend(true, {
                                resize: 'vertical',
                                language: 'zh',
                                iconlibrary: 'fa',
                                autofocus: false,
                                savable: false,
                                additionalButtons: [
                                    [{
                                        name: "groupCustom",
                                        data: [{
                                            name: "cmdUploadImage",
                                            toggle: false,
                                            title: "Upload image",
                                            icon: "fa fa-upload",
                                        }, {
                                            name: "cmdUploadFile",
                                            toggle: false,
                                            title: "Upload file",
                                            icon: "fa fa-cloud-upload",
                                        }, {
                                            name: "cmdSelectImage",
                                            toggle: false,
                                            title: "Select image",
                                            icon: "fa fa-file-image-o",
                                            callback: function (e) {
                                                parent.Fast.api.open("general/attachment/select?element_id=&multiple=true&mimetype=image/*", __('Choose'), {
                                                    callback: function (data) {
                                                        var urlArr = data.url.split(/\,/);
                                                        insert(e, data.url, 'image');
                                                    }
                                                });
                                                return false;
                                            }
                                        }, {
                                            name: "cmdSelectAttachment",
                                            toggle: false,
                                            title: "Select file",
                                            icon: "fa fa-file",
                                            callback: function (e) {
                                                parent.Fast.api.open("general/attachment/select?element_id=&multiple=true&mimetype=*", __('Choose'), {
                                                    callback: function (data) {
                                                        insert(e, data.url, 'file');
                                                    }
                                                });
                                                return false;
                                            }
                                        }]
                                    }]
                                ],
                                onShow: function (e) {
                                    //添加上传图片按钮和上传附件按钮
                                    var imgBtn = $("button[data-handler='bootstrap-markdown-cmdUploadImage']", e.$editor);
                                    var fileBtn = $("button[data-handler='bootstrap-markdown-cmdUploadFile']", e.$editor);
                                    var btnParent = imgBtn.parent();
                                    btnParent.addClass("md-relative");

                                    var upImgBtn = $('<button type="button" class="uploadimage faupload" data-button="image" title="点击上传图片" data-mimetype="image/gif,image/jpeg,image/png,image/jpg,image/bmp,image/webp" data-multiple="true">点击上传图片</button>');
                                    upImgBtn.css(imgBtn.position()).appendTo(btnParent);

                                    var upFileBtn = $('<button type="button" class="uploadfile faupload" data-button="file" title="点击上传附件" data-multiple="true">点击上传附件</button>');
                                    upFileBtn.css(fileBtn.position()).appendTo(btnParent);

                                    upImgBtn.data("upload-success", function (data, ret) {
                                        insert(e, data.url, 'image');
                                    });
                                    upFileBtn.data("upload-success", function (data, ret) {
                                        insert(e, data.url, 'file');
                                    });
                                    Form.events.faupload(e.$editor);

                                    $(".uploadimage,.uploadfile", e.$editor).on("mouseenter", function () {
                                        ($(this).data("button") === 'image' ? imgBtn : fileBtn).addClass("active");
                                    }).on("mouseleave", function () {
                                        ($(this).data("button") === 'image' ? imgBtn : fileBtn).removeClass("active");
                                    });

                                    //粘贴上传
                                    $(e.$textarea).bind('paste', function (event) {
                                        var originalEvent;
                                        originalEvent = event.originalEvent;
                                        if (originalEvent.clipboardData && originalEvent.clipboardData.files.length > 0) {
                                            uploadFiles.call(e, originalEvent.clipboardData.files);
                                            return false;
                                        }
                                    });
                                    //拖拽上传
                                    $(e.$textarea).bind('drop', function (event) {
                                        var originalEvent;
                                        originalEvent = event.originalEvent;
                                        if (originalEvent.dataTransfer && originalEvent.dataTransfer.files.length > 0) {
                                            uploadFiles.call(e, originalEvent.dataTransfer.files);
                                            return false;
                                        }
                                    });
                                },
                                onChange: function (e) {
                                    var origin = $(e.$textarea).data("markdown-origin");
                                    if (origin) {
                                        origin.val(marked(e.$textarea.val()));
                                    }
                                }
                            }, editor.data("markdown-options") || {}));
                        })(editor)
                    });
                });
            }
        } catch (e) {
            console.log(e);
        }

    };
});

});