import '../database/local_database.dart';
import '../models/user_word_progress.dart';
import 'memory_curve_algorithm.dart';

/// 复习模式枚举
enum ReviewMode {
  memoryCurve,  // 记忆曲线复习
  wrongWords,   // 错题复习
}

/// 复习优先级算法
/// 
/// 支持两种复习模式：
/// 1. 记忆曲线模式：获取到期需要复习的单词，按到期时间排序
/// 2. 错题模式：获取错误次数>0的单词，按错误次数排序
class ReviewPriorityAlgorithm {
  /// 获取待复习单词列表(按优先级排序)
  /// 
  /// [db] 本地数据库实例
  /// [listId] 词表ID
  /// [mode] 复习模式（记忆曲线或错题）
  /// 
  /// 返回排序后的单词ID列表
  /// 
  /// 记忆曲线模式：
  /// - 筛选状态为need_review且到期的单词
  /// - 按过期时间排序（过期越久越优先）
  /// 
  /// 错题模式：
  /// - 筛选错误次数>0的单词
  /// - 按错误次数降序排序（错误越多越优先）
  static Future<List<int>> getDueReviewWords(
    LocalDatabase db,
    int listId,
    ReviewMode mode,
  ) async {
    // 获取词表的所有学习进度
    List<UserWordProgress> progressList = await db.getProgressByListId(listId);
    
    // 获取排除的单词ID列表
    List<int> excludedWordIds = await db.getExcludedWordIds(listId);
    
    if (mode == ReviewMode.memoryCurve) {
      // 记忆曲线复习: 筛选到期的单词
      List<UserWordProgress> dueWords = progressList.where((progress) {
        // 过滤排除的单词
        if (excludedWordIds.contains(progress.wordId)) {
          return false;
        }
        
        // 只选择需要复习状态的单词
        if (progress.status != LearningStatus.needReview) {
          return false;
        }
        
        // 检查是否到期
        return MemoryCurveAlgorithm.isDueForReview(progress.nextReviewAt);
      }).toList();
      
      // 按过期时间排序(过期越久越优先)
      // 使用getReviewPriority计算优先级，返回过期小时数
      dueWords.sort((a, b) {
        if (a.nextReviewAt == null || b.nextReviewAt == null) {
          return 0;
        }
        int priorityA = MemoryCurveAlgorithm.getReviewPriority(a.nextReviewAt!);
        int priorityB = MemoryCurveAlgorithm.getReviewPriority(b.nextReviewAt!);
        // 降序排序：优先级高的（过期时间长的）排在前面
        return priorityB.compareTo(priorityA);
      });
      
      return dueWords.map((p) => p.wordId).toList();
      
    } else if (mode == ReviewMode.wrongWords) {
      // 错题复习: 筛选错误次数>0的单词
      List<UserWordProgress> wrongWords = progressList.where((progress) {
        // 过滤排除的单词
        if (excludedWordIds.contains(progress.wordId)) {
          return false;
        }
        
        // 只选择错误次数大于0的单词
        return progress.errorCount > 0;
      }).toList();
      
      // 按错误次数排序(错误越多越优先)
      wrongWords.sort((a, b) => b.errorCount.compareTo(a.errorCount));
      
      return wrongWords.map((p) => p.wordId).toList();
    }
    
    return [];
  }
}
