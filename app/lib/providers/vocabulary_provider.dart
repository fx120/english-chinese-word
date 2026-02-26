import 'dart:io';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../managers/vocabulary_manager.dart';
import '../models/vocabulary_list.dart';
import '../models/word.dart';
import '../services/api_client.dart';

/// 词表Provider
/// 
/// 封装VocabularyManager，提供状态管理和UI通知功能
/// 
/// 功能包括：
/// - 获取词表列表（在线和本地）
/// - 下载词表
/// - 导入词表（文本、Excel、OCR）
/// - 编辑词表
/// - 添加/删除/恢复单词
/// - 搜索单词
/// - 加载状态管理
/// - 下载进度管理
/// - 错误处理
class VocabularyProvider with ChangeNotifier {
  final VocabularyManager _vocabularyManager;
  List<VocabularyList> _vocabularyLists = [];
  List<VocabularyList> _onlineVocabularyLists = [];
  bool _isLoading = false;
  String? _error;
  double _downloadProgress = 0.0;
  
  VocabularyProvider(ApiClient apiClient, LocalDatabase db) 
      : _vocabularyManager = VocabularyManager(apiClient: apiClient, localDatabase: db);
  
  // ==================== Getters ====================
  
  /// 获取用户本地词表列表
  List<VocabularyList> get vocabularyLists => _vocabularyLists;
  
  /// 获取在线词表列表
  List<VocabularyList> get onlineVocabularyLists => _onlineVocabularyLists;
  
  /// 获取加载状态
  bool get isLoading => _isLoading;
  
  /// 获取错误信息
  String? get error => _error;
  
  /// 获取下载进度（0.0-1.0）
  double get downloadProgress => _downloadProgress;
  
  /// 获取VocabularyManager实例（供高级用法使用）
  VocabularyManager get vocabularyManager => _vocabularyManager;
  
  // ==================== 加载本地词表列表 ====================
  
  /// 加载用户本地词表列表
  /// 
  /// 从本地数据库加载所有词表（包括下载的和自定义的）
  Future<void> loadVocabularyLists() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _vocabularyLists = await _vocabularyManager.getUserVocabularyLists();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 按分类加载本地词表
  /// 
  /// [category] 分类名称
  Future<void> loadVocabularyListsByCategory(String category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _vocabularyLists = await _vocabularyManager.getUserVocabularyListsByCategory(category);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ==================== 加载在线词表列表 ====================
  
  /// 从API加载在线词表列表
  /// 
  /// [category] 分类筛选（可选）
  /// [page] 页码（可选）
  /// [limit] 每页数量（可选）
  Future<void> loadOnlineVocabularyLists({
    String? category,
    int? page,
    int? limit,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _onlineVocabularyLists = await _vocabularyManager.getVocabularyLists(
        category: category,
        page: page,
        limit: limit,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ==================== 下载词表 ====================
  
  /// 下载词表到本地
  /// 
  /// [listId] 服务器端词表ID
  /// 
  /// 下载完成后自动刷新本地词表列表
  Future<void> downloadVocabularyList(int listId) async {
    _isLoading = true;
    _error = null;
    _downloadProgress = 0.0;
    notifyListeners();
    
    try {
      await _vocabularyManager.downloadVocabularyList(
        listId,
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );
      
      // 下载完成后刷新本地词表列表
      await loadVocabularyLists();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _downloadProgress = 0.0;
      notifyListeners();
    }
  }
  
  // ==================== 导入词表 ====================
  
  /// 从文本文件导入词表
  /// 
  /// [file] 文本文件
  /// [name] 词表名称
  /// [description] 词表描述（可选）
  /// [category] 词表分类（可选）
  /// 
  /// 导入完成后自动刷新本地词表列表
  Future<VocabularyList?> importFromText(
    File file, {
    required String name,
    String? description,
    String? category,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final list = await _vocabularyManager.importFromText(
        file,
        name: name,
        description: description,
        category: category,
      );
      
      // 导入完成后刷新本地词表列表
      await loadVocabularyLists();
      
      return list;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 从Excel文件导入词表
  /// 
  /// [file] Excel文件
  /// [name] 词表名称
  /// [description] 词表描述（可选）
  /// [category] 词表分类（可选）
  /// 
  /// 导入完成后自动刷新本地词表列表
  Future<VocabularyList?> importFromExcel(
    File file, {
    required String name,
    String? description,
    String? category,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final list = await _vocabularyManager.importFromExcel(
        file,
        name: name,
        description: description,
        category: category,
      );
      
      // 导入完成后刷新本地词表列表
      await loadVocabularyLists();
      
      return list;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 从JSON文件导入词表
  /// 
  /// [file] JSON文件
  /// [name] 词表名称（可选，多bookId时自动命名）
  /// [description] 词表描述（可选）
  /// [category] 词表分类（可选）
  /// 
  /// 导入完成后自动刷新本地词表列表
  Future<List<VocabularyList>> importFromJson(
    File file, {
    String? name,
    String? description,
    String? category,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final lists = await _vocabularyManager.importFromJson(
        file,
        name: name,
        description: description,
        category: category,
      );
      
      await loadVocabularyLists();
      return lists;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 获取所有词表分类
  Future<List<String>> getAllCategories() async {
    try {
      return await _vocabularyManager.getAllCategories();
    } catch (e) {
      return [];
    }
  }
  
  // ==================== 编辑词表 ====================
  
  /// 更新词表信息
  /// 
  /// [list] 更新后的词表对象
  Future<void> updateVocabularyList(VocabularyList list) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _vocabularyManager.updateVocabularyList(list);
      
      // 更新完成后刷新本地词表列表
      await loadVocabularyLists();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 删除词表
  /// 
  /// [listId] 词表ID
  Future<void> deleteVocabularyList(int listId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _vocabularyManager.deleteVocabularyList(listId);
      
      // 删除完成后刷新本地词表列表
      await loadVocabularyLists();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ==================== 单词管理 ====================
  
  /// 添加单词到词表
  /// 
  /// [listId] 词表ID
  /// [word] 单词对象
  Future<void> addWordToList(int listId, Word word) async {
    _error = null;
    
    try {
      await _vocabularyManager.addWordToList(listId, word);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  /// 更新单词信息
  /// 
  /// [word] 更新后的单词对象
  Future<void> updateWord(Word word) async {
    _error = null;
    
    try {
      await _vocabularyManager.updateWord(word);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  /// 从词表中排除单词（软删除）
  /// 
  /// [listId] 词表ID
  /// [wordId] 单词ID
  Future<void> excludeWordFromList(int listId, int wordId) async {
    _error = null;
    
    try {
      await _vocabularyManager.excludeWordFromList(listId, wordId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  /// 恢复词表中已排除的单词
  /// 
  /// [listId] 词表ID
  /// [wordId] 单词ID
  Future<void> restoreWordToList(int listId, int wordId) async {
    _error = null;
    
    try {
      await _vocabularyManager.restoreWordToList(listId, wordId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  // ==================== 辅助方法 ====================
  
  /// 获取词表详情（包含单词列表）
  /// 
  /// [listId] 词表ID
  /// [includeExcluded] 是否包含已排除的单词
  Future<({VocabularyList list, List<Word> words})?> getVocabularyListDetail(
    int listId, {
    bool includeExcluded = false,
  }) async {
    try {
      return await _vocabularyManager.getVocabularyListDetail(
        listId,
        includeExcluded: includeExcluded,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
  
  /// 在词表中搜索单词
  /// 
  /// [listId] 词表ID
  /// [keyword] 搜索关键词
  /// [includeExcluded] 是否包含已排除的单词
  Future<List<Word>> searchWordsInList(
    int listId,
    String keyword, {
    bool includeExcluded = false,
  }) async {
    try {
      return await _vocabularyManager.searchWordsInList(
        listId,
        keyword,
        includeExcluded: includeExcluded,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }
  
  /// 获取已排除的单词列表
  /// 
  /// [listId] 词表ID
  Future<List<Word>> getExcludedWords(int listId) async {
    try {
      return await _vocabularyManager.getExcludedWords(listId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }
  
  // ==================== 清除错误 ====================
  
  /// 清除错误信息
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
