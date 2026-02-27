import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/api_client.dart';

class WordSearchPage extends StatefulWidget {
  const WordSearchPage({super.key});
  @override
  State<WordSearchPage> createState() => _WordSearchPageState();
}

class _WordSearchPageState extends State<WordSearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _apiClient = ApiClient();
  final _audioPlayer = AudioPlayer();
  Timer? _debounce;

  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String? _error;
  int _total = 0;
  int _page = 1;
  bool _hasMore = true;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    // 自动弹出键盘
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _search(query.trim(), reset: true);
      } else {
        setState(() {
          _results = [];
          _total = 0;
          _error = null;
        });
      }
    });
  }

  Future<void> _search(String keyword, {bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
    }
    if (!_hasMore && !reset) return;

    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) _expandedIndex = null;
    });

    try {
      final response = await _apiClient.searchWord(keyword, page: _page, limit: 20);
      final data = response.data['data'];
      final items = (data['items'] as List).cast<Map<String, dynamic>>();
      setState(() {
        if (reset) {
          _results = items;
        } else {
          _results.addAll(items);
        }
        _total = data['total'] ?? 0;
        _hasMore = _results.length < _total;
        _page++;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _loadMore() {
    if (!_isLoading && _hasMore && _controller.text.trim().isNotEmpty) {
      _search(_controller.text.trim());
    }
  }

  Future<void> _playPronunciation(String word, {int type = 1}) async {
    final url = 'https://dict.youdao.com/dictvoice?type=$type&audio=$word';
    try {
      await _audioPlayer.play(UrlSource(url));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: _buildSearchField(),
        titleSpacing: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
      onSubmitted: (v) {
        if (v.trim().isNotEmpty) _search(v.trim(), reset: true);
      },
      decoration: InputDecoration(
        hintText: '搜索单词或释义...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        border: InputBorder.none,
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 20),
                onPressed: () {
                  _controller.clear();
                  setState(() {
                    _results = [];
                    _total = 0;
                    _error = null;
                  });
                },
              )
            : null,
      ),
      style: const TextStyle(fontSize: 15),
    );
  }

  Widget _buildBody() {
    if (_error != null && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('搜索失败', style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _search(_controller.text.trim(), reset: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _controller.text.isEmpty ? '输入单词或中文释义搜索' : '没有找到相关单词',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _results.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _results.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _buildWordItem(index, _results[index]);
        },
      ),
    );
  }

  Widget _buildWordItem(int index, Map<String, dynamic> word) {
    final isExpanded = _expandedIndex == index;
    final wordText = word['word'] ?? '';
    final phonetic = word['phonetic'] ?? '';
    final partOfSpeech = word['part_of_speech'] ?? '';
    final definition = word['definition'] ?? '';
    final example = word['example'] ?? '';
    final listNames = word['list_names'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            _expandedIndex = isExpanded ? null : index;
          });
        },
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 单词行
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wordText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3436),
                            ),
                          ),
                          if (phonetic.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              phonetic,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
                // 简要释义（收起时也显示）
                const SizedBox(height: 6),
                Text(
                  _briefDefinition(definition),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  maxLines: isExpanded ? null : 1,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                ),
                if (listNames.toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.folder_outlined, size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(listNames, style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
                // 展开详情
                if (isExpanded) ...[
                  const Divider(height: 24),
                  // 发音按钮
                  Row(
                    children: [
                      _buildPronunciationBtn('🇺🇸 美音', wordText, 1),
                      const SizedBox(width: 12),
                      _buildPronunciationBtn('🇬🇧 英音', wordText, 2),
                    ],
                  ),
                  if (partOfSpeech.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow('词性', partOfSpeech),
                  ],
                  const SizedBox(height: 12),
                  _buildDetailRow('释义', definition),
                  if (example.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow('例句', example),
                  ],
                  if (listNames.toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow('词表', listNames),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _briefDefinition(String definition) {
    // 取第一行或前50个字符
    final firstLine = definition.split('\n').first;
    return firstLine.length > 50 ? '${firstLine.substring(0, 50)}...' : firstLine;
  }

  Widget _buildPronunciationBtn(String label, String word, int type) {
    return GestureDetector(
      onTap: () => _playPronunciation(word, type: type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.volume_up_rounded, size: 18, color: Color(0xFF4A90E2)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF4A90E2))),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF4A90E2), fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF2D3436), height: 1.5)),
        ),
      ],
    );
  }
}
