import 'dart:math';
import '../models/user_word_progress.dart';
import '../models/user_statistics.dart';

/// 数据同步冲突解决算法
/// 
/// 实现需求14.4和14.5的冲突解决策略：
/// - 比较memory_level，保留更高的
/// - 如果memory_level相同，比较last_review_at，保留更新的
/// - 统计数据合并：取最大值
class SyncConflictResolver {
  /// 解决学习进度同步冲突
  /// 
  /// 策略: 保留学习进度更高的数据
  /// 1. 比较记忆级别(memory_level)，保留更高的
  /// 2. 如果记忆级别相同，比较复习次数(review_count)，保留更多的
  /// 3. 如果复习次数也相同，比较最后复习时间(last_review_at)，保留更新的
  /// 4. 如果都相同，默认保留本地数据
  /// 
  /// [local] 本地数据
  /// [remote] 远程数据
  /// 返回合并后的数据
  static UserWordProgress resolveProgressConflict(
    UserWordProgress local,
    UserWordProgress remote,
  ) {
    // 1. 比较记忆级别
    if (local.memoryLevel > remote.memoryLevel) {
      return local;
    } else if (remote.memoryLevel > local.memoryLevel) {
      return remote;
    }
    
    // 2. 记忆级别相同，比较复习次数
    if (local.reviewCount > remote.reviewCount) {
      return local;
    } else if (remote.reviewCount > local.reviewCount) {
      return remote;
    }
    
    // 3. 复习次数也相同，比较最后复习时间
    if (local.lastReviewAt != null && remote.lastReviewAt != null) {
      return local.lastReviewAt!.isAfter(remote.lastReviewAt!)
          ? local
          : remote;
    }
    
    // 如果一个有复习时间，一个没有，保留有复习时间的
    if (local.lastReviewAt != null && remote.lastReviewAt == null) {
      return local;
    }
    if (remote.lastReviewAt != null && local.lastReviewAt == null) {
      return remote;
    }
    
    // 4. 默认保留本地数据
    return local;
  }
  
  /// 合并学习统计数据
  /// 
  /// 策略: 取最大值
  /// - total_days: 取最大值
  /// - continuous_days: 取最大值
  /// - total_words_learned: 取最大值
  /// - total_words_mastered: 取最大值
  /// - last_learn_date: 取最新日期
  /// 
  /// [local] 本地统计数据
  /// [remote] 远程统计数据
  /// 返回合并后的统计数据
  static UserStatistics mergeStatistics(
    UserStatistics local,
    UserStatistics remote,
  ) {
    return UserStatistics(
      totalDays: max(local.totalDays, remote.totalDays),
      continuousDays: max(local.continuousDays, remote.continuousDays),
      totalWordsLearned: max(local.totalWordsLearned, remote.totalWordsLearned),
      totalWordsMastered: max(local.totalWordsMastered, remote.totalWordsMastered),
      lastLearnDate: _getLatestDate(local.lastLearnDate, remote.lastLearnDate),
      updatedAt: DateTime.now(),
    );
  }
  
  /// 获取最新日期
  /// 
  /// [date1] 日期1
  /// [date2] 日期2
  /// 返回较新的日期，如果一个为null则返回另一个
  static DateTime? _getLatestDate(DateTime? date1, DateTime? date2) {
    if (date1 == null) return date2;
    if (date2 == null) return date1;
    return date1.isAfter(date2) ? date1 : date2;
  }
}
