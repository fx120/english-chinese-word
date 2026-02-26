import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../managers/review_manager.dart';
import '../algorithms/review_priority_algorithm.dart'; // 导入ReviewMode
import '../models/word.dart';

/// 复习Provider
/// 
/// 封装ReviewManager，提供状态管理和UI通知功能
/// 
/// 功能包括：
/// - 获取待复习单词数量
/// - 开始复习会话（记忆曲线/错题模式）
/// - 获取下一个复习单词
/// - 标记单词为记得/忘记
/// - 结束复习会话
/// - 获取复习进度
/// - 会话状态管理
/// - 错误处理
class ReviewProvider with ChangeNotifier {
  final ReviewManager _reviewManager;
  ReviewSession? _currentSession;
  Word? _currentWord;
  bool _isLoading = false;
  String? _error;
  double _progress = 0.0;
  
  ReviewProvider(LocalDatabase db) 
      : _reviewManager = ReviewManager(localDatabase: db);
  
  // ==================== Getters ====================
  
  /// 获取复习管理器
  ReviewManager get reviewManager => _reviewManager;
  
  /// 获取当前复习会话
  ReviewSession? get currentSession => _currentSession;
  
  /// 获取当前单词
  Word? get currentWord => _currentWord;
  
  /// 获取加载状态
  bool get isLoading => _isLoading;
  
  /// 获取错误信息
  String? get error => _error;
  
  /// 获取复习进度（0.0-100.0）
  double get progress => _progress;
  
  /// 检查是否有进行中的会话
  bool get hasActiveSession => _currentSession != null;
  
  // ==================== 获取待复习单词数量 ====================
  
  /// 获取待复习单词数量
  /// 
  /// [listId] 词表ID
  /// [mode] 复习模式（记忆曲线或错题）
  Future<int> getDueReviewCount(int listId, {ReviewMode mode = ReviewMode.memoryCurve}) async {
    try {
      return await _reviewManager.getDueReviewCount(listId, mode: mode);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }
  
  /// 获取记忆曲线待复习单词数量
  /// 
  /// [listId] 词表ID
  Future<int> getMemoryCurveDueCount(int listId) async {
    try {
      return await _reviewManager.getMemoryCurveDueCount(listId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }
  
  /// 获取错题数量
  /// 
  /// [listId] 词表ID
  Future<int> getWrongWordsCount(int listId) async {
    try {
      return await _reviewManager.getWrongWordsCount(listId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }
  
  // ==================== 开始复习会话 ====================
  
  /// 开始复习会话
  /// 
  /// [listId] 词表ID
  /// [mode] 复习模式（记忆曲线或错题）
  /// 
  /// 成功时自动加载第一个单词
  Future<void> startReviewSession(int listId, ReviewMode mode) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _currentSession = await _reviewManager.startReviewSession(listId, mode);
      
      // 自动加载第一个单词
      await _loadNextWord();
      
      // 更新进度
      _updateProgress();
    } catch (e) {
      _error = e.toString();
      _currentSession = null;
      _currentWord = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ==================== 获取下一个复习单词 ====================
  
  /// 加载下一个复习单词
  /// 
  /// 私有方法，由其他方法调用
  Future<void> _loadNextWord() async {
    if (_currentSession == null) {
      _currentWord = null;
      return;
    }
    
    try {
      _currentWord = await _reviewManager.getNextReviewWord(_currentSession!);
      _updateProgress();
    } catch (e) {
      _error = e.toString();
      _currentWord = null;
    }
  }
  
  /// 手动加载下一个复习单词
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
  
  /// 标记单词为记得
  /// 
  /// [wordId] 单词ID
  /// [listId] 词表ID
  /// 
  /// 标记后自动加载下一个单词
  Future<void> markWordAsRemembered(int wordId, int listId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _reviewManager.markWordAsRemembered(wordId, listId);
      
      // 自动加载下一个单词
      await _loadNextWord();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 标记单词为忘记
  /// 
  /// [wordId] 单词ID
  /// [listId] 词表ID
  /// 
  /// 标记后自动加载下一个单词
  Future<void> markWordAsForgotten(int wordId, int listId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _reviewManager.markWordAsForgotten(wordId, listId);
      
      // 自动加载下一个单词
      await _loadNextWord();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ==================== 结束复习会话 ====================
  
  /// 结束复习会话
  /// 
  /// 返回复习统计信息
  Future<ReviewStatistics?> endReviewSession() async {
    if (_currentSession == null) {
      _error = '没有进行中的复习会话';
      notifyListeners();
      return null;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final statistics = await _reviewManager.endReviewSession(_currentSession!);
      
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
  
  /// 更新复习进度
  /// 
  /// 私有方法，在加载单词后自动调用
  void _updateProgress() {
    if (_currentSession == null) {
      _progress = 0.0;
      return;
    }
    
    _progress = _reviewManager.getReviewProgress(_currentSession!);
  }
  
  // ==================== 会话信息 ====================
  
  /// 获取当前会话的已复习单词数量
  int get reviewedWordsCount => 
      (_currentSession?.rememberedWordIds.length ?? 0) + 
      (_currentSession?.forgottenWordIds.length ?? 0);
  
  /// 获取当前会话的记得单词数量
  int get rememberedWordsCount => _currentSession?.rememberedWordIds.length ?? 0;
  
  /// 获取当前会话的忘记单词数量
  int get forgottenWordsCount => _currentSession?.forgottenWordIds.length ?? 0;
  
  /// 获取当前会话的待复习单词总数
  int get totalReviewWordsCount => _currentSession?.reviewWordIds.length ?? 0;
  
  /// 获取当前会话的复习模式
  ReviewMode? get currentMode => _currentSession?.mode;
  
  /// 获取当前会话的词表ID
  int? get currentListId => _currentSession?.listId;
  
  /// 获取当前会话的开始时间
  DateTime? get sessionStartTime => _currentSession?.startTime;
  
  // ==================== 辅助方法 ====================
  
  /// 计算下次复习时间
  /// 
  /// [memoryLevel] 记忆级别（1-5）
  DateTime calculateNextReviewTime(int memoryLevel) {
    return _reviewManager.calculateNextReviewTime(memoryLevel);
  }
  
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
