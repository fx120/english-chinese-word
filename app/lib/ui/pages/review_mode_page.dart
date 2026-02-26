import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/review_provider.dart';
import '../../database/local_database.dart';
import '../../models/vocabulary_list.dart';
import '../../algorithms/review_priority_algorithm.dart';
import 'review_card_page.dart';

/// 复习模式选择页面
/// 
/// 功能：
/// - 显示记忆曲线复习和错题复习两个选项
/// - 显示待复习单词数量
/// - 显示错题数量
/// - 导航到复习卡片页面
/// 
/// 需求: 9.2, 10.2
class ReviewModePage extends StatefulWidget {
  final VocabularyList vocabularyList;
  
  const ReviewModePage({
    super.key,
    required this.vocabularyList,
  });

  @override
  State<ReviewModePage> createState() => _ReviewModePageState();
}

class _ReviewModePageState extends State<ReviewModePage> {
  bool _isLoading = true;
  int _memoryCurveDueCount = 0;
  int _wrongWordsCount = 0;
  int _dailyReviewWords = 50;
  
  @override
  void initState() {
    super.initState();
    _loadReviewCounts();
  }
  
  /// 加载复习数量
  Future<void> _loadReviewCounts() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final reviewManager = context.read<ReviewProvider>().reviewManager;
      
      // 获取记忆曲线待复习数量
      final memoryCurveCount = await reviewManager.getMemoryCurveDueCount(widget.vocabularyList.id);
      
      // 获取错题数量
      final wrongWordsCount = await reviewManager.getWrongWordsCount(widget.vocabularyList.id);
      
      // 加载学习计划
      final db = context.read<LocalDatabase>();
      final plan = await db.getLearningPlan(widget.vocabularyList.id);

      if (mounted) {
        setState(() {
          _memoryCurveDueCount = memoryCurveCount;
          _wrongWordsCount = wrongWordsCount;
          if (plan != null) _dailyReviewWords = plan['daily_review_words']!;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('加载复习数据失败: ${_getErrorMessage(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择复习模式'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 词表信息卡片
                  _buildVocabularyInfoCard(),
                  
                  const SizedBox(height: 24),
                  
                  // 复习统计卡片
                  _buildReviewStatsCard(),
                  
                  const SizedBox(height: 32),
                  
                  // 复习模式选择标题
                  const Text(
                    '选择复习模式',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 记忆曲线复习模式卡片
                  _buildModeCard(
                    icon: Icons.psychology,
                    iconColor: Colors.purple,
                    title: '记忆曲线复习',
                    description: '根据艾宾浩斯遗忘曲线智能安排复习，高效巩固已学单词',
                    count: _memoryCurveDueCount,
                    countLabel: '待复习',
                    onTap: () => _startReview(ReviewMode.memoryCurve),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 错题复习模式卡片
                  _buildModeCard(
                    icon: Icons.error_outline,
                    iconColor: Colors.red,
                    title: '错题复习',
                    description: '专门复习标记为"不认识"的单词，集中攻克难点',
                    count: _wrongWordsCount,
                    countLabel: '错题',
                    onTap: () => _startReview(ReviewMode.wrongWords),
                  ),
                ],
              ),
            ),
    );
  }
  
  /// 构建词表信息卡片
  Widget _buildVocabularyInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.book,
                color: Colors.purple.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.vocabularyList.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (widget.vocabularyList.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.vocabularyList.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建复习统计卡片
  Widget _buildReviewStatsCard() {
    final totalReviewCount = _memoryCurveDueCount + _wrongWordsCount;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '复习统计',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    label: '待复习',
                    value: _memoryCurveDueCount,
                    icon: Icons.schedule,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    label: '错题',
                    value: _wrongWordsCount,
                    icon: Icons.error,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    label: '总计',
                    value: totalReviewCount,
                    icon: Icons.library_books,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建统计项
  Widget _buildStatItem({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建复习模式卡片
  Widget _buildModeCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required int count,
    required String countLabel,
    required VoidCallback onTap,
  }) {
    final hasWords = count > 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: hasWords ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: hasWords 
                          ? iconColor.withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: hasWords ? iconColor : Colors.grey.shade400,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: hasWords 
                                ? Colors.black87 
                                : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: hasWords 
                                ? Colors.grey.shade600 
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: hasWords 
                      ? iconColor.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      countLabel,
                      style: TextStyle(
                        fontSize: 14,
                        color: hasWords 
                            ? Colors.grey.shade700 
                            : Colors.grey.shade400,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: hasWords ? iconColor : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '个单词',
                          style: TextStyle(
                            fontSize: 14,
                            color: hasWords 
                                ? Colors.grey.shade700 
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!hasWords) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '暂无需要复习的单词',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
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
  
  /// 开始复习
  Future<void> _startReview(ReviewMode mode) async {
    final count = mode == ReviewMode.memoryCurve 
        ? _memoryCurveDueCount 
        : _wrongWordsCount;
    
    if (count == 0) {
      final modeName = mode == ReviewMode.memoryCurve ? '记忆曲线复习' : '错题复习';
      _showError('没有需要$modeName的单词');
      return;
    }
    
    try {
      // 导航到复习卡片页面
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewCardPage(
            vocabularyList: widget.vocabularyList,
            mode: mode,
            dailyLimit: _dailyReviewWords,
          ),
        ),
      );
      
      // 如果完成了复习，刷新数量
      if (result == true && mounted) {
        await _loadReviewCounts();
      }
    } catch (e) {
      _showError('启动复习失败: ${_getErrorMessage(e)}');
    }
  }
  
  /// 显示错误提示
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  /// 获取错误信息
  String _getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}
