import '../database/local_database.dart';
import '../algorithms/review_priority_algorithm.dart';
import '../algorithms/memory_curve_algorithm.dart';
import '../models/word.dart';
import '../models/user_word_progress.dart';

/// 复习会话
/// 
/// 记录一次复习会话的状态和统计信息
class ReviewSession {
  final int listId;
  final ReviewMode mode;
  final DateTime startTime;
  final List<int> reviewWordIds; // 待复习的单词ID列表
  final List<int> rememberedWordIds; // 记得的单词ID列表
  final List<int> forgottenWordIds; // 忘记的单词ID列表
  int currentIndex; // 当前复习索引
  
  ReviewSession({
    required this.listId,
    required this.mode,
    required this.startTime,
    required this.reviewWordIds,
    List<int>? rememberedWordIds,
    List<int>? forgottenWordIds,
    this.currentIndex = 0,
  })  : rememberedWordIds = rememberedWordIds ?? [],
        forgottenWordIds = forgottenWordIds ?? [];
}

/// 复习统计
/// 
/// 复习会话结束时的统计信息
class ReviewStatistics {
  final int totalWordsReviewed;
  final int rememberedWordsCount;
  final int forgottenWordsCount;
  final Duration duration;
  
  ReviewStatistics({
    required this.totalWordsReviewed,
    required this.rememberedWordsCount,
    required this.forgottenWordsCount,
    required this.duration,
  });
}

/// 复习管理器
/// 
/// 负责复习会话的管理和复习进度的更新
/// 
/// 功能包括：
/// - 获取待复习单词数量
/// - 开始复习会话（支持记忆曲线和错题模式）
/// - 获取下一个复习单词
/// - 标记单词为记得
/// - 标记单词为忘记
/// - 结束复习会话并返回统计信息
/// - 计算下次复习时间
class ReviewManager {
  final LocalDatabase _localDatabase;
  
  ReviewSession? _currentSession;
  
  ReviewManager({
    required LocalDatabase localDatabase,
  }) : _localDatabase = localDatabase;
  
  // ==================== 获取待复习单词数量 ====================
  
  /// 获取待复习单词数量
  /// 
  /// [listId] 词表ID
  /// [mode] 复习模式（记忆曲线或错题）
  /// 
  /// 返回待复习的单词数量
  /// 
  /// 记忆曲线模式：返回到期需要复习的单词数量
  /// 错题模式：返回错误次数>0的单词数量
  Future<int> getDueReviewCount(int listId, {ReviewMode mode = ReviewMode.memoryCurve}) async {
    final dueWordIds = await ReviewPriorityAlgorithm.getDueReviewWords(
      _localDatabase,
      listId,
      mode,
    );
    return dueWordIds.length;
  }
  
  // ==================== 开始复习会话 ====================
  
  /// 开始复习会话
  /// 
  /// [listId] 词表ID
  /// [mode] 复习模式（记忆曲线或错题）
  /// 
  /// 返回复习会话对象
  /// 
  /// 抛出异常：
  /// - 已有进行中的复习会话
  /// - 词表不存在
  /// - 没有待复习的单词
  Future<ReviewSession> startReviewSession(
    int listId,
    ReviewMode mode,
  ) async {
    // 检查是否已有进行中的会话
    if (_currentSession != null) {
      throw Exception('已有进行中的复习会话，请先结束当前会话');
    }
    
    // 检查词表是否存在
    final list = await _localDatabase.getVocabularyList(listId);
    if (list == null) {
      throw Exception('词表不存在');
    }
    
    // 获取待复习的单词ID列表
    final dueWordIds = await ReviewPriorityAlgorithm.getDueReviewWords(
      _localDatabase,
      listId,
      mode,
    );
    
    if (dueWordIds.isEmpty) {
      throw Exception('没有待复习的单词');
    }
    
    // 创建复习会话
    _currentSession = ReviewSession(
      listId: listId,
      mode: mode,
      startTime: DateTime.now(),
      reviewWordIds: dueWordIds,
    );
    
    return _currentSession!;
  }
  
  // ==================== 获取下一个复习单词 ====================
  
  /// 获取下一个复习单词
  /// 
  /// [session] 复习会话对象
  /// 
  /// 返回下一个复习单词对象，如果没有更多单词则返回null
  /// 
  /// 抛出异常：
  /// - 会话无效
  /// - 数据库错误
  Future<Word?> getNextReviewWord(ReviewSession session) async {
    // 验证会话
    if (_currentSession == null || _currentSession != session) {
      throw Exception('无效的复习会话');
    }
    
    // 检查是否还有待复习的单词
    if (session.currentIndex >= session.reviewWordIds.length) {
      return null;
    }
    
    // 获取当前单词ID
    final wordId = session.reviewWordIds[session.currentIndex];
    
    // 获取单词详情
    final word = await _localDatabase.getWord(wordId);
    
    return word;
  }
  
  // ==================== 标记单词为记得 ====================
  
  /// 标记单词为记得
  /// 
  /// [wordId] 单词ID
  /// [listId] 词表ID
  /// 
  /// 记忆曲线模式：
  /// - 记忆级别+1（最大为5）
  /// - 如果达到最大级别，状态更新为"已掌握"
  /// - 否则保持"需复习"状态
  /// - 计算下次复习时间
  /// 
  /// 错题模式：
  /// - 从错题集移除（错误次数清零）
  /// - 状态更新为"已掌握"
  /// - 记忆级别设置为1
  /// - 计算下次复习时间
  /// 
  /// 抛出异常：
  /// - 数据库错误
  Future<void> markWordAsRemembered(int wordId, int listId) async {
    // 获取当前学习进度
    final existingProgress = await _localDatabase.getProgress(wordId, listId);
    
    if (existingProgress == null) {
      throw Exception('单词学习进度不存在');
    }
    
    final now = DateTime.now();
    final currentLevel = existingProgress.memoryLevel;
    
    // 计算下一个记忆级别
    final nextLevel = MemoryCurveAlgorithm.getNextMemoryLevel(currentLevel, true);
    
    // 计算下次复习时间
    final nextReviewTime = MemoryCurveAlgorithm.calculateNextReviewTime(currentLevel, true);
    
    // 判断是否达到最大级别
    final isMaxLevel = nextLevel >= MemoryCurveAlgorithm.MAX_MEMORY_LEVEL;
    
    // 如果是错题模式，清零错误次数
    final errorCount = _currentSession?.mode == ReviewMode.wrongWords 
        ? 0 
        : existingProgress.errorCount;
    
    final progress = UserWordProgress(
      id: existingProgress.id,
      wordId: wordId,
      vocabularyListId: listId,
      status: isMaxLevel ? LearningStatus.mastered : LearningStatus.needReview,
      learnedAt: existingProgress.learnedAt,
      lastReviewAt: now,
      nextReviewAt: nextReviewTime,
      reviewCount: existingProgress.reviewCount + 1,
      errorCount: errorCount,
      memoryLevel: nextLevel,
      syncStatus: 'pending',
    );
    
    await _localDatabase.insertOrUpdateProgress(progress);
    
    // 更新会话统计
    if (_currentSession != null) {
      if (!_currentSession!.rememberedWordIds.contains(wordId)) {
        _currentSession!.rememberedWordIds.add(wordId);
      }
      _currentSession!.currentIndex++;
    }
  }
  
  // ==================== 标记单词为忘记 ====================
  
  /// 标记单词为忘记
  /// 
  /// [wordId] 单词ID
  /// [listId] 词表ID
  /// 
  /// - 记忆级别重置为1
  /// - 状态更新为"需复习"
  /// - 错误次数+1
  /// - 计算下次复习时间（1天后）
  /// 
  /// 抛出异常：
  /// - 数据库错误
  Future<void> markWordAsForgotten(int wordId, int listId) async {
    // 获取当前学习进度
    final existingProgress = await _localDatabase.getProgress(wordId, listId);
    
    if (existingProgress == null) {
      throw Exception('单词学习进度不存在');
    }
    
    final now = DateTime.now();
    final currentLevel = existingProgress.memoryLevel;
    
    // 重置记忆级别为1
    final nextLevel = MemoryCurveAlgorithm.getNextMemoryLevel(currentLevel, false);
    
    // 计算下次复习时间（1天后）
    final nextReviewTime = MemoryCurveAlgorithm.calculateNextReviewTime(currentLevel, false);
    
    final progress = UserWordProgress(
      id: existingProgress.id,
      wordId: wordId,
      vocabularyListId: listId,
      status: LearningStatus.needReview,
      learnedAt: existingProgress.learnedAt,
      lastReviewAt: now,
      nextReviewAt: nextReviewTime,
      reviewCount: existingProgress.reviewCount + 1,
      errorCount: existingProgress.errorCount + 1,
      memoryLevel: nextLevel,
      syncStatus: 'pending',
    );
    
    await _localDatabase.insertOrUpdateProgress(progress);
    
    // 更新会话统计
    if (_currentSession != null) {
      if (!_currentSession!.forgottenWordIds.contains(wordId)) {
        _currentSession!.forgottenWordIds.add(wordId);
      }
      _currentSession!.currentIndex++;
    }
  }
  
  // ==================== 结束复习会话 ====================
  
  /// 结束复习会话
  /// 
  /// [session] 复习会话对象
  /// 
  /// 返回复习统计信息
  /// 
  /// 抛出异常：
  /// - 会话无效
  Future<ReviewStatistics> endReviewSession(ReviewSession session) async {
    // 验证会话
    if (_currentSession == null || _currentSession != session) {
      throw Exception('无效的复习会话');
    }
    
    // 计算复习时长
    final duration = DateTime.now().difference(session.startTime);
    
    // 创建统计信息
    final statistics = ReviewStatistics(
      totalWordsReviewed: session.rememberedWordIds.length + session.forgottenWordIds.length,
      rememberedWordsCount: session.rememberedWordIds.length,
      forgottenWordsCount: session.forgottenWordIds.length,
      duration: duration,
    );
    
    // 清除当前会话
    _currentSession = null;
    
    return statistics;
  }
  
  // ==================== 计算下次复习时间 ====================
  
  /// 计算下次复习时间
  /// 
  /// [memoryLevel] 记忆级别（1-5）
  /// 
  /// 返回下次复习的DateTime
  /// 
  /// 根据记忆级别计算：
  /// - 级别1: 1天后
  /// - 级别2: 2天后
  /// - 级别3: 4天后
  /// - 级别4: 7天后
  /// - 级别5: 15天后
  DateTime calculateNextReviewTime(int memoryLevel) {
    final intervalDays = MemoryCurveAlgorithm.REVIEW_INTERVALS[memoryLevel] ?? 1;
    return DateTime.now().add(Duration(days: intervalDays));
  }
  
  // ==================== 辅助方法 ====================
  
  /// 获取当前复习会话
  /// 
  /// 返回当前进行中的复习会话，如果没有则返回null
  ReviewSession? getCurrentSession() {
    return _currentSession;
  }
  
  /// 获取记忆曲线待复习单词数量
  /// 
  /// [listId] 词表ID
  /// 
  /// 返回到期需要复习的单词数量
  Future<int> getMemoryCurveDueCount(int listId) async {
    return await getDueReviewCount(listId, mode: ReviewMode.memoryCurve);
  }
  
  /// 获取错题数量
  /// 
  /// [listId] 词表ID
  /// 
  /// 返回错误次数>0的单词数量
  Future<int> getWrongWordsCount(int listId) async {
    return await getDueReviewCount(listId, mode: ReviewMode.wrongWords);
  }
  
  /// 获取复习进度
  /// 
  /// [session] 复习会话对象
  /// 
  /// 返回复习进度百分比（0.0-100.0）
  double getReviewProgress(ReviewSession session) {
    if (session.reviewWordIds.isEmpty) {
      return 100.0;
    }
    
    final reviewedCount = session.rememberedWordIds.length + session.forgottenWordIds.length;
    final totalCount = session.reviewWordIds.length;
    
    return (reviewedCount / totalCount * 100).clamp(0.0, 100.0);
  }
}
