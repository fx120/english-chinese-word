import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../managers/statistics_manager.dart';
import '../models/user_statistics.dart';
import '../models/daily_record.dart';

/// 统计Provider
/// 
/// 封装StatisticsManager，提供状态管理和UI通知功能
/// 
/// 功能包括：
/// - 获取用户统计数据
/// - 获取词表学习进度
/// - 获取每日学习记录
/// - 更新统计数据
/// - 检查连续学习天数
/// - 增加今日学习/复习单词数
/// - 加载状态管理
/// - 错误处理
class StatisticsProvider with ChangeNotifier {
  final StatisticsManager _statisticsManager;
  UserStatistics? _statistics;
  List<DailyRecord> _dailyRecords = [];
  bool _isLoading = false;
  String? _error;
  
  StatisticsProvider(LocalDatabase db) 
      : _statisticsManager = StatisticsManager(db);
  
  // ==================== Getters ====================
  
  /// 获取用户统计数据
  UserStatistics? get statistics => _statistics;
  
  /// 获取每日学习记录列表
  List<DailyRecord> get dailyRecords => _dailyRecords;
  
  /// 获取加载状态
  bool get isLoading => _isLoading;
  
  /// 获取错误信息
  String? get error => _error;
  
  /// 获取StatisticsManager实例（供高级用法使用）
  StatisticsManager get statisticsManager => _statisticsManager;
  
  // ==================== 统计数据快捷访问 ====================
  
  /// 获取总学习天数
  int get totalDays => _statistics?.totalDays ?? 0;
  
  /// 获取连续学习天数
  int get continuousDays => _statistics?.continuousDays ?? 0;
  
  /// 获取总学习单词数
  int get totalWordsLearned => _statistics?.totalWordsLearned ?? 0;
  
  /// 获取已掌握单词数
  int get totalWordsMastered => _statistics?.totalWordsMastered ?? 0;
  
  /// 获取最后学习日期
  DateTime? get lastLearnDate => _statistics?.lastLearnDate;
  
  // ==================== 加载统计数据 ====================
  
  /// 加载用户统计数据
  /// 
  /// 从数据库加载统计信息
  Future<void> loadStatistics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _statistics = await _statisticsManager.getUserStatistics();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 加载每日学习记录
  /// 
  /// [days] 加载最近N天的记录
  Future<void> loadDailyRecords(int days) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _dailyRecords = await _statisticsManager.getDailyRecords(days);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 加载所有统计数据（统计信息 + 每日记录）
  /// 
  /// [days] 加载最近N天的记录（默认7天）
  Future<void> loadAllStatistics({int days = 7}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // 并行加载统计数据和每日记录
      await Future.wait([
        _statisticsManager.getUserStatistics().then((stats) => _statistics = stats),
        _statisticsManager.getDailyRecords(days).then((records) => _dailyRecords = records),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ==================== 更新统计数据 ====================
  
  /// 更新统计数据
  /// 
  /// 在学习或复习会话结束后调用
  /// 重新计算总学习天数、连续学习天数、总学习单词数等
  Future<void> updateStatistics() async {
    _error = null;
    
    try {
      await _statisticsManager.updateStatistics();
      
      // 更新完成后重新加载统计数据
      await loadStatistics();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  /// 检查并更新连续学习天数
  /// 
  /// 在每次学习或复习会话开始时调用
  /// 如果今天还没有学习记录，则创建新记录并更新连续天数
  Future<void> checkContinuousDays() async {
    _error = null;
    
    try {
      await _statisticsManager.checkContinuousDays();
      
      // 更新完成后重新加载统计数据
      await loadStatistics();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  // ==================== 增加今日学习数据 ====================
  
  /// 增加今日新学习单词数
  /// 
  /// [count] 新学习的单词数量
  Future<void> incrementTodayNewWords(int count) async {
    _error = null;
    
    try {
      await _statisticsManager.incrementTodayNewWords(count);
      
      // 更新完成后重新加载每日记录
      if (_dailyRecords.isNotEmpty) {
        await loadDailyRecords(_dailyRecords.length);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  /// 增加今日复习单词数
  /// 
  /// [count] 复习的单词数量
  Future<void> incrementTodayReviewWords(int count) async {
    _error = null;
    
    try {
      await _statisticsManager.incrementTodayReviewWords(count);
      
      // 更新完成后重新加载每日记录
      if (_dailyRecords.isNotEmpty) {
        await loadDailyRecords(_dailyRecords.length);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  // ==================== 词表学习进度 ====================
  
  /// 获取词表学习进度
  /// 
  /// [listId] 词表ID
  /// 
  /// 返回学习进度百分比（0.0-100.0）
  Future<double> getVocabularyListProgress(int listId) async {
    try {
      return await _statisticsManager.getVocabularyListProgress(listId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0.0;
    }
  }
  
  /// 获取待复习单词总数
  /// 
  /// 返回所有词表中待复习的单词总数
  Future<int> getTotalDueReviewCount() async {
    try {
      return await _statisticsManager.getTotalDueReviewCount();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }
  
  // ==================== 今日学习数据 ====================
  
  /// 获取今日新学习单词数
  int get todayNewWordsCount {
    if (_dailyRecords.isEmpty) return 0;
    
    final today = _formatDate(DateTime.now());
    final todayRecord = _dailyRecords.firstWhere(
      (record) => record.date == today,
      orElse: () => DailyRecord(
        date: today,
        newWordsCount: 0,
        reviewWordsCount: 0,
        createdAt: DateTime.now(),
      ),
    );
    
    return todayRecord.newWordsCount;
  }
  
  /// 获取今日复习单词数
  int get todayReviewWordsCount {
    if (_dailyRecords.isEmpty) return 0;
    
    final today = _formatDate(DateTime.now());
    final todayRecord = _dailyRecords.firstWhere(
      (record) => record.date == today,
      orElse: () => DailyRecord(
        date: today,
        newWordsCount: 0,
        reviewWordsCount: 0,
        createdAt: DateTime.now(),
      ),
    );
    
    return todayRecord.reviewWordsCount;
  }
  
  /// 获取今日总学习单词数
  int get todayTotalWordsCount => todayNewWordsCount + todayReviewWordsCount;
  
  // ==================== 辅助方法 ====================
  
  /// 格式化日期为 YYYY-MM-DD 格式
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  /// 检查今天是否已学习
  bool get hasLearnedToday {
    if (_dailyRecords.isEmpty) return false;
    
    final today = _formatDate(DateTime.now());
    return _dailyRecords.any((record) => record.date == today);
  }
  
  // ==================== 清除错误 ====================
  
  /// 清除错误信息
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// 刷新所有数据
  /// 
  /// 重新加载统计数据和每日记录
  Future<void> refresh({int days = 7}) async {
    await loadAllStatistics(days: days);
  }
}
