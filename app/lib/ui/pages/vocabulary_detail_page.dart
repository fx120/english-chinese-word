import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../models/vocabulary_list.dart';
import '../../models/word.dart';

/// 词表详情页面
/// 
/// 功能：
/// - 显示词表信息
/// - 显示单词列表（支持搜索和过滤）
/// - 实现编辑单词功能
/// - 实现添加单词功能
/// - 实现删除单词功能（软删除，需确认）
/// - 实现恢复已删除单词功能
/// - 集成VocabularyManager
/// 
/// 需求: 11.1-11.12
class VocabularyDetailPage extends StatefulWidget {
  final VocabularyList vocabularyList;
  
  const VocabularyDetailPage({
    super.key,
    required this.vocabularyList,
  });

  @override
  State<VocabularyDetailPage> createState() => _VocabularyDetailPageState();
}

class _VocabularyDetailPageState extends State<VocabularyDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<Word> _words = [];
  List<Word> _excludedWords = [];
  List<Word> _filteredWords = [];
  bool _isLoading = false;
  String _searchKeyword = '';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWords();
    
    _searchController.addListener(() {
      setState(() {
        _searchKeyword = _searchController.text;
        _filterWords();
      });
    });
  }

  /// 加载单词列表
  Future<void> _loadWords() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final vocabularyManager = context.read<VocabularyProvider>().vocabularyManager;
      
      // 获取词表详情（包含单词列表）
      final detail = await vocabularyManager.getVocabularyListDetail(
        widget.vocabularyList.id,
        includeExcluded: false,
      );
      
      // 获取已排除的单词
      final excludedWords = await vocabularyManager.getExcludedWords(
        widget.vocabularyList.id,
      );
      
      if (mounted) {
        setState(() {
          _words = detail.words;
          _excludedWords = excludedWords;
          _filterWords();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('加载单词列表失败: ${_getErrorMessage(e)}');
      }
    }
  }
  
  /// 过滤单词列表
  void _filterWords() {
    if (_searchKeyword.isEmpty) {
      _filteredWords = List.from(_words);
    } else {
      final lowerKeyword = _searchKeyword.toLowerCase();
      _filteredWords = _words.where((word) {
        return word.word.toLowerCase().contains(lowerKeyword) ||
               word.definition.toLowerCase().contains(lowerKeyword);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vocabularyList.name),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: '单词列表 (${_words.length})'),
            Tab(text: '已删除 (${_excludedWords.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加单词',
            onPressed: _showAddWordDialog,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '词表信息',
            onPressed: _showVocabularyInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          _buildSearchBar(),
          
          // 标签页内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWordsTab(),
                _buildExcludedWordsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建搜索框
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索单词或释义...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchKeyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  /// 构建单词列表标签页
  Widget _buildWordsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_words.isEmpty) {
      return _buildEmptyState(
        icon: Icons.book,
        message: '暂无单词',
        hint: '点击右上角"+"添加单词',
      );
    }
    
    if (_filteredWords.isEmpty && _searchKeyword.isNotEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off,
        message: '未找到匹配的单词',
        hint: '尝试使用其他关键词搜索',
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadWords,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredWords.length,
        itemBuilder: (context, index) {
          final word = _filteredWords[index];
          return _buildWordCard(word, isExcluded: false);
        },
      ),
    );
  }
  
  /// 构建已删除单词标签页
  Widget _buildExcludedWordsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_excludedWords.isEmpty) {
      return _buildEmptyState(
        icon: Icons.delete_outline,
        message: '暂无已删除的单词',
        hint: '删除的单词会出现在这里',
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadWords,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _excludedWords.length,
        itemBuilder: (context, index) {
          final word = _excludedWords[index];
          return _buildWordCard(word, isExcluded: true);
        },
      ),
    );
  }

  /// 构建单词卡片
  Widget _buildWordCard(Word word, {required bool isExcluded}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showWordDetail(word, isExcluded: isExcluded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 单词和音标
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          word.word,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isExcluded ? Colors.grey : Colors.black87,
                            decoration: isExcluded ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (word.phonetic != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            word.phonetic!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isExcluded ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 操作按钮
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.grey.shade600,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showEditWordDialog(word);
                          break;
                        case 'delete':
                          _confirmDeleteWord(word);
                          break;
                        case 'restore':
                          _restoreWord(word);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (!isExcluded) ...[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('编辑'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('删除', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ] else ...[
                        const PopupMenuItem(
                          value: 'restore',
                          child: Row(
                            children: [
                              Icon(Icons.restore, size: 20, color: Colors.green),
                              SizedBox(width: 8),
                              Text('恢复', style: TextStyle(color: Colors.green)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              
              // 词性
              if (word.partOfSpeech != null) ...[
                const SizedBox(height: 4),
                Text(
                  word.partOfSpeech!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isExcluded ? Colors.grey.shade400 : Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              
              // 释义
              const SizedBox(height: 8),
              Text(
                word.definition,
                style: TextStyle(
                  fontSize: 15,
                  color: isExcluded ? Colors.grey.shade500 : Colors.black87,
                ),
              ),
              
              // 例句
              if (word.example != null && word.example!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isExcluded 
                        ? Colors.grey.shade100 
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    word.example!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isExcluded ? Colors.grey.shade500 : Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? hint,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// 显示词表信息
  void _showVocabularyInfo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('词表信息'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('名称', widget.vocabularyList.name),
                if (widget.vocabularyList.description != null)
                  _buildInfoRow('描述', widget.vocabularyList.description!),
                if (widget.vocabularyList.category != null)
                  _buildInfoRow('分类', widget.vocabularyList.category!),
                _buildInfoRow('单词数量', '${widget.vocabularyList.wordCount}'),
                _buildInfoRow('难度级别', '${widget.vocabularyList.difficultyLevel}'),
                _buildInfoRow(
                  '类型',
                  widget.vocabularyList.isOfficial
                      ? '官方词表'
                      : widget.vocabularyList.isCustom
                          ? '自定义词表'
                          : '下载词表',
                ),
                _buildInfoRow(
                  '创建时间',
                  _formatDateTime(widget.vocabularyList.createdAt),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示单词详情
  void _showWordDetail(Word word, {required bool isExcluded}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  word.word,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              if (word.phonetic != null)
                Text(
                  word.phonetic!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (word.partOfSpeech != null) ...[
                  Text(
                    word.partOfSpeech!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  '释义:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  word.definition,
                  style: const TextStyle(fontSize: 15),
                ),
                if (word.example != null && word.example!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '例句:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      word.example!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!isExcluded) ...[
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditWordDialog(word);
                },
                icon: const Icon(Icons.edit),
                label: const Text('编辑'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDeleteWord(word);
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ] else ...[
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _restoreWord(word);
                },
                icon: const Icon(Icons.restore, color: Colors.green),
                label: const Text('恢复', style: TextStyle(color: Colors.green)),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  /// 显示添加单词对话框
  void _showAddWordDialog() {
    final wordController = TextEditingController();
    final phoneticController = TextEditingController();
    final partOfSpeechController = TextEditingController();
    final definitionController = TextEditingController();
    final exampleController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加单词'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: wordController,
                  decoration: const InputDecoration(
                    labelText: '单词 *',
                    hintText: '请输入单词',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneticController,
                  decoration: const InputDecoration(
                    labelText: '音标',
                    hintText: '例如: /həˈləʊ/',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: partOfSpeechController,
                  decoration: const InputDecoration(
                    labelText: '词性',
                    hintText: '例如: n. v. adj.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: definitionController,
                  decoration: const InputDecoration(
                    labelText: '释义 *',
                    hintText: '请输入释义',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exampleController,
                  decoration: const InputDecoration(
                    labelText: '例句',
                    hintText: '请输入例句',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final word = wordController.text.trim();
                final definition = definitionController.text.trim();
                
                if (word.isEmpty || definition.isEmpty) {
                  _showError('单词和释义不能为空');
                  return;
                }
                
                Navigator.pop(context);
                await _addWord(
                  word: word,
                  phonetic: phoneticController.text.trim(),
                  partOfSpeech: partOfSpeechController.text.trim(),
                  definition: definition,
                  example: exampleController.text.trim(),
                );
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  /// 显示编辑单词对话框
  void _showEditWordDialog(Word word) {
    final wordController = TextEditingController(text: word.word);
    final phoneticController = TextEditingController(text: word.phonetic ?? '');
    final partOfSpeechController = TextEditingController(text: word.partOfSpeech ?? '');
    final definitionController = TextEditingController(text: word.definition);
    final exampleController = TextEditingController(text: word.example ?? '');
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑单词'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: wordController,
                  decoration: const InputDecoration(
                    labelText: '单词 *',
                    border: OutlineInputBorder(),
                  ),
                  enabled: false, // 单词本身不可编辑
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneticController,
                  decoration: const InputDecoration(
                    labelText: '音标',
                    hintText: '例如: /həˈləʊ/',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: partOfSpeechController,
                  decoration: const InputDecoration(
                    labelText: '词性',
                    hintText: '例如: n. v. adj.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: definitionController,
                  decoration: const InputDecoration(
                    labelText: '释义 *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exampleController,
                  decoration: const InputDecoration(
                    labelText: '例句',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final definition = definitionController.text.trim();
                
                if (definition.isEmpty) {
                  _showError('释义不能为空');
                  return;
                }
                
                Navigator.pop(context);
                await _updateWord(
                  word,
                  phonetic: phoneticController.text.trim(),
                  partOfSpeech: partOfSpeechController.text.trim(),
                  definition: definition,
                  example: exampleController.text.trim(),
                );
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  /// 添加单词
  Future<void> _addWord({
    required String word,
    String? phonetic,
    String? partOfSpeech,
    required String definition,
    String? example,
  }) async {
    try {
      final vocabularyManager = context.read<VocabularyProvider>().vocabularyManager;
      
      final newWord = Word(
        id: 0, // 自动分配
        word: word,
        phonetic: phonetic?.isNotEmpty == true ? phonetic : null,
        partOfSpeech: partOfSpeech?.isNotEmpty == true ? partOfSpeech : null,
        definition: definition,
        example: example?.isNotEmpty == true ? example : null,
        createdAt: DateTime.now(),
      );
      
      await vocabularyManager.addWordToList(widget.vocabularyList.id, newWord);
      
      // 刷新列表
      await _loadWords();
      
      _showSuccess('单词添加成功');
    } catch (e) {
      _showError('添加单词失败: ${_getErrorMessage(e)}');
    }
  }
  
  /// 更新单词
  Future<void> _updateWord(
    Word word, {
    String? phonetic,
    String? partOfSpeech,
    required String definition,
    String? example,
  }) async {
    try {
      final vocabularyManager = context.read<VocabularyProvider>().vocabularyManager;
      
      final updatedWord = Word(
        id: word.id,
        serverId: word.serverId,
        word: word.word,
        phonetic: phonetic?.isNotEmpty == true ? phonetic : null,
        partOfSpeech: partOfSpeech?.isNotEmpty == true ? partOfSpeech : null,
        definition: definition,
        example: example?.isNotEmpty == true ? example : null,
        createdAt: word.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await vocabularyManager.updateWord(updatedWord);
      
      // 刷新列表
      await _loadWords();
      
      _showSuccess('单词更新成功');
    } catch (e) {
      _showError('更新单词失败: ${_getErrorMessage(e)}');
    }
  }
  
  /// 确认删除单词
  void _confirmDeleteWord(Word word) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除单词 "${word.word}" 吗？\n\n删除后可以在"已删除"标签页中恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteWord(word);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  /// 删除单词（软删除）
  Future<void> _deleteWord(Word word) async {
    try {
      final vocabularyManager = context.read<VocabularyProvider>().vocabularyManager;
      
      await vocabularyManager.excludeWordFromList(
        widget.vocabularyList.id,
        word.id,
      );
      
      // 刷新列表
      await _loadWords();
      
      _showSuccess('单词已删除');
    } catch (e) {
      _showError('删除单词失败: ${_getErrorMessage(e)}');
    }
  }
  
  /// 恢复单词
  Future<void> _restoreWord(Word word) async {
    try {
      final vocabularyManager = context.read<VocabularyProvider>().vocabularyManager;
      
      await vocabularyManager.restoreWordToList(
        widget.vocabularyList.id,
        word.id,
      );
      
      // 刷新列表
      await _loadWords();
      
      _showSuccess('单词已恢复');
    } catch (e) {
      _showError('恢复单词失败: ${_getErrorMessage(e)}');
    }
  }
  
  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  /// 显示成功提示
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  /// 显示错误提示
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  /// 获取友好的错误信息
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString();
    
    // 提取异常信息中的实际错误内容
    if (errorStr.contains('Exception:')) {
      return errorStr.split('Exception:').last.trim();
    }
    
    return errorStr;
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
