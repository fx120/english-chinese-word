import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../managers/vocabulary_manager.dart';
import '../../models/vocabulary_list.dart';

/// 文件导入对话框
/// 
/// 功能：
/// - 选择导入方式（文本文件、Excel文件、OCR拍照）
/// - 文件选择和导入
/// - 显示导入进度
/// - 显示导入结果
/// - 显示错误提示
/// 
/// 需求: 4.1-4.6, 5.1-5.6, 6.1-6.8
class ImportDialog extends StatefulWidget {
  final VocabularyManager vocabularyManager;
  
  const ImportDialog({
    super.key,
    required this.vocabularyManager,
  });

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  // 导入状态
  ImportState _state = ImportState.selectMethod;
  
  // 导入方式
  ImportMethod? _selectedMethod;
  
  // 词表名称和描述
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // 选中的文件
  File? _selectedFile;
  
  // 导入结果
  VocabularyList? _importedList;
  String? _errorMessage;
  int _importedWordCount = 0;
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: _buildContent(),
      ),
    );
  }
  
  /// 构建对话框内容
  Widget _buildContent() {
    switch (_state) {
      case ImportState.selectMethod:
        return _buildMethodSelection();
      case ImportState.inputInfo:
        return _buildInfoInput();
      case ImportState.importing:
        return _buildImportingProgress();
      case ImportState.success:
        return _buildSuccessResult();
      case ImportState.error:
        return _buildErrorResult();
    }
  }
  
  /// 构建导入方式选择界面
  Widget _buildMethodSelection() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          Row(
            children: [
              const Icon(Icons.file_upload, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                '导入词表',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 导入方式选项
          _buildMethodOption(
            icon: Icons.text_snippet,
            title: '文本文件',
            subtitle: '支持 .txt 格式，每行一个单词',
            method: ImportMethod.text,
          ),
          const SizedBox(height: 12),
          
          _buildMethodOption(
            icon: Icons.table_chart,
            title: 'Excel文件',
            subtitle: '支持 .xlsx 和 .xls 格式',
            method: ImportMethod.excel,
          ),
          const SizedBox(height: 12),
          
          _buildMethodOption(
            icon: Icons.camera_alt,
            title: 'OCR拍照',
            subtitle: '拍照识别纸质词表（即将推出）',
            method: ImportMethod.ocr,
            enabled: false,
          ),
        ],
      ),
    );
  }
  
  /// 构建导入方式选项
  Widget _buildMethodOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required ImportMethod method,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? () => _selectMethod(method) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? Colors.grey.shade300 : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(12),
          color: enabled ? Colors.white : Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: enabled ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: enabled ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: enabled ? Colors.black54 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: enabled ? Colors.grey : Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }
  
  /// 选择导入方式
  Future<void> _selectMethod(ImportMethod method) async {
    setState(() {
      _selectedMethod = method;
    });
    
    // 选择文件
    await _pickFile();
  }
  
  /// 选择文件
  Future<void> _pickFile() async {
    try {
      if (_selectedMethod == ImportMethod.text) {
        // 选择文本文件
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['txt'],
        );
        
        if (result != null && result.files.single.path != null) {
          setState(() {
            _selectedFile = File(result.files.single.path!);
            _state = ImportState.inputInfo;
          });
        }
      } else if (_selectedMethod == ImportMethod.excel) {
        // 选择Excel文件
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xlsx', 'xls'],
        );
        
        if (result != null && result.files.single.path != null) {
          setState(() {
            _selectedFile = File(result.files.single.path!);
            _state = ImportState.inputInfo;
          });
        }
      } else if (_selectedMethod == ImportMethod.ocr) {
        // OCR拍照（预留）
        final picker = ImagePicker();
        final image = await picker.pickImage(source: ImageSource.camera);
        
        if (image != null) {
          setState(() {
            _selectedFile = File(image.path);
            _state = ImportState.inputInfo;
          });
        }
      }
    } catch (e) {
      _showError('选择文件失败: ${e.toString()}');
    }
  }
  
  /// 构建信息输入界面
  Widget _buildInfoInput() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _state = ImportState.selectMethod;
                    _selectedFile = null;
                  });
                },
              ),
              const Text(
                '词表信息',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 文件名显示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _getFileIcon(),
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFile?.path.split('/').last ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 词表名称输入
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '词表名称',
              hintText: '请输入词表名称',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
            maxLength: 50,
          ),
          const SizedBox(height: 16),
          
          // 词表描述输入
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: '词表描述（可选）',
              hintText: '请输入词表描述',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 3,
            maxLength: 200,
          ),
          const SizedBox(height: 24),
          
          // 开始导入按钮
          ElevatedButton(
            onPressed: _nameController.text.trim().isEmpty
                ? null
                : _startImport,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '开始导入',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 获取文件图标
  IconData _getFileIcon() {
    switch (_selectedMethod) {
      case ImportMethod.text:
        return Icons.text_snippet;
      case ImportMethod.excel:
        return Icons.table_chart;
      case ImportMethod.ocr:
        return Icons.camera_alt;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  /// 开始导入
  Future<void> _startImport() async {
    if (_selectedFile == null || _nameController.text.trim().isEmpty) {
      return;
    }
    
    setState(() {
      _state = ImportState.importing;
    });
    
    try {
      VocabularyList? result;
      
      if (_selectedMethod == ImportMethod.text) {
        // 导入文本文件
        result = await widget.vocabularyManager.importFromText(
          _selectedFile!,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
      } else if (_selectedMethod == ImportMethod.excel) {
        // 导入Excel文件
        result = await widget.vocabularyManager.importFromExcel(
          _selectedFile!,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
      } else if (_selectedMethod == ImportMethod.ocr) {
        // OCR导入（预留）
        throw UnimplementedError('OCR导入功能尚未实现');
      }
      
      if (result != null) {
        setState(() {
          _importedList = result;
          _importedWordCount = result!.wordCount;
          _state = ImportState.success;
        });
      }
    } catch (e) {
      _showError(e.toString());
    }
  }
  
  /// 构建导入进度界面
  Widget _buildImportingProgress() {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 16),
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            '正在导入...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '请稍候，正在解析文件并保存数据',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
  
  /// 构建成功结果界面
  Widget _buildSuccessResult() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 成功图标
          const Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          
          // 成功标题
          const Text(
            '导入成功！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // 导入统计
          Text(
            '已成功导入 $_importedWordCount 个单词',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          
          // 词表信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.book, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _importedList?.name ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_importedList?.description != null &&
                    _importedList!.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _importedList!.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 完成按钮
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(_importedList);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '完成',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建错误结果界面
  Widget _buildErrorResult() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 错误图标
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          
          // 错误标题
          const Text(
            '导入失败',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // 错误信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              _errorMessage ?? '未知错误',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // 按钮组
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _state = ImportState.selectMethod;
                      _selectedFile = null;
                      _selectedMethod = null;
                      _nameController.clear();
                      _descriptionController.clear();
                      _errorMessage = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('重试'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 显示错误
  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _state = ImportState.error;
    });
  }
}

/// 导入状态
enum ImportState {
  selectMethod,  // 选择导入方式
  inputInfo,     // 输入词表信息
  importing,     // 导入中
  success,       // 导入成功
  error,         // 导入失败
}

/// 导入方式
enum ImportMethod {
  text,   // 文本文件
  excel,  // Excel文件
  ocr,    // OCR拍照
}
