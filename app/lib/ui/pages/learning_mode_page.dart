import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/learning_provider.dart';
import '../../database/local_database.dart';
import '../../models/vocabulary_list.dart';
import '../../managers/learning_manager.dart';
import 'learning_card_page.dart';

class LearningModePage extends StatefulWidget {
  final VocabularyList vocabularyList;
  const LearningModePage({super.key, required this.vocabularyList});

  @override
  State<LearningModePage> createState() => _LearningModePageState();
}

class _LearningModePageState extends State<LearningModePage> {
  bool _isLoading = true;
  int _totalWords = 0;
  int _learnedWords = 0;
  int _masteredWords = 0;
  int _needReviewWords = 0;
  int _unlearnedWords = 0;
  double _progress = 0.0;

  // 学习计划
  int _dailyNewWords = 20;
  int _dailyReviewWords = 50;
  bool _hasPlan = false;
  int _todayLearned = 0;
  int _todayRemaining = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final lm = context.read<LearningProvider>().learningManager;
      final db = context.read<LocalDatabase>();

      final progress = await lm.getLearningProgress(widget.vocabularyList.id);
      final unlearnedCount = await lm.getUnlearnedWordCount(widget.vocabularyList.id);
      final masteredCount = await lm.getMasteredWordCount(widget.vocabularyList.id);
      final needReviewCount = await lm.getNeedReviewWordCount(widget.vocabularyList.id);

      // 加载学习计划
      final plan = await db.getLearningPlan(widget.vocabularyList.id);
      final todayLearned = await db.getTodayLearnedCount(widget.vocabularyList.id);

      if (mounted) {
        setState(() {
          _progress = progress;
          _unlearnedWords = unlearnedCount;
          _masteredWords = masteredCount;
          _needReviewWords = needReviewCount;
          _learnedWords = masteredCount + needReviewCount;
          _totalWords = widget.vocabularyList.wordCount;
          _todayLearned = todayLearned;
          if (plan != null) {
            _hasPlan = true;
            _dailyNewWords = plan['daily_new_words']!;
            _dailyReviewWords = plan['daily_review_words']!;
          }
          _todayRemaining = (_dailyNewWords - _todayLearned).clamp(0, _unlearnedWords);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('加载失败: ${_getErrorMessage(e)}');
      }
    }
  }

  Future<void> _showPlanDialog() async {
    int newWords = _dailyNewWords;
    int reviewWords = _dailyReviewWords;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('学习计划', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('设置每天的学习目标', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 20),
            _planSlider(ctx, setDialogState, '每日新学单词', newWords, 5, 100, Colors.blue, (v) {
              setDialogState(() => newWords = v);
            }),
            const SizedBox(height: 16),
            _planSlider(ctx, setDialogState, '每日复习单词', reviewWords, 10, 200, Colors.purple, (v) {
              setDialogState(() => reviewWords = v);
            }),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      final db = context.read<LocalDatabase>();
      await db.saveLearningPlan(widget.vocabularyList.id, newWords, reviewWords);
      setState(() {
        _dailyNewWords = newWords;
        _dailyReviewWords = reviewWords;
        _hasPlan = true;
        _todayRemaining = (_dailyNewWords - _todayLearned).clamp(0, _unlearnedWords);
      });
    }
  }

  Widget _planSlider(BuildContext ctx, StateSetter setDialogState, String label, int value, int min, int max, Color color, ValueChanged<int> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text('$value 个', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ),
      ]),
      Slider(
        value: value.toDouble(), min: min.toDouble(), max: max.toDouble(),
        divisions: (max - min) ~/ 5, activeColor: color,
        onChanged: (v) => onChanged(v.round()),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习'),
        backgroundColor: Colors.blue, foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.tune), tooltip: '学习计划', onPressed: _showPlanDialog),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _buildTodayPlanCard(),
                const SizedBox(height: 16),
                _buildProgressCard(),
                const SizedBox(height: 24),
                const Text('选择学习模式', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildModeCard(Icons.shuffle, Colors.orange, '随机学习', '随机抽取未学习的单词', () => _startLearning(LearningMode.random)),
                const SizedBox(height: 12),
                _buildModeCard(Icons.format_list_numbered, Colors.green, '顺序学习', '按词表顺序学习单词', () => _startLearning(LearningMode.sequential)),
              ]),
            ),
    );
  }

  Widget _buildTodayPlanCard() {
    final todayDone = _todayLearned;
    final todayGoal = _dailyNewWords;
    final pct = todayGoal > 0 ? (todayDone / todayGoal).clamp(0.0, 1.0) : 0.0;
    final completed = todayDone >= todayGoal;

    return Card(
      elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.today, color: Colors.blue.shade700, size: 22),
          const SizedBox(width: 8),
          const Text('今日学习', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (completed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                const SizedBox(width: 4),
                Text('已完成', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
              ]),
            )
          else
            Text('$todayDone / $todayGoal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct, minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(completed ? Colors.green : Colors.blue.shade600),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _todayStat('新学', todayDone, Colors.blue),
          const SizedBox(width: 16),
          _todayStat('剩余', _todayRemaining, Colors.orange),
          const SizedBox(width: 16),
          _todayStat('未学', _unlearnedWords, Colors.grey),
        ]),
        if (!_hasPlan) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: _showPlanDialog,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('点击设置每日学习计划', style: TextStyle(fontSize: 13, color: Colors.blue.shade700))),
                Icon(Icons.arrow_forward_ios, color: Colors.blue.shade400, size: 14),
              ]),
            ),
          ),
        ],
      ])),
    );
  }

  Widget _todayStat(String label, int value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ]),
    ));
  }

  Widget _buildProgressCard() {
    return Card(
      elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('总体进度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('${_progress.toStringAsFixed(1)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: _progress / 100, minHeight: 10, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _progressChip('总词数', _totalWords, Colors.blue),
          const SizedBox(width: 8),
          _progressChip('已掌握', _masteredWords, Colors.green),
          const SizedBox(width: 8),
          _progressChip('需复习', _needReviewWords, Colors.orange),
        ]),
      ])),
    );
  }

  Widget _progressChip(String label, int value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ]),
    ));
  }

  Widget _buildModeCard(IconData icon, Color color, String title, String desc, VoidCallback onTap) {
    final enabled = _unlearnedWords > 0 && _todayRemaining > 0;
    return Card(
      elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: enabled ? color.withValues(alpha: 0.1) : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: enabled ? color : Colors.grey.shade400, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: enabled ? Colors.black87 : Colors.grey.shade400)),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(fontSize: 13, color: enabled ? Colors.grey.shade600 : Colors.grey.shade400)),
          ])),
          Icon(Icons.arrow_forward_ios, color: enabled ? Colors.grey.shade400 : Colors.grey.shade300, size: 18),
        ])),
      ),
    );
  }

  Future<void> _startLearning(LearningMode mode) async {
    if (_unlearnedWords == 0) { _showError('没有可学习的单词'); return; }
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => LearningCardPage(
        vocabularyList: widget.vocabularyList, mode: mode,
        dailyLimit: _dailyNewWords, todayLearned: _todayLearned,
      ),
    ));
    if (result == true && mounted) await _loadAll();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  String _getErrorMessage(dynamic e) {
    if (e is Exception) return e.toString().replaceFirst('Exception: ', '');
    return e.toString();
  }
}
