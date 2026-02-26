class MemoryCurveAlgorithm {
  // 记忆级别对应的复习间隔(天)
  // 达到级别3即为彻底掌握（3次会背后跳过）
  static const Map<int, int> REVIEW_INTERVALS = {
    0: 0,    // 未学习
    1: 1,    // 第一次复习: 1天后
    2: 3,    // 第二次复习: 3天后
    3: 7,    // 第三次复习: 7天后（达到此级别即掌握）
  };
  
  // 最大记忆级别（3次会背后彻底跳过）
  static const int MAX_MEMORY_LEVEL = 3;
  
  /// 计算下次复习时间
  /// [currentLevel] 当前记忆级别
  /// [remembered] 是否记得(true: 升级, false: 重置到级别1)
  /// 返回下次复习的DateTime
  static DateTime calculateNextReviewTime(int currentLevel, bool remembered) {
    int nextLevel;
    
    if (remembered) {
      // 记得: 升级到下一级别
      nextLevel = (currentLevel + 1).clamp(1, MAX_MEMORY_LEVEL);
    } else {
      // 忘记: 重置到第一级别
      nextLevel = 1;
    }
    
    int intervalDays = REVIEW_INTERVALS[nextLevel]!;
    return DateTime.now().add(Duration(days: intervalDays));
  }
  
  /// 获取下一个记忆级别
  static int getNextMemoryLevel(int currentLevel, bool remembered) {
    if (remembered) {
      return (currentLevel + 1).clamp(1, MAX_MEMORY_LEVEL);
    } else {
      return 1;
    }
  }
  
  /// 判断单词是否到期需要复习
  static bool isDueForReview(DateTime? nextReviewTime) {
    if (nextReviewTime == null) return false;
    return DateTime.now().isAfter(nextReviewTime) || 
           DateTime.now().isAtSameMomentAs(nextReviewTime);
  }
  
  /// 获取复习优先级(越小越优先)
  /// 基于过期时间计算，过期越久优先级越高
  static int getReviewPriority(DateTime nextReviewTime) {
    Duration overdue = DateTime.now().difference(nextReviewTime);
    return overdue.inHours; // 返回过期小时数
  }
}
