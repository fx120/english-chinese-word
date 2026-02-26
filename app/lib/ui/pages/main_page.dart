import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/statistics_provider.dart';
import '../../models/vocabulary_list.dart';
import '../../models/daily_record.dart';
import '../../services/api_client.dart';
import '../../database/local_database.dart';
import 'vocabulary_list_page.dart';
import 'statistics_page.dart';
import 'settings_page.dart';
import 'login_page.dart';
import 'learning_mode_page.dart';
import 'review_mode_page.dart';
import 'vocabulary_detail_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final vocabProvider = context.read<VocabularyProvider>();
    final statsProvider = context.read<StatisticsProvider>();
    await Future.wait([
      vocabProvider.loadVocabularyLists(),
      statsProvider.loadAllStatistics(days: 7),
    ]);
  }

  void _switchToTab(int index) {
    setState(() => _currentIndex = index);
  }

  /// 检查登录状态，未登录则弹出登录页
  Future<bool> _ensureLoggedIn() async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) return true;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(
        onSwitchToTab: _switchToTab,
        onEnsureLoggedIn: _ensureLoggedIn,
      ),
      _ReviewTabPage(onSwitchToVocabulary: () => _switchToTab(0)),
      const SizedBox(), // placeholder for center FAB
      const StatisticsPage(),
      _ProfilePage(onEnsureLoggedIn: _ensureLoggedIn),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _buildBottomBar(),
      floatingActionButton: _buildCenterFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildCenterFAB() {
    return SizedBox(
      width: 56, height: 56,
      child: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const VocabularyListPage(initialTab: 1)));
        },
        elevation: 4,
        backgroundColor: const Color(0xFF4A90E2),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      height: 60,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_rounded, '首页', 0),
          _buildNavItem(Icons.replay_rounded, '复习', 1),
          const SizedBox(width: 48), // space for FAB
          _buildNavItem(Icons.bar_chart_rounded, '统计', 3),
          _buildNavItem(Icons.person_rounded, '我的', 4),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    final color = isActive ? const Color(0xFF4A90E2) : Colors.grey;
    return InkWell(
      onTap: () => _switchToTab(index),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 60, height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}


// ==================== 首页 ====================
class _HomePage extends StatefulWidget {
  final Function(int) onSwitchToTab;
  final Future<bool> Function() onEnsureLoggedIn;
  const _HomePage({required this.onSwitchToTab, required this.onEnsureLoggedIn});
  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _apiClient = ApiClient();
  final _audioPlayer = AudioPlayer();
  Timer? _debounce;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchLoading = false;
  int _searchTotal = 0;
  int _searchPage = 1;
  bool _searchHasMore = true;
  int? _expandedIndex;

  static const String _keyLastActiveListId = 'last_active_list_id';
  int? _lastActiveListId;

  @override
  void initState() {
    super.initState();
    _loadLastActiveListId();
    _refresh();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
        setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _loadLastActiveListId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastActiveListId = prefs.getInt(_keyLastActiveListId);
    });
  }

  Future<void> _saveLastActiveListId(int listId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastActiveListId, listId);
    setState(() => _lastActiveListId = listId);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchTotal = 0;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _doSearch(query.trim(), reset: true);
    });
  }

  Future<void> _doSearch(String keyword, {bool reset = false}) async {
    if (reset) {
      _searchPage = 1;
      _searchHasMore = true;
    }
    if (!_searchHasMore && !reset) return;
    setState(() {
      _isSearchLoading = true;
      if (reset) _expandedIndex = null;
    });
    try {
      final response = await _apiClient.searchWord(keyword, page: _searchPage, limit: 20);
      final data = response.data['data'];
      final items = (data['items'] as List).cast<Map<String, dynamic>>();
      setState(() {
        if (reset) {
          _searchResults = items;
        } else {
          _searchResults.addAll(items);
        }
        _searchTotal = data['total'] ?? 0;
        _searchHasMore = _searchResults.length < _searchTotal;
        _searchPage++;
        _isSearchLoading = false;
      });
    } catch (e) {
      setState(() => _isSearchLoading = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
      _searchTotal = 0;
      _isSearching = false;
      _expandedIndex = null;
    });
  }

  Future<void> _playPronunciation(String word, {int type = 1}) async {
    final url = 'https://dict.youdao.com/dictvoice?type=$type&audio=$word';
    try {
      await _audioPlayer.play(UrlSource(url));
    } catch (_) {}
  }

  Future<void> _refresh() async {
    final stats = context.read<StatisticsProvider>();
    final vocab = context.read<VocabularyProvider>();
    await Future.wait([
      stats.loadAllStatistics(days: 7),
      vocab.loadVocabularyLists(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          _buildGradientHeader(),
          if (_isSearching) ...[
            _buildSearchResultsSliver(),
          ] else ...[
            SliverToBoxAdapter(child: _buildTodayPlanCard()),
            SliverToBoxAdapter(child: _buildWeeklyStatsCard()),
            SliverToBoxAdapter(child: _buildQuickActions()),
            SliverToBoxAdapter(child: _buildMyWordBooks()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }

  Widget _buildGradientHeader() {
    return SliverToBoxAdapter(
      child: Consumer2<AuthProvider, StatisticsProvider>(
        builder: (context, auth, stats, _) {
          final name = auth.isLoggedIn ? (auth.user?.nickname ?? '同学') : '同学';
          final streak = stats.continuousDays;
          return Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 20, right: 20, bottom: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      child: const Icon(Icons.person, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('你好, $name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('今天也是进步的一天 ✨', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text('$streak 天', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search bar - 直接输入搜索
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (v) {
                            if (v.trim().isNotEmpty) _doSearch(v.trim(), reset: true);
                          },
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          cursorColor: Colors.white,
                          decoration: InputDecoration(
                            hintText: '搜索单词或词组...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: _clearSearch,
                          child: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.7), size: 18),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodayPlanCard() {
    return Consumer2<VocabularyProvider, StatisticsProvider>(
      builder: (context, vocab, stats, _) {
        final lists = vocab.vocabularyLists;
        if (lists.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _buildEmptyPlanCard(),
          );
        }
        // 优先展示最后学习的词表
        VocabularyList activeList;
        if (_lastActiveListId != null) {
          activeList = lists.firstWhere(
            (l) => l.id == _lastActiveListId,
            orElse: () => lists.first,
          );
        } else {
          activeList = lists.first;
        }
        final todayNew = stats.todayNewWordsCount;
        final todayReview = stats.todayReviewWordsCount;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('📋', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    const Text('今日计划', style: TextStyle(fontSize: 13, color: Color(0xFF4A90E2), fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Icon(Icons.description_outlined, color: Colors.grey.shade400, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                Text(activeList.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text('$todayNew', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
                    const SizedBox(width: 6),
                    Text('/ $todayReview 单词待复习', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (todayNew + todayReview) > 0 ? 0.3 : 0,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4A90E2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _startLearning(activeList),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('开始学习'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90E2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => _startReview(activeList),
                        icon: const Icon(Icons.shuffle_rounded, color: Color(0xFF4A90E2)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyPlanCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Icon(Icons.library_add, size: 48, color: Color(0xFF4A90E2)),
          const SizedBox(height: 12),
          const Text('还没有词表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
          const SizedBox(height: 6),
          Text('下载或导入一个词表开始学习吧', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VocabularyListPage(initialTab: 1)));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('去发现词表'),
          ),
        ],
      ),
    );
  }

  void _startLearning(VocabularyList list) {
    _saveLastActiveListId(list.id);
    Navigator.push(context, MaterialPageRoute(builder: (_) => LearningModePage(vocabularyList: list)));
  }

  void _startReview(VocabularyList list) {
    _saveLastActiveListId(list.id);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewModePage(vocabularyList: list)));
  }

  Widget _buildWeeklyStatsCard() {
    return Consumer<StatisticsProvider>(
      builder: (context, stats, _) {
        final records = stats.dailyRecords;
        final weekTotal = records.fold<int>(0, (sum, r) => sum + r.newWordsCount + r.reviewWordsCount);
        final mastered = stats.totalWordsMastered;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('学习统计', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => widget.onSwitchToTab(3),
                      child: const Text('详细数据 >', style: TextStyle(fontSize: 13, color: Color(0xFF4A90E2))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildStatColumn('本周已学', '$weekTotal')),
                    Container(width: 1, height: 40, color: Colors.grey.shade200),
                    Expanded(child: _buildStatColumn('累计掌握', '$mastered')),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _buildWeekBars(records),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
                      .map((d) => SizedBox(width: 36, child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey.shade500))))
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
      ],
    );
  }

  List<Widget> _buildWeekBars(List<DailyRecord> records) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final maxVal = records.isEmpty ? 1 : records.fold<int>(0, (m, r) => (r.newWordsCount + r.reviewWordsCount) > m ? (r.newWordsCount + r.reviewWordsCount) : m).clamp(1, 999999);

    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final dayStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final record = records.where((r) => r.date == dayStr).toList();
      final val = record.isEmpty ? 0 : record.first.newWordsCount + record.first.reviewWordsCount;
      final height = val > 0 ? (val / maxVal * 50).clamp(4.0, 50.0) : 4.0;
      final isToday = day.day == now.day && day.month == now.month;

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: isToday ? const Color(0xFF4A90E2) : const Color(0xFFD6E4FF),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('快捷功能', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionCard('词表管理', Icons.library_books_rounded, const Color(0xFF4A90E2), const Color(0xFFE8F0FE), () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VocabularyListPage()));
              }),
              const SizedBox(width: 12),
              _buildActionCard('复习模式', Icons.replay_rounded, const Color(0xFFE67E22), const Color(0xFFFFF3E0), () => widget.onSwitchToTab(1)),
              const SizedBox(width: 12),
              _buildActionCard('生词本', Icons.bookmark_rounded, const Color(0xFF9B59B6), const Color(0xFFF3E5F5), () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String label, IconData icon, Color iconColor, Color bgColor, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: iconColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyWordBooks() {
    return Consumer<VocabularyProvider>(
      builder: (context, provider, _) {
        final lists = provider.vocabularyLists;
        if (lists.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('我的词书', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
              const SizedBox(height: 12),
              ...lists.map((list) => _buildWordBookItem(list)),
            ],
          ),
        );
      },
    );
  }

  // ==================== 搜索结果 ====================

  Widget _buildSearchResultsSliver() {
    if (_isSearchLoading && _searchResults.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_searchResults.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('没有找到相关单词', style: TextStyle(fontSize: 15, color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _searchResults.length) {
            if (_searchHasMore) {
              _doSearch(_searchController.text.trim());
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('共 $_searchTotal 个结果', style: TextStyle(fontSize: 13, color: Colors.grey.shade500))),
            );
          }
          return _buildSearchWordItem(index, _searchResults[index]);
        },
        childCount: _searchResults.length + 1,
      ),
    );
  }

  Widget _buildSearchWordItem(int index, Map<String, dynamic> word) {
    final isExpanded = _expandedIndex == index;
    final wordText = word['word'] ?? '';
    final phonetic = word['phonetic'] ?? '';
    final partOfSpeech = word['part_of_speech'] ?? '';
    final definition = word['definition'] ?? '';
    final example = word['example'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(wordText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
                          if (phonetic.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(phonetic, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          ],
                        ],
                      ),
                    ),
                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade400),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  definition.toString().split('\n').first,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  maxLines: isExpanded ? null : 1,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                ),
                if (isExpanded) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      _buildPronBtn('🇺🇸 美音', wordText, 1),
                      const SizedBox(width: 12),
                      _buildPronBtn('🇬🇧 英音', wordText, 2),
                    ],
                  ),
                  if (partOfSpeech.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailLabel('词性', partOfSpeech),
                  ],
                  const SizedBox(height: 12),
                  _buildDetailLabel('释义', definition),
                  if (example.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailLabel('例句', example),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPronBtn(String label, String word, int type) {
    return GestureDetector(
      onTap: () => _playPronunciation(word, type: type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(20)),
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

  Widget _buildDetailLabel(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(4)),
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF4A90E2), fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF2D3436), height: 1.5))),
      ],
    );
  }

  Widget _buildWordBookItem(VocabularyList list) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // 左侧图标 - 点击进入词表详情
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VocabularyDetailPage(vocabularyList: list))),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          // 中间文字 - 点击进入词表详情
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VocabularyDetailPage(vocabularyList: list))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(list.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
                  const SizedBox(height: 3),
                  Text('${list.wordCount} 个单词', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
          // 开始学习按钮
          GestureDetector(
            onTap: () => _startLearning(list),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('学习', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          // 更多操作（删除）
          GestureDetector(
            onTap: () => _showWordBookActions(list),
            child: Icon(Icons.more_vert, color: Colors.grey.shade400, size: 20),
          ),
        ],
      ),
    );
  }

  void _showWordBookActions(VocabularyList list) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(list.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded, color: Color(0xFF4A90E2)),
                title: const Text('开始学习'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startLearning(list);
                },
              ),
              ListTile(
                leading: const Icon(Icons.replay_rounded, color: Color(0xFFE67E22)),
                title: const Text('复习模式'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startReview(list);
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt_rounded, color: Color(0xFF9B59B6)),
                title: const Text('查看词表'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => VocabularyDetailPage(vocabularyList: list)));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('删除词表', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteList(list);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteList(VocabularyList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除词表'),
        content: Text('确定要删除「${list.name}」吗？\n\n删除后该词表的学习进度也会清除。'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final vocab = context.read<VocabularyProvider>();
      await vocab.deleteVocabularyList(list.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除「${list.name}」'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}


// ==================== 复习标签页 ====================
class _ReviewTabPage extends StatelessWidget {
  final VoidCallback onSwitchToVocabulary;
  const _ReviewTabPage({required this.onSwitchToVocabulary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('复习'),
        backgroundColor: const Color(0xFF7B68EE),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<VocabularyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());
          if (provider.vocabularyLists.isEmpty) return _buildEmptyState(context);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.vocabularyLists.length,
            itemBuilder: (context, index) => _buildListCard(context, provider.vocabularyLists[index]),
          );
        },
      ),
    );
  }

  Widget _buildListCard(BuildContext context, VocabularyList list) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewModePage(vocabularyList: list))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.replay_rounded, color: Color(0xFF7B68EE), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(list.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${list.wordCount} 个单词', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.replay_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('暂无可复习的词表', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onSwitchToVocabulary,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B68EE), foregroundColor: Colors.white),
            child: const Text('去添加词表'),
          ),
        ],
      ),
    );
  }
}

// ==================== 我的（个人中心） ====================
class _ProfilePage extends StatelessWidget {
  final Future<bool> Function() onEnsureLoggedIn;
  const _ProfilePage({required this.onEnsureLoggedIn});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildProfileHeader(context, auth)),
              SliverToBoxAdapter(child: _buildMenuSection(context, auth)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AuthProvider auth) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, left: 20, right: 20, bottom: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            child: const Icon(Icons.person, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: auth.isLoggedIn
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.user?.nickname ?? '用户', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(auth.user?.mobile ?? '', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                    ],
                  )
                : GestureDetector(
                    onTap: () => onEnsureLoggedIn(),
                    child: const Text('点击登录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildMenuItem(Icons.library_books_rounded, '词表管理', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const VocabularyListPage()));
          }),
          _buildMenuItem(Icons.settings_rounded, '设置', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
          }),
          _buildMenuItem(Icons.cleaning_services_rounded, '清除缓存', () {
            _confirmClearCache(context);
          }, color: Colors.orange),
          if (auth.isLoggedIn)
            _buildMenuItem(Icons.logout_rounded, '退出登录', () {
              _confirmLogout(context, auth);
            }, color: Colors.red),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出登录后，本地词表和学习进度数据仍会保留在本机。\n\n如需彻底清除数据，请在「我的」中点击「清除缓存」。'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await auth.logout();
    }
  }

  Future<void> _confirmClearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('将清除本地所有词表、学习进度、统计数据等缓存。\n\n此操作不可恢复，确定要清除吗？'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        // 删除本地数据库
        final dbPath = p.join(await getDatabasesPath(), 'vocabulary_app.db');
        await deleteDatabase(dbPath);
        // 清除 SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        // 刷新 providers
        if (context.mounted) {
          await context.read<VocabularyProvider>().loadVocabularyLists();
          await context.read<StatisticsProvider>().loadAllStatistics(days: 7);
          // 重新初始化数据库（下次访问时自动创建）
          context.read<LocalDatabase>().resetDatabase();
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('缓存已清除'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清除失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: color ?? const Color(0xFF4A90E2)),
        title: Text(title, style: TextStyle(color: color ?? const Color(0xFF2D3436))),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
