import 'dart:io';
import '../services/api_client.dart';
import '../database/local_database.dart';
import '../algorithms/text_parser.dart';
import '../algorithms/excel_parser.dart';
import '../algorithms/json_vocabulary_parser.dart';
import '../models/vocabulary_list.dart';
import '../models/word.dart';
import '../models/user_word_exclusion.dart';

/// 词表管理器
/// 负责词表的获取、下载、导入、编辑等操作
/// 
/// 功能包括：
/// - 从API获取词表列表
/// - 下载词表到本地
/// - 导入文本文件词表
/// - 导入Excel文件词表
/// - 导入OCR图片词表（预留接口）
/// - 获取用户本地词表
/// - 编辑词表
/// - 添加单词到词表
/// - 软删除单词（排除）
/// - 恢复已删除单词
class VocabularyManager {
  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;
  
  VocabularyManager({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  })  : _apiClient = apiClient,
        _localDatabase = localDatabase;
  
  // ==================== 获取词表列表 ====================
  
  /// 从API获取词表列表
  /// 
  /// [category] 分类筛选（可选）
  /// [page] 页码（可选）
  /// [limit] 每页数量（可选）
  /// 返回词表列表
  /// 
  /// 抛出异常：
  /// - 网络错误
  /// - API错误
  Future<List<VocabularyList>> getVocabularyLists({
    String? category,
    int? page,
    int? limit,
  }) async {
    try {
      final response = await _apiClient.getVocabularyLists(
        category: category,
        page: page,
        limit: limit,
      );
      
      final data = response.data['data'];
      final items = data['items'] as List;
      
      return items.map((item) {
        return VocabularyList(
          id: 0, // 本地ID暂时为0，下载后会分配
          serverId: item['id'] as int,
          name: item['name'] as String,
          description: item['description'] as String?,
          category: item['category'] as String?,
          difficultyLevel: item['difficulty_level'] as int? ?? 1,
          wordCount: item['word_count'] as int? ?? 0,
          isOfficial: item['is_official'] == true || item['is_official'] == 1,
          isCustom: false,
          createdAt: item['created_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  (item['created_at'] as int) * 1000,
                )
              : DateTime.now(),
          syncStatus: 'synced',
        );
      }).toList();
    } catch (e) {
      throw Exception('获取词表列表失败: ${e.toString()}');
    }
  }
  
  // ==================== 下载词表 ====================
  
  /// 下载词表到本地
  /// 
  /// [listId] 服务器端词表ID
  /// [onProgress] 下载进度回调（0.0-1.0）
  /// 
  /// 下载流程：
  /// 1. 从API获取词表详情和单词数据
  /// 2. 保存词表定义到本地数据库
  /// 3. 保存单词到本地数据库（复用已存在的单词）
  /// 4. 建立词表与单词的关联关系
  /// 
  /// 抛出异常：
  /// - 网络错误
  /// - API错误
  /// - 数据库错误
  /// - 词表已下载错误
  Future<void> downloadVocabularyList(
    int listId, {
    Function(double)? onProgress,
  }) async {
    try {
      // 检查是否已下载
      final existingLists = await _localDatabase.getAllVocabularyLists();
      final existingList = existingLists.where((list) => list.serverId == listId).toList();
      
      if (existingList.isNotEmpty) {
        // 本地已有词表记录，删除旧数据后重新下载
        for (final old in existingList) {
          await _localDatabase.deleteVocabularyList(old.id);
        }
      }
      
      // 报告进度：开始下载
      onProgress?.call(0.1);
      
      // 从API下载词表
      final response = await _apiClient.downloadVocabularyList(listId);
      final data = response.data['data'];
      
      // 报告进度：下载完成
      onProgress?.call(0.3);
      
      // 解析词表信息
      final vocabularyListData = data['vocabulary_list'];
      final wordsData = data['words'] as List;
      
      // 创建词表对象
      final vocabularyList = VocabularyList(
        id: 0, // 自动分配
        serverId: vocabularyListData['id'] as int,
        name: vocabularyListData['name'] as String,
        description: vocabularyListData['description'] as String?,
        category: vocabularyListData['category'] as String?,
        difficultyLevel: vocabularyListData['difficulty_level'] as int? ?? 1,
        wordCount: wordsData.length,
        isOfficial: vocabularyListData['is_official'] == true || 
                    vocabularyListData['is_official'] == 1,
        isCustom: false,
        createdAt: vocabularyListData['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (vocabularyListData['created_at'] as int) * 1000,
              )
            : DateTime.now(),
        syncStatus: 'synced',
      );
      
      // 保存词表到本地数据库
      final localListId = await _localDatabase.insertVocabularyList(vocabularyList);
      
      // 报告进度：词表已保存
      onProgress?.call(0.4);
      
      // 解析单词数据
      final words = wordsData.map((wordData) {
        return Word(
          id: 0, // 自动分配
          serverId: wordData['id'] as int,
          word: wordData['word'] as String,
          phonetic: wordData['phonetic'] as String?,
          partOfSpeech: wordData['part_of_speech'] as String?,
          definition: wordData['definition'] as String,
          example: wordData['example'] as String?,
          createdAt: wordData['created_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  (wordData['created_at'] as int) * 1000,
                )
              : DateTime.now(),
        );
      }).toList();
      
      // 批量保存单词到本地数据库
      // 这个方法会自动处理单词复用（如果单词已存在则不重复插入）
      await _localDatabase.batchInsertWordsToList(words, localListId);
      
      // 报告进度：完成
      onProgress?.call(1.0);
    } catch (e) {
      throw Exception('下载词表失败: ${e.toString()}');
    }
  }
  
  // ==================== 导入文本文件 ====================
  
  /// 从文本文件导入词表
  /// 
  /// [file] 文本文件
  /// [name] 词表名称
  /// [description] 词表描述（可选）
  /// [category] 词表分类（可选，默认为"custom"）
  /// 
  /// 返回创建的词表对象
  /// 
  /// 抛出异常：
  /// - 文件读取错误
  /// - 解析错误
  /// - 数据库错误
  Future<VocabularyList> importFromText(
    File file, {
    required String name,
    String? description,
    String? category,
  }) async {
    try {
      // 读取文件内容
      final content = await file.readAsString();
      
      // 解析文本文件
      final parseResult = TextParser.parseTextFileWithDetails(content);
      
      if (parseResult.words.isEmpty) {
        if (parseResult.hasErrors) {
          throw Exception('解析失败:\n${parseResult.errors.join('\n')}');
        } else {
          throw Exception('文件中没有有效的单词数据');
        }
      }
      
      // 创建词表
      final vocabularyList = VocabularyList(
        id: 0, // 自动分配
        serverId: null,
        name: name,
        description: description,
        category: category ?? 'custom',
        difficultyLevel: 1,
        wordCount: parseResult.words.length,
        isOfficial: false,
        isCustom: true,
        createdAt: DateTime.now(),
        syncStatus: 'pending',
      );
      
      // 保存词表到本地数据库
      final localListId = await _localDatabase.insertVocabularyList(vocabularyList);
      
      // 批量保存单词到本地数据库
      await _localDatabase.batchInsertWordsToList(parseResult.words, localListId);
      
      // 返回创建的词表（带有正确的ID）
      final createdList = await _localDatabase.getVocabularyList(localListId);
      if (createdList == null) {
        throw Exception('创建词表失败');
      }
      
      return createdList;
    } catch (e) {
      throw Exception('导入文本文件失败: ${e.toString()}');
    }
  }
  
  // ==================== 导入Excel文件 ====================
  
  /// 从Excel文件导入词表
  /// 
  /// [file] Excel文件（.xlsx或.xls）
  /// [name] 词表名称
  /// [description] 词表描述（可选）
  /// [category] 词表分类（可选，默认为"custom"）
  /// 
  /// 返回创建的词表对象
  /// 
  /// 抛出异常：
  /// - 文件格式错误
  /// - 解析错误
  /// - 数据库错误
  Future<VocabularyList> importFromExcel(
    File file, {
    required String name,
    String? description,
    String? category,
  }) async {
    try {
      // 检查文件格式
      if (!ExcelParser.isSupportedExcelFile(file.path)) {
        throw Exception('不支持的文件格式，请使用.xlsx或.xls文件');
      }
      
      // 解析Excel文件
      final parseResult = await ExcelParser.parseExcelFileWithDetails(file.path);
      
      if (parseResult.words.isEmpty) {
        if (parseResult.hasErrors) {
          throw Exception('解析失败:\n${parseResult.errors.join('\n')}');
        } else {
          throw Exception('文件中没有有效的单词数据');
        }
      }
      
      // 创建词表
      final vocabularyList = VocabularyList(
        id: 0, // 自动分配
        serverId: null,
        name: name,
        description: description,
        category: category ?? 'custom',
        difficultyLevel: 1,
        wordCount: parseResult.words.length,
        isOfficial: false,
        isCustom: true,
        createdAt: DateTime.now(),
        syncStatus: 'pending',
      );
      
      // 保存词表到本地数据库
      final localListId = await _localDatabase.insertVocabularyList(vocabularyList);
      
      // 批量保存单词到本地数据库
      await _localDatabase.batchInsertWordsToList(parseResult.words, localListId);
      
      // 返回创建的词表（带有正确的ID）
      final createdList = await _localDatabase.getVocabularyList(localListId);
      if (createdList == null) {
        throw Exception('创建词表失败');
      }
      
      return createdList;
    } catch (e) {
      throw Exception('导入Excel文件失败: ${e.toString()}');
    }
  }
  
  // ==================== 导入JSON词表 ====================
  
  /// 从JSON文件导入词表
  /// 
  /// 支持网络获取的词表JSON格式，每行一个JSON对象
  /// 自动按bookId分组创建多个词表
  /// 
  /// [file] JSON文件
  /// [name] 词表名称（当只有一个bookId时使用，多个时自动命名）
  /// [description] 词表描述（可选）
  /// [category] 词表分类（可选）
  /// 
  /// 返回创建的词表列表
  Future<List<VocabularyList>> importFromJson(
    File file, {
    String? name,
    String? description,
    String? category,
  }) async {
    try {
      final content = await file.readAsString();
      final parseResult = JsonVocabularyParser.parseJsonContent(content);
      
      if (!parseResult.isSuccess) {
        if (parseResult.hasErrors) {
          throw Exception('解析失败:\n${parseResult.errors.take(5).join('\n')}');
        } else {
          throw Exception('文件中没有有效的单词数据');
        }
      }
      
      final createdLists = <VocabularyList>[];
      
      // 按bookId分组导入
      for (final entry in parseResult.groupedByBook.entries) {
        final bookId = entry.key;
        final wordEntries = entry.value;
        final words = JsonVocabularyParser.toWordList(wordEntries);
        
        // 确定词表名称
        String listName;
        if (parseResult.bookCount == 1 && name != null && name.isNotEmpty) {
          listName = name;
        } else {
          listName = name != null && name.isNotEmpty
              ? '$name - ${JsonVocabularyParser.bookIdToName(bookId)}'
              : JsonVocabularyParser.bookIdToName(bookId);
        }
        
        final vocabularyList = VocabularyList(
          id: 0,
          serverId: null,
          name: listName,
          description: description ?? '从JSON文件导入 (${wordEntries.length}词)',
          category: category ?? 'custom',
          difficultyLevel: 1,
          wordCount: words.length,
          isOfficial: false,
          isCustom: true,
          createdAt: DateTime.now(),
          syncStatus: 'pending',
        );
        
        final localListId = await _localDatabase.insertVocabularyList(vocabularyList);
        await _localDatabase.batchInsertWordsToList(words, localListId);
        
        final createdList = await _localDatabase.getVocabularyList(localListId);
        if (createdList != null) {
          createdLists.add(createdList);
        }
      }
      
      if (createdLists.isEmpty) {
        throw Exception('创建词表失败');
      }
      
      return createdLists;
    } catch (e) {
      throw Exception('导入JSON文件失败: ${e.toString()}');
    }
  }
  
  // ==================== 获取所有分类 ====================
  
  /// 获取本地词表的所有分类
  /// 
  /// 返回去重后的分类列表
  Future<List<String>> getAllCategories() async {
    try {
      final lists = await _localDatabase.getAllVocabularyLists();
      final categories = <String>{};
      for (final list in lists) {
        if (list.category != null && list.category!.isNotEmpty) {
          categories.add(list.category!);
        }
      }
      return categories.toList()..sort();
    } catch (e) {
      throw Exception('获取分类失败: ${e.toString()}');
    }
  }
  
  // ==================== 导入OCR图片（预留接口） ====================
  
  /// 从OCR图片导入单词（预留接口）
  /// 
  /// [image] 图片文件
  /// 返回识别的单词列表
  /// 
  /// 注意：此功能需要集成OCR服务，当前仅为预留接口
  /// 
  /// 抛出异常：
  /// - 功能未实现
  Future<List<Word>> importFromOCR(File image) async {
    // TODO: 集成OCR服务
    // 1. 调用OCR服务识别图片中的文字
    // 2. 解析识别结果为单词列表
    // 3. 返回单词列表供用户确认和编辑
    
    throw UnimplementedError('OCR导入功能尚未实现，请等待后续版本');
  }
  
  // ==================== 获取用户词表 ====================
  
  /// 获取用户的所有词表（从本地数据库）
  /// 
  /// 返回词表列表，包括下载的官方词表和自定义词表
  Future<List<VocabularyList>> getUserVocabularyLists() async {
    try {
      return await _localDatabase.getAllVocabularyLists();
    } catch (e) {
      throw Exception('获取用户词表失败: ${e.toString()}');
    }
  }
  
  /// 根据分类获取用户词表
  /// 
  /// [category] 分类名称
  /// 返回指定分类的词表列表
  Future<List<VocabularyList>> getUserVocabularyListsByCategory(String category) async {
    try {
      return await _localDatabase.getVocabularyListsByCategory(category);
    } catch (e) {
      throw Exception('获取用户词表失败: ${e.toString()}');
    }
  }
  
  /// 获取词表详情（包含单词列表）
  /// 
  /// [listId] 本地词表ID
  /// [includeExcluded] 是否包含已排除的单词（默认false）
  /// 返回词表对象和单词列表
  Future<({VocabularyList list, List<Word> words})> getVocabularyListDetail(
    int listId, {
    bool includeExcluded = false,
  }) async {
    try {
      final list = await _localDatabase.getVocabularyList(listId);
      if (list == null) {
        throw Exception('词表不存在');
      }
      
      final words = await _localDatabase.getWordsByListId(
        listId,
        includeExcluded: includeExcluded,
      );
      
      return (list: list, words: words);
    } catch (e) {
      throw Exception('获取词表详情失败: ${e.toString()}');
    }
  }
  
  // ==================== 编辑词表 ====================
  
  /// 更新词表信息
  /// 
  /// [list] 更新后的词表对象
  /// 
  /// 抛出异常：
  /// - 数据库错误
  Future<void> updateVocabularyList(VocabularyList list) async {
    try {
      // 更新词表
      final updatedList = VocabularyList(
        id: list.id,
        serverId: list.serverId,
        name: list.name,
        description: list.description,
        category: list.category,
        difficultyLevel: list.difficultyLevel,
        wordCount: list.wordCount,
        isOfficial: list.isOfficial,
        isCustom: list.isCustom,
        createdAt: list.createdAt,
        updatedAt: DateTime.now(),
        syncStatus: 'pending', // 标记为待同步
      );
      
      await _localDatabase.updateVocabularyList(updatedList);
    } catch (e) {
      throw Exception('更新词表失败: ${e.toString()}');
    }
  }
  
  // ==================== 更新单词 ====================
  
  /// 更新单词信息
  /// 
  /// [word] 更新后的单词对象
  /// 
  /// 注意：此操作会更新全局单词数据，影响所有引用该单词的词表
  /// 
  /// 抛出异常：
  /// - 数据库错误
  Future<void> updateWord(Word word) async {
    try {
      await _localDatabase.updateWord(word);
    } catch (e) {
      throw Exception('更新单词失败: ${e.toString()}');
    }
  }
  
  // ==================== 添加单词到词表 ====================
  
  /// 添加单词到词表
  /// 
  /// [listId] 词表ID
  /// [word] 单词对象
  /// 
  /// 如果单词已存在于全局单词表，则复用；否则创建新单词
  /// 
  /// 抛出异常：
  /// - 数据库错误
  /// - 单词已存在于词表
  Future<void> addWordToList(int listId, Word word) async {
    try {
      // 检查单词是否已存在于全局单词表
      final existingWord = await _localDatabase.getWordByText(word.word);
      
      int wordId;
      if (existingWord != null) {
        // 复用已存在的单词
        wordId = existingWord.id;
      } else {
        // 创建新单词
        wordId = await _localDatabase.insertWord(word);
        if (wordId == 0) {
          throw Exception('添加单词失败');
        }
      }
      
      // 添加单词到词表
      await _localDatabase.addWordToList(wordId, listId);
      
      // 更新词表的同步状态
      final list = await _localDatabase.getVocabularyList(listId);
      if (list != null) {
        await updateVocabularyList(list);
      }
    } catch (e) {
      throw Exception('添加单词到词表失败: ${e.toString()}');
    }
  }
  
  /// 批量添加单词到词表
  /// 
  /// [listId] 词表ID
  /// [words] 单词列表
  /// 
  /// 抛出异常：
  /// - 数据库错误
  Future<void> addWordsToList(int listId, List<Word> words) async {
    try {
      await _localDatabase.batchInsertWordsToList(words, listId);
      
      // 更新词表的同步状态
      final list = await _localDatabase.getVocabularyList(listId);
      if (list != null) {
        await updateVocabularyList(list);
      }
    } catch (e) {
      throw Exception('批量添加单词失败: ${e.toString()}');
    }
  }
  
  // ==================== 软删除单词（排除） ====================
  
  /// 从词表中排除单词（软删除）
  /// 
  /// [listId] 词表ID
  /// [wordId] 单词ID
  /// 
  /// 软删除不会删除全局单词数据，只是在用户维度标记为排除
  /// 被排除的单词在该词表中不可见，但在其他词表中仍然可见
  /// 
  /// 抛出异常：
  /// - 数据库错误
  Future<void> excludeWordFromList(int listId, int wordId) async {
    try {
      // 检查是否已排除
      final isExcluded = await _localDatabase.isWordExcluded(wordId, listId);
      if (isExcluded) {
        throw Exception('单词已被排除');
      }
      
      // 创建排除记录
      final exclusion = UserWordExclusion(
        id: 0, // 自动分配
        wordId: wordId,
        vocabularyListId: listId,
        excludedAt: DateTime.now(),
        syncStatus: 'pending',
      );
      
      await _localDatabase.insertExclusion(exclusion);
      
      // 更新词表的同步状态
      final list = await _localDatabase.getVocabularyList(listId);
      if (list != null) {
        await updateVocabularyList(list);
      }
    } catch (e) {
      throw Exception('排除单词失败: ${e.toString()}');
    }
  }
  
  // ==================== 恢复已删除单词 ====================
  
  /// 恢复词表中已排除的单词
  /// 
  /// [listId] 词表ID
  /// [wordId] 单词ID
  /// 
  /// 移除排除标记，使单词重新在词表中可见
  /// 
  /// 抛出异常：
  /// - 数据库错误
  /// - 单词未被排除
  Future<void> restoreWordToList(int listId, int wordId) async {
    try {
      // 检查是否已排除
      final isExcluded = await _localDatabase.isWordExcluded(wordId, listId);
      if (!isExcluded) {
        throw Exception('单词未被排除，无需恢复');
      }
      
      // 删除排除记录
      await _localDatabase.deleteExclusion(wordId, listId);
      
      // 更新词表的同步状态
      final list = await _localDatabase.getVocabularyList(listId);
      if (list != null) {
        await updateVocabularyList(list);
      }
    } catch (e) {
      throw Exception('恢复单词失败: ${e.toString()}');
    }
  }
  
  /// 获取词表中已排除的单词列表
  /// 
  /// [listId] 词表ID
  /// 返回已排除的单词列表
  Future<List<Word>> getExcludedWords(int listId) async {
    try {
      // 获取排除的单词ID列表
      final excludedIds = await _localDatabase.getExcludedWordIds(listId);
      
      // 获取单词详情
      final words = <Word>[];
      for (final wordId in excludedIds) {
        final word = await _localDatabase.getWord(wordId);
        if (word != null) {
          words.add(word);
        }
      }
      
      return words;
    } catch (e) {
      throw Exception('获取已排除单词失败: ${e.toString()}');
    }
  }
  
  // ==================== 删除词表 ====================
  
  /// 删除词表
  /// 
  /// [listId] 词表ID
  /// 
  /// 注意：删除词表会同时删除：
  /// - 词表定义
  /// - 词表与单词的关联关系
  /// - 该词表的学习进度
  /// - 该词表的排除记录
  /// 
  /// 但不会删除全局单词数据
  /// 
  /// 抛出异常：
  /// - 数据库错误
  Future<void> deleteVocabularyList(int listId) async {
    try {
      await _localDatabase.deleteVocabularyList(listId);
    } catch (e) {
      throw Exception('删除词表失败: ${e.toString()}');
    }
  }
  
  // ==================== 搜索功能 ====================
  
  /// 在词表中搜索单词
  /// 
  /// [listId] 词表ID
  /// [keyword] 搜索关键词（匹配单词或释义）
  /// [includeExcluded] 是否包含已排除的单词（默认false）
  /// 返回匹配的单词列表
  Future<List<Word>> searchWordsInList(
    int listId,
    String keyword, {
    bool includeExcluded = false,
  }) async {
    try {
      final words = await _localDatabase.getWordsByListId(
        listId,
        includeExcluded: includeExcluded,
      );
      
      // 过滤匹配关键词的单词
      final lowerKeyword = keyword.toLowerCase();
      return words.where((word) {
        return word.word.toLowerCase().contains(lowerKeyword) ||
               word.definition.toLowerCase().contains(lowerKeyword);
      }).toList();
    } catch (e) {
      throw Exception('搜索单词失败: ${e.toString()}');
    }
  }
}
