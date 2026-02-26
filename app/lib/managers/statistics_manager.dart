import 'package:sqflite/sqflite.dart';
import '../database/local_database.dart';
import '../models/user_statistics.dart';
import '../models/daily_record.dart';
import '../models/user_word_progress.dart';
import '../algorithms/continuous_days_calculator.dart';

/// 统计管理器
/// 负责管理用户学习统计数据，包括总学习天数、连续学习天数、
/// 总学习单词数、已掌握单词数、待复习单词数等
class StatisticsManager {
  final LocalDatabase _db;
  
  StatisticsManager(this._db);
  
  /// 获取用户统计数据
  /// 返回包含总学习天数、连续学习天数、总学习单词数、已掌握单词数等信息
  Future<UserStatistics> getUserStatistics() async {
    // 从数据库获取统计数据
    UserStatistics? stats = await _db.getStatistics();
    
    // 如果不存在，创建初始统计数据
    if (stats == null) {
      stats = UserStatistics(
        totalDays: 0,
        continuousDays: 0,
        totalWordsLearned: 0,
        totalWordsMastered: 0,
        lastLearnDate: null,
        updatedAt: DateTime.now(),
      );
      await _db.updateStatistics(stats);
    }
    
    return stats;
  }
  
  /// 获取词表学习进度百分比
  /// [listId] 词表ID
  /// 返回学习进度百分比 (0-100)
  Future<double> getVocabularyListProgress(int listId) async {
    // 获取词表总单词数（排除已标记排除的单词）
    final allWords = await _db.getWordsByListId(listId, includeExcluded: false);
    final totalCount = allWords.length;
    
    if (totalCount == 0) {
      return 0.0;
    }
    
    // 获取已学习的单词数（状态为mastered或needReview）
    final progressList = await _db.getProgressByListId(listId);
    final learnedCount = progressList.where((progress) {
      return progress.status == LearningStatus.mastered || 
             progress.status == LearningStatus.needReview;
    }).length;
    
    // 计算进度百分比
    return (learnedCount / totalCount * 100).clamp(0.0, 100.0);
  }
  
  /// 获取最近N天的学习记录
  /// [days] 天数
  /// 返回每日学习记录列表，按日期降序排列
  Future<List<DailyRecord>> getDailyRecords(int days) async {
    return await _db.getDailyRecords(days);
  }
  
  /// 更新统计数据
  /// 在学习或复习会话结束后调用，更新总学习天数、连续学习天数、
  /// 总学习单词数、已掌握单词数等统计信息
  Future<void> updateStatistics() async {
    // 获取当前统计数据
    UserStatistics? currentStats = await _db.getStatistics();
    
    // 获取所有学习进度
    final db = await _db.database;
    final progressMaps = await db.query('user_word_progress');
    final allProgress = progressMaps.map((map) => UserWordProgress.fromJson(map)).toList();
    
    // 计算总学习单词数（状态不是notLearned的单词）
    final totalWordsLearned = allProgress.where((progress) {
      return progress.status != LearningStatus.notLearned;
    }).length;
    
    // 计算已掌握单词数
    final totalWordsMastered = allProgress.where((progress) {
      return progress.status == LearningStatus.mastered;
    }).length;
    
    // 获取今天的日期
    final today = DateTime.now();
    final todayStr = _formatDate(today);
    
    // 检查今天是否有学习记录
    final todayRecord = await _db.getDailyRecord(todayStr);
    
    // 计算总学习天数
    final allRecords = await _db.getAllDailyRecords();
    final totalDays = allRecords.length;
    
    // 计算连续学习天数
    final continuousDays = ContinuousDaysCalculator.calculateContinuousDays(allRecords);
    
    // 更新统计数据
    final updatedStats = UserStatistics(
      totalDays: totalDays,
      continuousDays: continuousDays,
      totalWordsLearned: totalWordsLearned,
      totalWordsMastered: totalWordsMastered,
      lastLearnDate: todayRecord != null ? today : currentStats?.lastLearnDate,
      updatedAt: DateTime.now(),
    );
    
    await _db.updateStatistics(updatedStats);
  }
  
  /// 检查并更新连续学习天数
  /// 在每次学习或复习会话开始时调用，检查今天是否已有学习记录，
  /// 如果没有则创建新记录，并更新连续学习天数
  Future<void> checkContinuousDays() async {
    final today = DateTime.now();
    final todayStr = _formatDate(today);
    
    // 检查今天是否已有学习记录
    final todayRecord = await _db.getDailyRecord(todayStr);
    
    if (todayRecord == null) {
      // 创建今天的学习记录
      final newRecord = DailyRecord(
        date: todayStr,
        newWordsCount: 0,
        reviewWordsCount: 0,
        createdAt: DateTime.now(),
      );
      await _db.insertDailyRecord(newRecord);
      
      // 更新统计数据
      await updateStatistics();
    }
  }
  
  /// 增加今日新学习单词数
  /// [count] 新学习的单词数量
  Future<void> incrementTodayNewWords(int count) async {
    final today = DateTime.now();
    final todayStr = _formatDate(today);
    
    // 获取今天的学习记录
    DailyRecord? todayRecord = await _db.getDailyRecord(todayStr);
    
    if (todayRecord == null) {
      // 创建今天的学习记录
      todayRecord = DailyRecord(
        date: todayStr,
        newWordsCount: count,
        reviewWordsCount: 0,
        createdAt: DateTime.now(),
      );
      await _db.insertDailyRecord(todayRecord);
    } else {
      // 更新今天的学习记录
      final updatedRecord = DailyRecord(
        date: todayStr,
        newWordsCount: todayRecord.newWordsCount + count,
        reviewWordsCount: todayRecord.reviewWordsCount,
        createdAt: todayRecord.createdAt,
      );
      await _db.updateDailyRecord(updatedRecord);
    }
  }
  
  /// 增加今日复习单词数
  /// [count] 复习的单词数量
  Future<void> incrementTodayReviewWords(int count) async {
    final today = DateTime.now();
    final todayStr = _formatDate(today);
    
    // 获取今天的学习记录
    DailyRecord? todayRecord = await _db.getDailyRecord(todayStr);
    
    if (todayRecord == null) {
      // 创建今天的学习记录
      todayRecord = DailyRecord(
        date: todayStr,
        newWordsCount: 0,
        reviewWordsCount: count,
        createdAt: DateTime.now(),
      );
      await _db.insertDailyRecord(todayRecord);
    } else {
      // 更新今天的学习记录
      final updatedRecord = DailyRecord(
        date: todayStr,
        newWordsCount: todayRecord.newWordsCount,
        reviewWordsCount: todayRecord.reviewWordsCount + count,
        createdAt: todayRecord.createdAt,
      );
      await _db.updateDailyRecord(updatedRecord);
    }
  }
  
  /// 获取待复习单词数量
  /// 返回所有词表中待复习的单词总数
  Future<int> getTotalDueReviewCount() async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM user_word_progress
      WHERE status = ? AND next_review_at <= ?
    ''', ['need_review', now]);
    
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  /// 格式化日期为 YYYY-MM-DD 格式
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
