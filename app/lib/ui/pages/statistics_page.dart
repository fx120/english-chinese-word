import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/statistics_provider.dart';
import '../../database/local_database.dart';
import '../../models/daily_record.dart';
import '../../models/vocabulary_list.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<VocabularyList> _vocabularyLists = [];
  Map<int, double> _listProgress = {};
  int _dueReviewCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sp = context.read<StatisticsProvider>();
      final db = context.read<LocalDatabase>();
      final sm = sp.statisticsManager;
      await sm.updateStatistics();
      await sp.loadAllStatistics(days: 30);
      final lists = await db.getAllVocabularyLists();
      final Map<int, double> progress = {};
      for (var list in lists) {
        progress[list.id] = await sm.getVocabularyListProgress(list.id);
      }
      final due = await sm.getTotalDueReviewCount();
      if (mounted) {
        setState(() {
          _vocabularyLists = lists;
          _listProgress = progress;
          _dueReviewCount = due;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _loadData, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return Consumer<StatisticsProvider>(
      builder: (context, stats, _) {
        final records = stats.dailyRecords;
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeader(stats),
            SliverToBoxAdapter(child: _buildTodayCard(stats)),
            SliverToBoxAdapter(child: _buildStreakAndTotal(stats)),
            SliverToBoxAdapter(child: _buildChartCard(records)),
            SliverToBoxAdapter(child: _buildVocabularyProgress()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  // ==================== 顶部渐变头 ====================
  Widget _buildHeader(StatisticsProvider stats) {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20, right: 20, bottom: 28,
        ),
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
                const Text('学习统计', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                GestureDetector(
                  onTap: _loadData,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 大数字展示
            Row(
              children: [
                _buildHeaderStat('${stats.totalWordsLearned}', '累计学习'),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3), margin: const EdgeInsets.symmetric(horizontal: 24)),
                _buildHeaderStat('${stats.totalWordsMastered}', '已掌握'),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3), margin: const EdgeInsets.symmetric(horizontal: 24)),
                _buildHeaderStat('$_dueReviewCount', '待复习'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  // ==================== 今日学习卡片 ====================
  Widget _buildTodayCard(StatisticsProvider stats) {
    final newW = stats.todayNewWordsCount;
    final revW = stats.todayReviewWordsCount;
    final total = newW + revW;

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
                const Text('📖', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                const Text('今日学习', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
                const Spacer(),
                Text(_formatDate(DateTime.now()), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildTodayItem('新学', newW, const Color(0xFF4A90E2), const Color(0xFFE8F0FE)),
                const SizedBox(width: 12),
                _buildTodayItem('复习', revW, const Color(0xFFE67E22), const Color(0xFFFFF3E0)),
                const SizedBox(width: 12),
                _buildTodayItem('总计', total, const Color(0xFF9B59B6), const Color(0xFFF3E5F5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayItem(String label, int value, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  // ==================== 连续天数 & 总天数 ====================
  Widget _buildStreakAndTotal(StatisticsProvider stats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                    child: const Text('🔥', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${stats.continuousDays}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE67E22))),
                      Text('连续天数', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(12)),
                    child: const Text('📅', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${stats.totalDays}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2))),
                      Text('总学习天数', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 学习曲线图 ====================
  Widget _buildChartCard(List<DailyRecord> records) {
    final now = DateTime.now();
    final days = <_DayData>[];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = _formatDateFull(date);
      final record = records.where((r) => r.date == dateStr).toList();
      final newW = record.isEmpty ? 0 : record.first.newWordsCount;
      final revW = record.isEmpty ? 0 : record.first.reviewWordsCount;
      days.add(_DayData(
        label: '${date.month}/${date.day}',
        weekday: _weekdayLabel(date.weekday),
        newCount: newW,
        reviewCount: revW,
        isToday: i == 0,
      ));
    }
    final maxVal = days.fold<int>(0, (m, d) => (d.newCount + d.reviewCount) > m ? (d.newCount + d.reviewCount) : m).clamp(1, 999999);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                const Text('📊', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                const Text('最近7天', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
                const Spacer(),
                // 图例
                _buildLegend(const Color(0xFF4A90E2), '新学'),
                const SizedBox(width: 12),
                _buildLegend(const Color(0xFF7B68EE), '复习'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: days.map((d) => _buildBarColumn(d, maxVal)).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: days.map((d) => Expanded(
                child: Text(
                  d.isToday ? '今天' : d.weekday,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: d.isToday ? const Color(0xFF4A90E2) : Colors.grey.shade500,
                    fontWeight: d.isToday ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildBarColumn(_DayData d, int maxVal) {
    final total = d.newCount + d.reviewCount;
    final totalH = total > 0 ? (total / maxVal * 110).clamp(6.0, 110.0) : 4.0;
    final newH = total > 0 ? (d.newCount / total * totalH) : 0.0;
    final revH = total > 0 ? totalH - newH : 0.0;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (total > 0)
              Text('$total', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            // 堆叠柱状图
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Column(
                children: [
                  // 复习部分（上）
                  if (revH > 0)
                    Container(height: revH, color: d.isToday ? const Color(0xFF7B68EE) : const Color(0xFFD6CCFF)),
                  // 新学部分（下）
                  Container(
                    height: newH > 0 ? newH : 4,
                    color: d.isToday ? const Color(0xFF4A90E2) : const Color(0xFFD6E4FF),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayLabel(int weekday) {
    const labels = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return labels[weekday];
  }

  // ==================== 词表学习进度 ====================
  Widget _buildVocabularyProgress() {
    if (_vocabularyLists.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                const Text('📚', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                const Text('词表进度', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
              ],
            ),
            const SizedBox(height: 16),
            ..._vocabularyLists.map((list) {
              final progress = _listProgress[list.id] ?? 0.0;
              return _buildProgressRow(list, progress);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(VocabularyList list, double progress) {
    final color = progress >= 80
        ? const Color(0xFF27AE60)
        : progress >= 40
            ? const Color(0xFFE67E22)
            : const Color(0xFF4A90E2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(list.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3436)), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('共 ${list.wordCount} 个单词', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Text('${progress.toStringAsFixed(1)}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 工具方法 ====================
  String _formatDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  String _formatDateFull(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _DayData {
  final String label;
  final String weekday;
  final int newCount;
  final int reviewCount;
  final bool isToday;
  const _DayData({required this.label, required this.weekday, required this.newCount, required this.reviewCount, required this.isToday});
}
