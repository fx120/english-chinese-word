import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/vocabulary_list.dart';
import '../../database/local_database.dart';
import 'vocabulary_detail_page.dart';
import 'login_page.dart';

class VocabularyListPage extends StatefulWidget {
  final int initialTab;
  const VocabularyListPage({super.key, this.initialTab = 0});

  @override
  State<VocabularyListPage> createState() => _VocabularyListPageState();
}

class _VocabularyListPageState extends State<VocabularyListPage> {
  late int _selectedTab = widget.initialTab; // 0=我的词表, 1=发现词表
  final Map<int, double> _downloadProgress = {};
  List<VocabularyList> _availableLists = [];
  bool _loadingAvailable = false;
  // 缓存每个词表的学习进度
  final Map<int, double> _progressCache = {};
  // 分类筛选
  List<String> _categories = [];
  String? _selectedCategory; // null表示"全部"
  // 发现词表：展开的分类
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocalLists();
      _loadAvailableLists();
      _loadCategories();
    });
  }

  Future<void> _loadCategories() async {
    final categories = await context.read<VocabularyProvider>().getAllCategories();
    if (mounted) setState(() => _categories = categories);
  }

  Future<void> _loadLocalLists() async {
    await context.read<VocabularyProvider>().loadVocabularyLists();
    _loadProgressForLists();
    _loadCategories();
  }

  Future<void> _loadProgressForLists() async {
    final provider = context.read<VocabularyProvider>();
    final db = context.read<LocalDatabase>();
    for (final list in provider.vocabularyLists) {
      final progress = await db.getVocabularyListProgress(list.id);
      if (mounted) {
        setState(() => _progressCache[list.id] = progress);
      }
    }
  }

  Future<void> _loadAvailableLists() async {
    setState(() => _loadingAvailable = true);
    try {
      final vm = context.read<VocabularyProvider>().vocabularyManager;
      // 分页加载全部词表（后端默认limit=20，需要循环获取）
      final allLists = <VocabularyList>[];
      int page = 1;
      const int pageSize = 100;
      while (true) {
        final lists = await vm.getVocabularyLists(page: page, limit: pageSize);
        allLists.addAll(lists);
        if (lists.length < pageSize) break; // 最后一页
        page++;
      }
      if (mounted) setState(() { _availableLists = allLists; _loadingAvailable = false; });
    } catch (e) {
      if (mounted) { setState(() => _loadingAvailable = false); _showError('加载词表列表失败: ${_getErrorMessage(e)}'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _selectedTab == 0 ? _buildMyListsTab() : _buildDiscoverTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A90D9), Color(0xFF357ABD)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      const Text('词表', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
                    tooltip: '导入词表',
                    onPressed: _showImportDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSegmentedToggle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _buildToggleItem('我的词表', 0),
          _buildToggleItem('发现词表', 1),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: selected ? const Color(0xFF357ABD) : Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyListsTab() {
    return Consumer<VocabularyProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator());
        if (provider.vocabularyLists.isEmpty) {
          return _buildEmptyState(Icons.library_books, '暂无词表', '点击右上角"+"导入词表，或切换到"发现词表"下载');
        }
        // 按分类筛选
        final filteredLists = _selectedCategory == null
            ? provider.vocabularyLists
            : provider.vocabularyLists.where((l) => l.category == _selectedCategory).toList();

        // 按分类分组
        final Map<String, List<VocabularyList>> grouped = {};
        for (final list in filteredLists) {
          final cat = (list.category != null && list.category!.isNotEmpty) ? list.category! : '未分类';
          grouped.putIfAbsent(cat, () => []);
          grouped[cat]!.add(list);
        }

        return RefreshIndicator(
          onRefresh: _loadLocalLists,
          child: Column(
            children: [
              // 分类筛选栏
              if (_categories.isNotEmpty)
                _buildCategoryFilter(),
              Expanded(
                child: filteredLists.isEmpty
                    ? _buildEmptyState(Icons.filter_list_off, '该分类暂无词表', '试试选择其他分类')
                    : grouped.length <= 1
                        // 只有一个分类（或筛选后只剩一个），直接平铺
                        ? ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: filteredLists.length,
                            itemBuilder: (context, index) => _buildVocabularyCard(filteredLists[index], isLocal: true),
                          )
                        // 多个分类，折叠显示
                        : _buildGroupedLocalList(grouped),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupedLocalList(Map<String, List<VocabularyList>> grouped) {
    final sortedCategories = grouped.keys.toList()..sort();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final category = sortedCategories[index];
        final lists = grouped[category]!;
        final isExpanded = _expandedCategories.contains(category);
        final totalWords = lists.fold<int>(0, (sum, l) => sum + l.wordCount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedCategories.remove(category);
                  } else {
                    _expandedCategories.add(category);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90D9).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.folder, color: Color(0xFF4A90D9), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 3),
                          Text('${lists.length} 个词表 · 共 $totalWords 词',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.grey.shade500, size: 24,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Column(
                  children: lists.map((list) => _buildVocabularyCard(list, isLocal: true)).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _buildCategoryChip('全部', null),
          ..._categories.map((c) => _buildCategoryChip(c, c)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? category) {
    final selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = category),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4A90D9) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverTab() {
    if (_loadingAvailable) return const Center(child: CircularProgressIndicator());
    if (_availableLists.isEmpty) {
      return _buildEmptyState(Icons.cloud_off, '暂无可用词表', '请检查网络连接后重试',
        action: TextButton.icon(onPressed: _loadAvailableLists, icon: const Icon(Icons.refresh), label: const Text('重新加载')),
      );
    }

    // 按分类分组
    final Map<String, List<VocabularyList>> grouped = {};
    for (final list in _availableLists) {
      final cat = (list.category != null && list.category!.isNotEmpty) ? list.category! : '未分类';
      grouped.putIfAbsent(cat, () => []);
      grouped[cat]!.add(list);
    }

    // 只有一个分类时不折叠，直接展示
    if (grouped.length <= 1) {
      return RefreshIndicator(
        onRefresh: _loadAvailableLists,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: _availableLists.length,
          itemBuilder: (context, index) => _buildVocabularyCard(_availableLists[index], isLocal: false),
        ),
      );
    }

    final sortedCategories = grouped.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _loadAvailableLists,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: sortedCategories.length,
        itemBuilder: (context, index) {
          final category = sortedCategories[index];
          final lists = grouped[category]!;
          final isExpanded = _expandedCategories.contains(category);
          final totalWords = lists.fold<int>(0, (sum, l) => sum + l.wordCount);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 分类头部（可点击展开/折叠）
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedCategories.remove(category);
                    } else {
                      _expandedCategories.add(category);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90D9).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.folder, color: Color(0xFF4A90D9), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 3),
                            Text('${lists.length} 个词表 · 共 $totalWords 词',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade500, size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              // 展开后显示该分类下的词表
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Column(
                    children: lists.map((list) => _buildVocabularyCard(list, isLocal: false)).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVocabularyCard(VocabularyList list, {required bool isLocal}) {
    final isDownloaded = isLocal || _isListDownloaded(list);
    final downloadProgress = _downloadProgress[list.serverId];
    final progress = _progressCache[list.id] ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isDownloaded ? () => _navigateToDetail(list) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧图标
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF5B9BD5), Color(0xFF3A7BD5)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              // 右侧内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题行
                    Row(
                      children: [
                        Expanded(
                          child: Text(list.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ),
                        if (isDownloaded && downloadProgress == null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.check_circle, size: 13, color: Color(0xFF4CAF50)),
                              SizedBox(width: 3),
                              Text('已下载', style: TextStyle(fontSize: 11, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
                            ]),
                          ),
                      ],
                    ),
                    // 描述
                    if (list.description != null && list.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(list.description!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 10),
                    // 进度条（仅本地词表显示）
                    if (isLocal) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress / 100,
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A90D9)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('已学: ${progress.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A90D9))),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    // 底部标签行
                    Row(
                      children: [
                        if (list.category != null && list.category!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)),
                            child: Text(list.category!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1976D2))),
                          ),
                        if (list.category != null && list.category!.isNotEmpty) const SizedBox(width: 8),
                        Icon(Icons.menu_book, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text('${list.wordCount} 词', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const Spacer(),
                        // 下载进度或下载按钮
                        if (downloadProgress != null)
                          SizedBox(
                            width: 80,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('${(downloadProgress * 100).toInt()}%', style: const TextStyle(fontSize: 11, color: Color(0xFF4A90D9))),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(value: downloadProgress, minHeight: 4, backgroundColor: Colors.grey.shade200),
                              ),
                            ]),
                          )
                        else if (!isDownloaded)
                          SizedBox(
                            height: 30,
                            child: ElevatedButton(
                              onPressed: () => _downloadList(list),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A90D9), foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 0,
                              ),
                              child: const Text('下载', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message, String hint, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(hint, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            if (action != null) ...[const SizedBox(height: 24), action],
          ],
        ),
      ),
    );
  }

  bool _isListDownloaded(VocabularyList list) {
    final provider = context.read<VocabularyProvider>();
    return provider.vocabularyLists.any((l) => l.serverId == list.serverId);
  }

  Future<void> _downloadList(VocabularyList list) async {
    if (list.serverId == null) { _showError('无法下载：词表ID无效'); return; }
    // 下载云词表需要登录
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      if (result != true) return;
    }
    try {
      final vm = context.read<VocabularyProvider>().vocabularyManager;
      await vm.downloadVocabularyList(list.serverId!, onProgress: (progress) {
        if (mounted) setState(() => _downloadProgress[list.serverId!] = progress);
      });
      if (mounted) {
        setState(() => _downloadProgress.remove(list.serverId!));
        await _loadLocalLists();
        _showSuccess('词表下载成功');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadProgress.remove(list.serverId!));
        final msg = _getErrorMessage(e);
        if (msg.contains('无需重复下载')) { _showInfo('该词表已下载完成'); }
        else { _showError('下载失败: $msg'); }
      }
    }
  }

  void _navigateToDetail(VocabularyList list) {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => VocabularyDetailPage(vocabularyList: list),
    )).then((_) => _loadLocalLists());
  }

  void _showImportDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const Text('导入词表', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _buildImportOption(icon: Icons.text_snippet, title: '文本文件', subtitle: '支持 .txt 格式', color: Colors.blue,
                    onTap: () { Navigator.pop(context); _importFromText(); }),
                  const SizedBox(height: 12),
                  _buildImportOption(icon: Icons.table_chart, title: 'Excel文件', subtitle: '支持 .xlsx 和 .xls 格式', color: Colors.green,
                    onTap: () { Navigator.pop(context); _importFromExcel(); }),
                  const SizedBox(height: 12),
                  _buildImportOption(icon: Icons.data_object, title: 'JSON词表', subtitle: '支持网络词表JSON格式，自动提取音标释义', color: Colors.purple,
                    onTap: () { Navigator.pop(context); _importFromJson(); }),
                  const SizedBox(height: 12),
                  _buildImportOption(icon: Icons.camera_alt, title: 'OCR识别', subtitle: '拍照识别纸质词表（即将推出）', color: Colors.orange,
                    onTap: () { Navigator.pop(context); _showInfo('OCR识别功能即将推出，敬请期待'); }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImportOption({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ])),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  Future<void> _importFromText() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt']);
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.single.path!);
      final name = await _showNameInputDialog('导入文本词表');
      if (name == null || name.isEmpty) return;
      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(
        child: Card(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在导入...')]))),
      ));
      final vm = context.read<VocabularyProvider>().vocabularyManager;
      await vm.importFromText(file, name: name, description: '从文本文件导入');
      if (mounted) {
        Navigator.pop(context);
        await _loadLocalLists();
        setState(() => _selectedTab = 0);
        _showSuccess('导入成功');
      }
    } catch (e) {
      if (mounted) { Navigator.pop(context); _showError('导入失败: ${_getErrorMessage(e)}'); }
    }
  }

  Future<void> _importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.single.path!);
      final name = await _showNameInputDialog('导入Excel词表');
      if (name == null || name.isEmpty) return;
      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(
        child: Card(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在导入...')]))),
      ));
      final vm = context.read<VocabularyProvider>().vocabularyManager;
      await vm.importFromExcel(file, name: name, description: '从Excel文件导入');
      if (mounted) {
        Navigator.pop(context);
        await _loadLocalLists();
        setState(() => _selectedTab = 0);
        _showSuccess('导入成功');
      }
    } catch (e) {
      if (mounted) { Navigator.pop(context); _showError('导入失败: ${_getErrorMessage(e)}'); }
    }
  }

  Future<void> _importFromJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;
      // 检查文件扩展名
      if (!filePath.toLowerCase().endsWith('.json')) {
        _showError('请选择 .json 格式的文件');
        return;
      }
      final file = File(filePath);
      final info = await _showJsonImportInfoDialog();
      if (info == null) return;
      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(
        child: Card(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在导入...')]))),
      ));
      final vm = context.read<VocabularyProvider>().vocabularyManager;
      final lists = await vm.importFromJson(file, name: info.name, description: info.description, category: info.category);
      if (mounted) {
        Navigator.pop(context);
        await _loadLocalLists();
        setState(() => _selectedTab = 0);
        final totalWords = lists.fold<int>(0, (sum, l) => sum + l.wordCount);
        _showSuccess('导入成功：${lists.length}个词表，共$totalWords个单词');
      }
    } catch (e) {
      if (mounted) { Navigator.pop(context); _showError('导入失败: ${_getErrorMessage(e)}'); }
    }
  }

  Future<_ImportInfo?> _showJsonImportInfoDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final categoryController = TextEditingController();
    return showDialog<_ImportInfo>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入JSON词表'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('JSON文件可能包含多个词表（按bookId分组），会自动创建对应词表。', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: '词表名称（可选）', hintText: '留空则自动命名', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: '分类', hintText: '如：高中、初中、四级', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: descController, decoration: const InputDecoration(labelText: '描述（可选）', border: OutlineInputBorder()), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(onPressed: () {
            Navigator.pop(context, _ImportInfo(
              name: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
              category: categoryController.text.trim().isEmpty ? null : categoryController.text.trim(),
              description: descController.text.trim().isEmpty ? null : descController.text.trim(),
            ));
          }, child: const Text('导入')),
        ],
      ),
    );
  }

  Future<String?> _showNameInputDialog(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: '词表名称', hintText: '请输入词表名称', border: OutlineInputBorder()), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('确定')),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)));
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.blue, duration: const Duration(seconds: 2)));
  }

  String _getErrorMessage(dynamic error) {
    final s = error.toString();
    if (s.contains('Exception:')) return s.split('Exception:').last.trim();
    return s;
  }
}

class _ImportInfo {
  final String? name;
  final String? category;
  final String? description;
  _ImportInfo({this.name, this.category, this.description});
}
