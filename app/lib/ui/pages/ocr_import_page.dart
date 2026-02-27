import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../managers/vocabulary_manager.dart';
import '../../providers/vocabulary_provider.dart';

/// OCR拍照识别导入页面
/// 
/// 支持多页拍照 + 区域框选：
/// 拍照/选图 → 框选区域（可跳过）→ 识别 → 预览（可继续下一页）→ 输入词表信息 → 导入
class OcrImportPage extends StatefulWidget {
  const OcrImportPage({super.key});

  @override
  State<OcrImportPage> createState() => _OcrImportPageState();
}

class _OcrImportPageState extends State<OcrImportPage> {
  final ImagePicker _picker = ImagePicker();
  
  OcrPageState _state = OcrPageState.pickImage;
  File? _imageFile;
  String? _errorMessage;
  
  // 多页累积
  final List<OcrWordEntry> _allWords = [];
  int _pageCount = 0;
  int _lastPageWordCount = 0;
  
  // 裁剪相关
  ui.Image? _uiImage;
  Rect? _cropRect;
  
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _uiImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: const Color(0xFF4A90D9),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_allWords.isNotEmpty && (_state == OcrPageState.pickImage || _state == OcrPageState.cropImage))
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('已识别 ${_allWords.length} 词', style: const TextStyle(fontSize: 14)),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  String _getTitle() {
    switch (_state) {
      case OcrPageState.pickImage:
        return _pageCount > 0 ? '继续拍照（第${_pageCount + 1}页）' : 'OCR识别';
      case OcrPageState.cropImage:
        return '选择识别区域';
      case OcrPageState.recognizing:
        return '正在识别第${_pageCount + 1}页...';
      case OcrPageState.preview:
        return '识别结果（共$_pageCount页）';
      case OcrPageState.inputInfo:
        return '词表信息';
      case OcrPageState.importing:
        return '正在导入...';
      case OcrPageState.error:
        return 'OCR识别';
    }
  }

  Widget _buildBody() {
    switch (_state) {
      case OcrPageState.pickImage:
        return _buildPickImage();
      case OcrPageState.cropImage:
        return _buildCropImage();
      case OcrPageState.recognizing:
        return _buildRecognizing();
      case OcrPageState.preview:
        return _buildPreview();
      case OcrPageState.inputInfo:
        return _buildInputInfo();
      case OcrPageState.importing:
        return _buildImporting();
      case OcrPageState.error:
        return _buildError();
    }
  }

  // ==================== 选择图片 ====================

  Widget _buildPickImage() {
    final bool isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
    final bool hasExistingWords = _allWords.isNotEmpty;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasExistingWords ? Icons.add_a_photo_outlined : Icons.document_scanner_outlined,
              size: 80, color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              hasExistingWords ? '继续拍摄下一页' : (isDesktop ? '选择图片识别词表' : '拍照识别纸质词表'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hasExistingWords
                  ? '已识别 $_pageCount 页，共 ${_allWords.length} 个单词'
                  : '支持多页拍照，所有单词合并到一个词表',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 48),
            if (!isDesktop) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(hasExistingWords ? '拍摄下一页' : '拍照识别', style: const TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: isDesktop
                ? ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: Text(hasExistingWords ? '选择下一张图片' : '选择图片', style: const TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90D9), foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: Text(hasExistingWords ? '从相册选择下一张' : '从相册选择', style: const TextStyle(fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
            ),
            if (hasExistingWords) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _state = OcrPageState.preview),
                  icon: const Icon(Icons.checklist),
                  label: Text('查看已识别的 ${_allWords.length} 个单词', style: const TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            if (!hasExistingWords) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.lightbulb_outline, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text('拍照建议', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                    ]),
                    const SizedBox(height: 8),
                    Text('• 保持图片清晰，避免模糊\n• 尽量平整拍摄，避免倾斜\n• 确保光线充足，避免阴影\n• 选图后可框选识别区域',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade700, height: 1.6)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      File? file;
      if (source == ImageSource.gallery) {
        final result = await FilePicker.platform.pickFiles(type: FileType.image);
        if (result == null || result.files.isEmpty || result.files.single.path == null) return;
        file = File(result.files.single.path!);
      } else {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.camera, maxWidth: 2048, maxHeight: 2048, imageQuality: 85,
        );
        if (image == null) return;
        file = File(image.path);
      }
      
      // 加载图片用于裁剪预览
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      
      setState(() {
        _imageFile = file;
        _uiImage?.dispose();
        _uiImage = frame.image;
        _cropRect = null;
        _state = OcrPageState.cropImage;
      });
    } catch (e) {
      _showErrorState('选择图片失败: $e');
    }
  }

  // ==================== 裁剪区域选择 ====================

  Widget _buildCropImage() {
    return Column(
      children: [
        // 提示
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.orange.shade50,
          child: Row(
            children: [
              Icon(Icons.crop, size: 18, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text('拖拽选择要识别的区域，或直接点击"识别整张"',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade800)),
              ),
            ],
          ),
        ),
        // 图片 + 裁剪框
        Expanded(
          child: _CropAreaWidget(
            image: _uiImage!,
            cropRect: _cropRect,
            onCropChanged: (rect) => setState(() => _cropRect = rect),
          ),
        ),
        // 底部按钮
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _startRecognize(cropRect: null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('识别整张'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _cropRect != null ? () => _startRecognize(cropRect: _cropRect) : null,
                    icon: const Icon(Icons.crop),
                    label: const Text('识别选中区域', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90D9), foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _startRecognize({Rect? cropRect}) async {
    setState(() => _state = OcrPageState.recognizing);
    
    try {
      Uint8List bytes;
      
      if (cropRect != null && _uiImage != null) {
        // 裁剪图片
        bytes = await _cropImage(_uiImage!, cropRect);
      } else {
        bytes = await _imageFile!.readAsBytes();
      }
      
      if (bytes.length > 3 * 1024 * 1024) {
        _showErrorState('图片文件过大（${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB），请选择较小的图片');
        return;
      }
      
      final base64Image = base64Encode(bytes);
      final vm = context.read<VocabularyProvider>().vocabularyManager;
      final result = await vm.recognizeImage(base64Image);
      
      if (!mounted) return;
      
      if (result.words.isEmpty) {
        _showErrorState('未识别到有效的单词数据，请尝试重新拍照\n\n识别到 ${result.linesCount} 行文字，但未能解析出单词和释义对');
        return;
      }
      
      setState(() {
        _pageCount++;
        _lastPageWordCount = result.words.length;
        final existingWords = _allWords.map((w) => w.word.toLowerCase()).toSet();
        for (final word in result.words) {
          if (!existingWords.contains(word.word.toLowerCase())) {
            _allWords.add(word);
            existingWords.add(word.word.toLowerCase());
          }
        }
        _state = OcrPageState.preview;
      });
    } catch (e) {
      if (mounted) {
        _showErrorState(_getErrorMessage(e));
      }
    }
  }

  /// 裁剪图片：从 ui.Image 中截取指定区域，返回 PNG bytes
  Future<Uint8List> _cropImage(ui.Image image, Rect cropRect) async {
    // cropRect 是相对于图片实际尺寸的比例坐标 (0.0 ~ 1.0)
    final int imgW = image.width;
    final int imgH = image.height;
    
    final int x = (cropRect.left * imgW).round().clamp(0, imgW);
    final int y = (cropRect.top * imgH).round().clamp(0, imgH);
    final int w = (cropRect.width * imgW).round().clamp(1, imgW - x);
    final int h = (cropRect.height * imgH).round().clamp(1, imgH - y);
    
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(w, h);
    final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    croppedImage.dispose();
    picture.dispose();
    
    return byteData!.buffer.asUint8List();
  }

  // ==================== 识别中 ====================

  Widget _buildRecognizing() {
    return Column(
      children: [
        if (_imageFile != null)
          Container(
            height: 200, width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_imageFile!, fit: BoxFit.cover),
            ),
          ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text('正在识别第${_pageCount + 1}页...', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                if (_allWords.isNotEmpty)
                  Text('已累计 ${_allWords.length} 个单词', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 预览编辑 ====================

  Widget _buildPreview() {
    final selectedCount = _allWords.where((w) => w.selected).length;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.blue.shade50,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('共 $_pageCount 页，${_allWords.length} 个单词，已选 $selectedCount 个',
                      style: TextStyle(fontSize: 14, color: Colors.blue.shade800)),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        final allSelected = _allWords.every((w) => w.selected);
                        for (final w in _allWords) { w.selected = !allSelected; }
                      });
                    },
                    child: Text(_allWords.every((w) => w.selected) ? '取消全选' : '全选'),
                  ),
                ],
              ),
              if (_lastPageWordCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('本页新增 $_lastPageWordCount 个单词',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _allWords.length,
            itemBuilder: (context, index) => _buildWordItem(_allWords[index], index),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() { _state = OcrPageState.pickImage; _imageFile = null; _lastPageWordCount = 0; }),
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('继续拍下一页'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedCount > 0 ? () => setState(() => _state = OcrPageState.inputInfo) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90D9), foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('完成，导入 $selectedCount 个单词', style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordItem(OcrWordEntry entry, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => setState(() => entry.selected = !entry.selected),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: entry.selected,
                onChanged: (v) => setState(() => entry.selected = v ?? false),
                activeColor: const Color(0xFF4A90D9),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(entry.word, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (entry.phonetic != null) ...[
                        const SizedBox(width: 8),
                        Text('/${entry.phonetic}/', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                      if (entry.partOfSpeech != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                          child: Text(entry.partOfSpeech!, style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Text(entry.definition, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                    if (entry.example != null && entry.example!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(entry.example!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade500),
                onPressed: () => _editWord(entry), tooltip: '编辑',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editWord(OcrWordEntry entry) async {
    final wordCtrl = TextEditingController(text: entry.word);
    final defCtrl = TextEditingController(text: entry.definition);
    final phoneticCtrl = TextEditingController(text: entry.phonetic ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑单词'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: wordCtrl, decoration: const InputDecoration(labelText: '单词', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phoneticCtrl, decoration: const InputDecoration(labelText: '音标（可选）', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: defCtrl, decoration: const InputDecoration(labelText: '释义', border: OutlineInputBorder()), maxLines: 3),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (result == true) {
      setState(() {
        entry.word = wordCtrl.text.trim();
        entry.definition = defCtrl.text.trim();
        entry.phonetic = phoneticCtrl.text.trim().isEmpty ? null : phoneticCtrl.text.trim();
      });
    }
    wordCtrl.dispose();
    defCtrl.dispose();
    phoneticCtrl.dispose();
  }

  // ==================== 输入词表信息 ====================

  Widget _buildInputInfo() {
    final selectedCount = _allWords.where((w) => w.selected).length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('即将导入 $selectedCount 个单词', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '词表名称 *',
              hintText: '例如：四年级上册Unit1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(
              labelText: '分类（可选）',
              hintText: '例如：PEP小学英语',
              border: OutlineInputBorder(),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _state = OcrPageState.preview),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('返回修改'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _nameController.text.trim().isNotEmpty ? _doImport : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('导入 $selectedCount 个单词', style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 导入中 ====================

  Widget _buildImporting() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('正在导入词表...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _doImport() async {
    setState(() => _state = OcrPageState.importing);
    try {
      final vm = context.read<VocabularyProvider>().vocabularyManager;
      final selectedWords = _allWords.where((w) => w.selected).toList();
      await vm.importFromOcrWords(
        selectedWords,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功导入 ${selectedWords.length} 个单词'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _showErrorState('导入失败: $e');
      }
    }
  }

  // ==================== 错误页面 ====================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_errorMessage ?? '发生未知错误', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _state = _allWords.isNotEmpty ? OcrPageState.preview : OcrPageState.pickImage;
                _errorMessage = null;
              }),
              icon: const Icon(Icons.refresh),
              label: Text(_allWords.isNotEmpty ? '返回预览' : '重新选择图片'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorState(String message) {
    setState(() {
      _errorMessage = message;
      _state = OcrPageState.error;
    });
  }

  String _getErrorMessage(dynamic e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return '网络连接失败，请检查网络后重试';
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return '请求超时，请检查网络后重试';
    }
    if (msg.contains('FormatException')) {
      return '服务器返回数据格式异常';
    }
    return '识别失败: $msg';
  }
}

// ==================== 页面状态枚举 ====================

enum OcrPageState {
  pickImage,
  cropImage,
  recognizing,
  preview,
  inputInfo,
  importing,
  error,
}

// ==================== 裁剪区域选择组件 ====================
//
// 交互方式：预设选区 + 拖拽手柄精准调整
// - 初始显示覆盖图片中间80%的默认选区
// - 四角有大圆形手柄，手指容易抓住
// - 四条边中点有条形手柄，可单独调整某一边
// - 拖拽选区内部可整体移动
// - 最小选区限制，防止误操作

/// 拖拽操作类型
enum _DragHandle { none, topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right, move }

class _CropAreaWidget extends StatefulWidget {
  final ui.Image image;
  final Rect? cropRect;
  final ValueChanged<Rect?> onCropChanged;

  const _CropAreaWidget({
    required this.image,
    required this.cropRect,
    required this.onCropChanged,
  });

  @override
  State<_CropAreaWidget> createState() => _CropAreaWidgetState();
}

class _CropAreaWidgetState extends State<_CropAreaWidget> {
  // 选区在屏幕坐标系中的位置
  Rect? _selRect;
  _DragHandle _activeHandle = _DragHandle.none;
  Offset? _dragStart;
  Rect? _rectAtDragStart;
  bool _initialized = false;

  // 手柄触摸热区半径（像素）
  static const double _handleHitRadius = 24.0;
  // 最小选区尺寸（像素）
  static const double _minSize = 48.0;

  Rect _displayRect = Rect.zero;
  double _displayW = 0;
  double _displayH = 0;
  double _offsetX = 0;
  double _offsetY = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imgW = widget.image.width.toDouble();
        final imgH = widget.image.height.toDouble();
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;

        final scale = (boxW / imgW).clamp(0.0, boxH / imgH);
        _displayW = imgW * scale;
        _displayH = imgH * scale;
        _offsetX = (boxW - _displayW) / 2;
        _offsetY = (boxH - _displayH) / 2;
        _displayRect = Rect.fromLTWH(_offsetX, _offsetY, _displayW, _displayH);

        // 初始化默认选区（图片中间80%）
        if (!_initialized) {
          _initialized = true;
          final margin = 0.1;
          _selRect = Rect.fromLTRB(
            _offsetX + _displayW * margin,
            _offsetY + _displayH * margin,
            _offsetX + _displayW * (1 - margin),
            _offsetY + _displayH * (1 - margin),
          );
          // 通知父组件
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _notifyParent();
          });
        }

        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            size: Size(boxW, boxH),
            painter: _CropPainter(
              image: widget.image,
              displayRect: _displayRect,
              selectionRect: _selRect,
            ),
          ),
        );
      },
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (_selRect == null) return;
    final pos = details.localPosition;
    _dragStart = pos;
    _rectAtDragStart = _selRect;
    _activeHandle = _hitTest(pos);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_selRect == null || _rectAtDragStart == null || _dragStart == null) return;
    final delta = details.localPosition - _dragStart!;
    final r = _rectAtDragStart!;

    Rect newRect;
    switch (_activeHandle) {
      case _DragHandle.topLeft:
        newRect = Rect.fromLTRB(
          (r.left + delta.dx).clamp(_displayRect.left, r.right - _minSize),
          (r.top + delta.dy).clamp(_displayRect.top, r.bottom - _minSize),
          r.right, r.bottom,
        );
        break;
      case _DragHandle.topRight:
        newRect = Rect.fromLTRB(
          r.left,
          (r.top + delta.dy).clamp(_displayRect.top, r.bottom - _minSize),
          (r.right + delta.dx).clamp(r.left + _minSize, _displayRect.right),
          r.bottom,
        );
        break;
      case _DragHandle.bottomLeft:
        newRect = Rect.fromLTRB(
          (r.left + delta.dx).clamp(_displayRect.left, r.right - _minSize),
          r.top,
          r.right,
          (r.bottom + delta.dy).clamp(r.top + _minSize, _displayRect.bottom),
        );
        break;
      case _DragHandle.bottomRight:
        newRect = Rect.fromLTRB(
          r.left, r.top,
          (r.right + delta.dx).clamp(r.left + _minSize, _displayRect.right),
          (r.bottom + delta.dy).clamp(r.top + _minSize, _displayRect.bottom),
        );
        break;
      case _DragHandle.top:
        newRect = Rect.fromLTRB(
          r.left,
          (r.top + delta.dy).clamp(_displayRect.top, r.bottom - _minSize),
          r.right, r.bottom,
        );
        break;
      case _DragHandle.bottom:
        newRect = Rect.fromLTRB(
          r.left, r.top, r.right,
          (r.bottom + delta.dy).clamp(r.top + _minSize, _displayRect.bottom),
        );
        break;
      case _DragHandle.left:
        newRect = Rect.fromLTRB(
          (r.left + delta.dx).clamp(_displayRect.left, r.right - _minSize),
          r.top, r.right, r.bottom,
        );
        break;
      case _DragHandle.right:
        newRect = Rect.fromLTRB(
          r.left, r.top,
          (r.right + delta.dx).clamp(r.left + _minSize, _displayRect.right),
          r.bottom,
        );
        break;
      case _DragHandle.move:
        var dx = delta.dx;
        var dy = delta.dy;
        // 限制不超出图片区域
        if (r.left + dx < _displayRect.left) dx = _displayRect.left - r.left;
        if (r.right + dx > _displayRect.right) dx = _displayRect.right - r.right;
        if (r.top + dy < _displayRect.top) dy = _displayRect.top - r.top;
        if (r.bottom + dy > _displayRect.bottom) dy = _displayRect.bottom - r.bottom;
        newRect = r.shift(Offset(dx, dy));
        break;
      case _DragHandle.none:
        return;
    }

    setState(() => _selRect = newRect);
    _notifyParent();
  }

  void _onPanEnd(DragEndDetails details) {
    _activeHandle = _DragHandle.none;
    _dragStart = null;
    _rectAtDragStart = null;
  }

  /// 判断触摸点命中了哪个手柄
  _DragHandle _hitTest(Offset pos) {
    final r = _selRect!;

    // 四角优先（最大触摸区域）
    if ((pos - r.topLeft).distance < _handleHitRadius) return _DragHandle.topLeft;
    if ((pos - r.topRight).distance < _handleHitRadius) return _DragHandle.topRight;
    if ((pos - r.bottomLeft).distance < _handleHitRadius) return _DragHandle.bottomLeft;
    if ((pos - r.bottomRight).distance < _handleHitRadius) return _DragHandle.bottomRight;

    // 四边中点
    final topMid = Offset(r.center.dx, r.top);
    final bottomMid = Offset(r.center.dx, r.bottom);
    final leftMid = Offset(r.left, r.center.dy);
    final rightMid = Offset(r.right, r.center.dy);
    if ((pos - topMid).distance < _handleHitRadius) return _DragHandle.top;
    if ((pos - bottomMid).distance < _handleHitRadius) return _DragHandle.bottom;
    if ((pos - leftMid).distance < _handleHitRadius) return _DragHandle.left;
    if ((pos - rightMid).distance < _handleHitRadius) return _DragHandle.right;

    // 选区内部 → 整体移动
    if (r.contains(pos)) return _DragHandle.move;

    return _DragHandle.none;
  }

  /// 将屏幕选区转换为归一化坐标通知父组件
  void _notifyParent() {
    if (_selRect == null) {
      widget.onCropChanged(null);
      return;
    }
    final r = _selRect!;
    final normLeft = ((r.left - _offsetX) / _displayW).clamp(0.0, 1.0);
    final normTop = ((r.top - _offsetY) / _displayH).clamp(0.0, 1.0);
    final normRight = ((r.right - _offsetX) / _displayW).clamp(0.0, 1.0);
    final normBottom = ((r.bottom - _offsetY) / _displayH).clamp(0.0, 1.0);
    if ((normRight - normLeft) > 0.02 && (normBottom - normTop) > 0.02) {
      widget.onCropChanged(Rect.fromLTRB(normLeft, normTop, normRight, normBottom));
    }
  }
}

// ==================== 裁剪绘制器 ====================

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final Rect displayRect;
  final Rect? selectionRect;

  _CropPainter({
    required this.image,
    required this.displayRect,
    this.selectionRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制图片
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      displayRect,
      Paint(),
    );

    if (selectionRect == null) return;
    final r = selectionRect!;

    // 半透明遮罩（选区外部）
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final clampedTop = r.top.clamp(displayRect.top, displayRect.bottom);
    final clampedBottom = r.bottom.clamp(displayRect.top, displayRect.bottom);
    final clampedLeft = r.left.clamp(displayRect.left, displayRect.right);
    final clampedRight = r.right.clamp(displayRect.left, displayRect.right);
    canvas.drawRect(Rect.fromLTRB(displayRect.left, displayRect.top, displayRect.right, clampedTop), overlayPaint);
    canvas.drawRect(Rect.fromLTRB(displayRect.left, clampedBottom, displayRect.right, displayRect.bottom), overlayPaint);
    canvas.drawRect(Rect.fromLTRB(displayRect.left, clampedTop, clampedLeft, clampedBottom), overlayPaint);
    canvas.drawRect(Rect.fromLTRB(clampedRight, clampedTop, displayRect.right, clampedBottom), overlayPaint);

    // 选区边框
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(r, borderPaint);

    // 三分线（辅助构图）
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final thirdW = r.width / 3;
    final thirdH = r.height / 3;
    canvas.drawLine(Offset(r.left + thirdW, r.top), Offset(r.left + thirdW, r.bottom), guidePaint);
    canvas.drawLine(Offset(r.left + thirdW * 2, r.top), Offset(r.left + thirdW * 2, r.bottom), guidePaint);
    canvas.drawLine(Offset(r.left, r.top + thirdH), Offset(r.right, r.top + thirdH), guidePaint);
    canvas.drawLine(Offset(r.left, r.top + thirdH * 2), Offset(r.right, r.top + thirdH * 2), guidePaint);

    // 四角L形手柄（粗线，醒目）
    final cornerPaint = Paint()
      ..color = const Color(0xFF4A90D9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    const cLen = 24.0;
    // 左上
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(cLen, 0), cornerPaint);
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(0, cLen), cornerPaint);
    // 右上
    canvas.drawLine(r.topRight, r.topRight + const Offset(-cLen, 0), cornerPaint);
    canvas.drawLine(r.topRight, r.topRight + const Offset(0, cLen), cornerPaint);
    // 左下
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(cLen, 0), cornerPaint);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(0, -cLen), cornerPaint);
    // 右下
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(-cLen, 0), cornerPaint);
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(0, -cLen), cornerPaint);

    // 四边中点圆形手柄（方便手指抓取）
    final handlePaint = Paint()..color = const Color(0xFF4A90D9);
    final handleBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    const hr = 7.0; // 手柄半径
    final midPoints = [
      Offset(r.center.dx, r.top),    // 上
      Offset(r.center.dx, r.bottom), // 下
      Offset(r.left, r.center.dy),   // 左
      Offset(r.right, r.center.dy),  // 右
    ];
    for (final p in midPoints) {
      canvas.drawCircle(p, hr, handlePaint);
      canvas.drawCircle(p, hr, handleBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) => true;
}
