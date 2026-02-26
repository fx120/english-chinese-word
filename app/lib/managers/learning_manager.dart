import '../database/local_database.dart';
import '../algorithms/random_learning_algorithm.dart';
import '../algorithms/sequential_learning_algorithm.dart';
import '../algorithms/memory_curve_algorithm.dart';
import '../models/word.dart';
import '../models/user_word_progress.dart';

/// 学习模式枚举
enum LearningMode {
  random,      // 随机学习模式
  sequential,  // 顺序学习模式
}

/// 学习会话
/// 
/// 记录一次学习会话的状态和统计信息
class LearningSession {
  final int listId;
  final LearningMode mode;
  final DateTime startTime;
  final List<int> learnedWordIds;
  final List<int> knownWordIds;
  final List<int> unknownWordIds;
  int currentIndex; // 用于顺序学习模式
  
  LearningSession({
    required this.listId,
    required this.mode,
    required this.startTime,
    List<int>? learnedWordIds,
    List<int>? knownWordIds,
    List<int>? unknownWordIds,
    this.currentIndex = 0,
  })  : learnedWordIds = learnedWordIds ?? [],
        knownWordIds = knownWordIds ?? [],
        unknownWordIds = unknownWordIds ?? [];
}

/// 学习统计
/// 
/// 学习会话结束时的统计信息
class LearningStatistics {
  final int totalWordsLearned;
  final int knownWordsCount;
  final int unknownWordsCount;
  final Duration duration;
  
  LearningStatistics({
    required this.totalWordsLearned,
    required this.knownWordsCount,
    required this.unknownWordsCount,
    required this.duration,
  });
}

/// 学习管理器
/// 
/// 负责学习会话的管理和学习进度的更新
/// 
/// 功能包括：
/// - 开始学习会话（支持随机和顺序模式）
/// - 获取下一个单词
/// - 标记单词为认识
/// - 标记单词为不认识
/// - 结束学习会话并返回统计信息
/// - 集成记忆曲线算法
class LearningManager {
  final LocalDatabase _localDatabase;
  
  LearningSession? _currentSession;
  
  LearningManager({
    required LocalDatabase localDatabase,
  }) : _localDatabase = localDatabase;
  
  // ==================== 开始学习会话 ====================
  
  /// 开始学习会话
  /// 
  /// [listId] 词表ID
  /// [mode] 学习模式（随机或顺序）
  /// 
  /// 返回学习会话对象
  /// 
  /// 抛出异常：
  /// - 已有进行中的学习会话
  /// - 词表不存在
  /// - 没有可学习的单词
  Future<LearningSession> startLearningSession(
    int listId,
    LearningMode mode,
  ) async {
    // 检查是否已有进行中的会话
    if (_currentSession != null) {
      throw Exception('已有进行中的学习会话，请先结束当前会话');
    }
    
    // 检查词表是否存在
    final list = await _localDatabase.getVocabularyList(listId);
    if (list == null) {
      throw Exception('词表不存在');
    }
    
    // 获取未学习的单词数量
    final unlearnedIds = await _localDatabase.getUnlearnedWordIds(listId);
    if (unlearnedIds.isEmpty) {
      throw Exception('没有可学习的单词');
    }
    
    // 创建学习会话
    _currentSession = LearningSession(
      listId: listId,
      mode: mode,
      startTime: DateTime.now(),
    );
    
    return _currentSession!;
  }
  
  // ==================== 获取下一个单词 ====================
  
  /// 获取下一个单词
  /// 
  /// [session] 学习会话对象
  /// 
  /// 返回下一个单词对象，如果没有更多单词则返回null
  /// 
  /// 抛出异常：
  /// - 会话无效
  /// - 数据库错误
  Future<Word?> getNextWord(LearningSession session) async {
    // 验证会话
    if (_currentSession == null || _currentSession != session) {
      throw Exception('无效的学习会话');
    }
    
    // 获取已排除的单词ID列表
    final excludedIds = await _localDatabase.getExcludedWordIds(session.listId);
    
    // 获取已学习的单词ID列表（本次会话中）
    final learnedIds = session.learnedWordIds;
    
    int? wordId;
    
    if (session.mode == LearningMode.random) {
      // 随机学习模式
      wordId = await RandomLearningAlgorithm.getRandomUnlearnedWord(
        _localDatabase,
        session.listId,
        excludedIds,
        learnedIds,
      );
    } else {
      // 顺序学习模式
      final result = await SequentialLearningAlgorithm.getNextSequentialWord(
        _localDatabase,
        session.listId,
        excludedIds,
        session.currentIndex,
      );
      
      wordId = result.wordId;
      session.currentIndex = result.nextIndex;
    }
    
    // 如果没有更多单词，返回null
    if (wordId == null) {
      return null;
    }
    
    // 获取单词详情
    final word = await _localDatabase.getWord(wordId);
    return word;
  }
  
  // ==================== 标记单词为认识 ====================
  
  /// 标记单词为认识
  /// 
  /// [wordId] 单词ID
  /// [listId] 词表ID
  /// 
  /// 将单词状态更新为"已掌握"，并设置记忆级别为1，
  /// 计算下次复习时间（1天后）
  /// 
  /// 抛出异常：
  /// - 数据库错误
  Future<void> markWordAsKnown(int wordId, int listId) async {
    // 检查是否已有学习进度
    final existingProgress = await _localDatabase.getProgress(wordId, listId);
    
    final now = DateTime.now();
    const memoryLevel = 1;
    final nextReviewTime = MemoryCurveAlgorithm.calculateNextReviewTime(0, true);
    
    final progress = UserWordProgress(
      id: existingProgress?.id ?? 0,
      wordId: wordId,
      vocabularyListId: listId,
      status: LearningStatus.mastered,
      learnedAt: existingProgress?.learnedAt ?? now,
      lastReviewAt: now,
      nextReviewAt: nextReviewTime,
      reviewCount: (existingProgress?.reviewCount ?? 0) + 1,
      errorCount: existingProgress?.errorCount ?? 0,
      memoryLevel: memoryLevel,
      syncStatus: 'pending',
    );
    
    await _localDatabase.insertOrUpdateProgress(progress);
    
    // 更新会话统计
    if (_currentSession != null) {
      if (!_currentSession!.learnedWordIds.contains(wordId)) {
        _currentSession!.learnedWordIds.add(wordId);
      }
      if (!_currentSession!.knownWordIds.contains(wordId)) {
        _currentSession!.knownWordIds.add(wordId);
      }
    }
  }
  
  // ==================== 标记单词为不认识 ====================
  
  /// 标记单词为不认识
  /// 
  /// [wordId] 单词ID
  /// [listId] 词表ID
  /// 
  /// 将单词状态更新为"需复习"，增加错误计数，
  /// 设置记忆级别为1，计算下次复习时间（1天后）
  /// 
  /// 抛出异常：
  /// - 数据库错误
  Future<void> markWordAsUnknown(int wordId, int listId) async {
    // 检查是否已有学习进度
    final existingProgress = await _localDatabase.getProgress(wordId, listId);
    
    final now = DateTime.now();
    const memoryLevel = 1;
    final nextReviewTime = MemoryCurveAlgorithm.calculateNextReviewTime(0, false);
    
    final progress = UserWordProgress(
      id: existingProgress?.id ?? 0,
      wordId: wordId,
      vocabularyListId: listId,
      status: LearningStatus.needReview,
      learnedAt: existingProgress?.learnedAt ?? now,
      lastReviewAt: now,
      nextReviewAt: nextReviewTime,
      reviewCount: (existingProgress?.reviewCount ?? 0) + 1,
      errorCount: (existingProgress?.errorCount ?? 0) + 1,
      memoryLevel: memoryLevel,
      syncStatus: 'pending',
    );
    
    await _localDatabase.insertOrUpdateProgress(progress);
    
    // 更新会话统计
    if (_currentSession != null) {
      if (!_currentSession!.learnedWordIds.contains(wordId)) {
        _currentSession!.learnedWordIds.add(wordId);
      }
      if (!_currentSession!.unknownWordIds.contains(wordId)) {
        _currentSession!.unknownWordIds.add(wordId);
      }
    }
  }
  
  // ==================== 结束学习会话 ====================
  
  /// 结束学习会话
  /// 
  /// [session] 学习会话对象
  /// 
  /// 返回学习统计信息
  /// 
  /// 抛出异常：
  /// - 会话无效
  Future<LearningStatistics> endLearningSession(LearningSession session) async {
    // 验证会话
    if (_currentSession == null || _currentSession != session) {
      throw Exception('无效的学习会话');
    }
    
    // 计算学习时长
    final duration = DateTime.now().difference(session.startTime);
    
    // 创建统计信息
    final statistics = LearningStatistics(
      totalWordsLearned: session.learnedWordIds.length,
      knownWordsCount: session.knownWordIds.length,
      unknownWordsCount: session.unknownWordIds.length,
      duration: duration,
    );
    
    // 清除当前会话
    _currentSession = null;
    
    return statistics;
  }
  
  // ==================== 辅助方法 ====================
  
  /// 获取当前学习会话
  /// 
  /// 返回当前进行中的学习会话，如果没有则返回null
  LearningSession? getCurrentSession() {
    return _currentSession;
  }
  
  /// 获取学习进度
  /// 
  /// [listId] 词表ID
  /// 
  /// 返回学习进度百分比（0.0-100.0）
  Future<double> getLearningProgress(int listId) async {
    // 获取词表所有单词（不包括排除的）
    final allWords = await _localDatabase.getWordsByListId(listId);
    final totalCount = allWords.length;
    
    if (totalCount == 0) {
      return 0.0;
    }
    
    // 获取已学习的单词数量
    final progressList = await _localDatabase.getProgressByListId(listId);
    final learnedCount = progressList.where((p) {
      return p.status == LearningStatus.mastered || 
             p.status == LearningStatus.needReview;
    }).length;
    
    return SequentialLearningAlgorithm.calculateProgress(learnedCount, totalCount);
  }
  
  /// 获取未学习单词数量
  /// 
  /// [listId] 词表ID
  /// 
  /// 返回未学习的单词数量
  Future<int> getUnlearnedWordCount(int listId) async {
    final unlearnedIds = await _localDatabase.getUnlearnedWordIds(listId);
    return unlearnedIds.length;
  }
  
  /// 获取已掌握单词数量
  /// 
  /// [listId] 词表ID
  /// 
  /// 返回已掌握的单词数量
  Future<int> getMasteredWordCount(int listId) async {
    final progressList = await _localDatabase.getProgressByListId(listId);
    return progressList.where((p) => p.status == LearningStatus.mastered).length;
  }
  
  /// 获取需复习单词数量
  /// 
  /// [listId] 词表ID
  /// 
  /// 返回需复习的单词数量
  Future<int> getNeedReviewWordCount(int listId) async {
    final progressList = await _localDatabase.getProgressByListId(listId);
    return progressList.where((p) => p.status == LearningStatus.needReview).length;
  }
}
