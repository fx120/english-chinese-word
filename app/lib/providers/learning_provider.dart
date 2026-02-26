import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../managers/learning_manager.dart';
import '../models/word.dart';

/// 学习Provider
/// 
/// 封装LearningManager，提供状态管理和UI通知功能
/// 
/// 功能包括：
/// - 开始学习会话（随机/顺序模式）
/// - 获取下一个单词
/// - 标记单词为认识/不认识
/// - 结束学习会话
/// - 获取学习进度
/// - 会话状态管理
/// - 错误处理
class LearningProvider with ChangeNotifier {
  final LearningManager _learningManager;
  LearningSession? _currentSession;
  Word? _currentWord;
  bool _isLoading = false;
  String? _error;
  double _progress = 0.0;
  
  LearningProvider(LocalDatabase db) 
      : _learningManager = LearningManager(localDatabase: db);
  
  // ==================== Getters ====================
  
  /// 获取学习管理器
  LearningManager get learningManager => _learningManager;
  
  /// 获取当前学习会话
  LearningSession? get currentSession => _currentSession;
  
  /// 获取当前单词
  Word? get currentWord => _currentWord;
  
  /// 获取加载状态
  bool get isLoading => _isLoading;
  
  /// 获取错误信息
  String? get error => _error;
  
  /// 获取学习进度（0.0-100.0）
  double get progress => _progress;
  
  /// 检查是否有进行中的会话
  bool get hasActiveSession => _currentSession != null;
  
  // ==================== 开始学习会话 ====================
  
  /// 开始学习会话
  /// 
  /// [listId] 词表ID
  /// [mode] 学习模式（随机或顺序）
  /// 
  /// 成功时自动加载第一个单词
  Future<void> startLearningSession(int listId, LearningMode mode) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _currentSession = await _learningManager.startLearningSession(listId, mode);
      
      // 自动加载第一个单词
      await _loadNextWord();
      
      // 更新进度
      await _updateProgress();
    } catch (e) {
      _error = e.toString();
      _currentSession = null;
      _currentWord = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ==================== 获取下一个单词 ====================
  
  /// 加载下一个单词
  /// 
  /// 私有方法，由其他方法调用
  Future<void> _loadNextWord() async {
    if (_currentSession == null) {
      _currentWord = null;
      return;
    }
    
    try {
      _currentWord = await _learningManager.getNextWord(_currentSession!);
      await _updateProgress();
    } catch (e) {
      _error = e.toString();
      _currentWord = null;
    }
  }
  
  /// 手动加载下一个单词
  /// 
  /// 供UI调用，用于跳过当前单词
  Future<void> loadNextWord() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _loadNextWord();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ==================== 标记单词 ====================
  
  /// 标记单词为认识
  /// 
  /// [wordId] 单词ID
  /// [listId] 词表ID
  /// 
  /// 标记后自动加载下一个单词
  Future<void> markWordAsKnown(int wordId, int listId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _learningManager.markWordAsKnown(wordId, listId);
      
      // 自动加载下一个单词
      await _loadNextWord();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 标记单词为不认识
  /// 
  /// [wordId] 单词ID
  /// [listId] 词表ID
  /// 
  /// 标记后自动加载下一个单词
  Future<void> markWordAsUnknown(int wordId, int listId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _learningManager.markWordAsUnknown(wordId, listId);
      
      // 自动加载下一个单词
      await _loadNextWord();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ==================== 结束学习会话 ====================
  
  /// 结束学习会话
  /// 
  /// 返回学习统计信息
  Future<LearningStatistics?> endLearningSession() async {
    if (_currentSession == null) {
      _error = '没有进行中的学习会话';
      notifyListeners();
      return null;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final statistics = await _learningManager.endLearningSession(_currentSession!);
      
      // 清除会话状态
      _currentSession = null;
      _currentWord = null;
      _progress = 0.0;
      
      return statistics;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ==================== 进度管理 ====================
  
  /// 更新学习进度
  /// 
  /// 私有方法，在加载单词后自动调用
  Future<void> _updateProgress() async {
    if (_currentSession == null) {
      _progress = 0.0;
      return;
    }
    
    try {
      _progress = await _learningManager.getLearningProgress(_currentSession!.listId);
    } catch (e) {
      // 忽略进度更新错误
      _progress = 0.0;
    }
  }
  
  /// 获取指定词表的学习进度
  /// 
  /// [listId] 词表ID
  /// 
  /// 返回学习进度百分比（0.0-100.0）
  Future<double> getLearningProgress(int listId) async {
    try {
      return await _learningManager.getLearningProgress(listId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0.0;
    }
  }
  
  /// 获取未学习单词数量
  /// 
  /// [listId] 词表ID
  Future<int> getUnlearnedWordCount(int listId) async {
    try {
      return await _learningManager.getUnlearnedWordCount(listId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }
  
  /// 获取已掌握单词数量
  /// 
  /// [listId] 词表ID
  Future<int> getMasteredWordCount(int listId) async {
    try {
      return await _learningManager.getMasteredWordCount(listId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }
  
  /// 获取需复习单词数量
  /// 
  /// [listId] 词表ID
  Future<int> getNeedReviewWordCount(int listId) async {
    try {
      return await _learningManager.getNeedReviewWordCount(listId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }
  
  // ==================== 会话信息 ====================
  
  /// 获取当前会话的已学习单词数量
  int get learnedWordsCount => _currentSession?.learnedWordIds.length ?? 0;
  
  /// 获取当前会话的认识单词数量
  int get knownWordsCount => _currentSession?.knownWordIds.length ?? 0;
  
  /// 获取当前会话的不认识单词数量
  int get unknownWordsCount => _currentSession?.unknownWordIds.length ?? 0;
  
  /// 获取当前会话的学习模式
  LearningMode? get currentMode => _currentSession?.mode;
  
  /// 获取当前会话的词表ID
  int? get currentListId => _currentSession?.listId;
  
  // ==================== 清除错误 ====================
  
  /// 清除错误信息
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// 重置Provider状态
  /// 
  /// 清除所有会话和单词数据
  void reset() {
    _currentSession = null;
    _currentWord = null;
    _progress = 0.0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
