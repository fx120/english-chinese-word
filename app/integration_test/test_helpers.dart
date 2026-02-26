import 'package:ai_vocabulary_app/database/local_database.dart';
import 'package:ai_vocabulary_app/models/vocabulary_list.dart';
import 'package:ai_vocabulary_app/models/word.dart';
import 'package:ai_vocabulary_app/models/user_word_progress.dart';
import 'package:ai_vocabulary_app/models/user_statistics.dart';
import 'package:ai_vocabulary_app/models/daily_record.dart';

/// 集成测试辅助工具类
/// 
/// 提供创建测试数据的辅助方法
class TestHelpers {
  /// 创建测试词表
  static Future<int> createTestVocabularyList(
    LocalDatabase database, {
    String name = '测试词表',
    String description = '这是一个测试词表',
    String category = 'test',
    int wordCount = 0,
  }) async {
    final list = VocabularyList(
      id: 0,
      name: name,
      description: description,
      category: category,
      difficultyLevel: 1,
      wordCount: wordCount,
      isOfficial: false,
      isCustom: true,
      createdAt: DateTime.now(),
      syncStatus: 'synced',
    );

    await database.insertVocabularyList(list);
    
    // 获取插入后的ID
    final lists = await database.getAllVocabularyLists();
    return lists.last.id;
  }

  /// 创建测试单词
  static Future<List<int>> createTestWords(
    LocalDatabase database,
    int listId,
    int count,
  ) async {
    final wordIds = <int>[];

    for (int i = 0; i < count; i++) {
      final word = Word(
        id: 0,
        word: 'word_$i',
        phonetic: '/wɜːd/',
        partOfSpeech: 'n.',
        definition: '单词 $i 的释义',
        example: 'This is an example sentence for word $i.',
        createdAt: DateTime.now(),
      );

      final wordId = await database.insertWord(word);
      wordIds.add(wordId);

      // 关联单词到词表
      await database.addWordToList(wordId, listId, i);
    }

    return wordIds;
  }

  /// 创建到期复习进度
  static Future<void> createDueReviewProgress(
    LocalDatabase database,
    int listId,
    List<int> wordIds,
  ) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    for (int i = 0; i < wordIds.length; i++) {
      final progress = UserWordProgress(
        id: 0,
        wordId: wordIds[i],
        vocabularyListId: listId,
        status: LearningStatus.needReview,
        learnedAt: yesterday,
        lastReviewAt: yesterday,
        nextReviewAt: yesterday, // 已到期
        reviewCount: i + 1,
        errorCount: 0,
        memoryLevel: 1,
        syncStatus: 'synced',
      );

      await database.insertOrUpdateProgress(progress);
    }
  }

  /// 创建错题进度
  static Future<void> createWrongWordsProgress(
    LocalDatabase database,
    int listId,
    List<int> wordIds,
  ) async {
    final now = DateTime.now();

    for (int i = 0; i < wordIds.length; i++) {
      final progress = UserWordProgress(
        id: 0,
        wordId: wordIds[i],
        vocabularyListId: listId,
        status: LearningStatus.needReview,
        learnedAt: now,
        lastReviewAt: now,
        nextReviewAt: now.add(const Duration(days: 1)),
        reviewCount: i + 1,
        errorCount: (i + 1) * 2, // 错误次数递增
        memoryLevel: 1,
        syncStatus: 'synced',
      );

      await database.insertOrUpdateProgress(progress);
    }
  }

  /// 创建学习进度（混合状态）
  static Future<void> createLearningProgress(
    LocalDatabase database,
    int listId,
    List<int> wordIds,
  ) async {
    final now = DateTime.now();

    for (int i = 0; i < wordIds.length; i++) {
      LearningStatus status;
      int memoryLevel;
      DateTime? nextReviewAt;

      // 创建不同状态的单词
      if (i % 3 == 0) {
        status = LearningStatus.mastered;
        memoryLevel = 5;
        nextReviewAt = now.add(const Duration(days: 15));
      } else if (i % 3 == 1) {
        status = LearningStatus.needReview;
        memoryLevel = 2;
        nextReviewAt = now.add(const Duration(days: 2));
      } else {
        status = LearningStatus.notLearned;
        memoryLevel = 0;
        nextReviewAt = null;
      }

      final progress = UserWordProgress(
        id: 0,
        wordId: wordIds[i],
        vocabularyListId: listId,
        status: status,
        learnedAt: status != LearningStatus.notLearned ? now : null,
        lastReviewAt: status != LearningStatus.notLearned ? now : null,
        nextReviewAt: nextReviewAt,
        reviewCount: status != LearningStatus.notLearned ? i + 1 : 0,
        errorCount: status == LearningStatus.needReview ? 1 : 0,
        memoryLevel: memoryLevel,
        syncStatus: 'synced',
      );

      await database.insertOrUpdateProgress(progress);
    }
  }

  /// 创建统计数据
  static Future<void> createStatisticsData(LocalDatabase database) async {
    final statistics = UserStatistics(
      totalDays: 30,
      continuousDays: 7,
      totalWordsLearned: 150,
      totalWordsMastered: 100,
      lastLearnDate: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await database.updateStatistics(statistics);

    // 创建每日学习记录
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final record = DailyRecord(
        date: _formatDate(date),
        newWordsCount: 10 + i,
        reviewWordsCount: 20 + i,
        createdAt: date,
      );

      await database.insertDailyRecord(record);
    }
  }

  /// 格式化日期为字符串
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 清理所有测试数据
  static Future<void> clearAllTestData(LocalDatabase database) async {
    // 清理所有表的数据
    await database.clearAllData();
  }

  /// 验证词表是否存在
  static Future<bool> vocabularyListExists(
    LocalDatabase database,
    int listId,
  ) async {
    final list = await database.getVocabularyList(listId);
    return list != null;
  }

  /// 验证单词是否存在
  static Future<bool> wordExists(
    LocalDatabase database,
    int wordId,
  ) async {
    final word = await database.getWord(wordId);
    return word != null;
  }

  /// 验证学习进度是否存在
  static Future<bool> progressExists(
    LocalDatabase database,
    int wordId,
    int listId,
  ) async {
    final progress = await database.getProgress(wordId, listId);
    return progress != null;
  }

  /// 获取词表的单词数量
  static Future<int> getWordCount(
    LocalDatabase database,
    int listId,
  ) async {
    final words = await database.getWordsByListId(listId);
    return words.length;
  }

  /// 获取已掌握单词数量
  static Future<int> getMasteredWordCount(
    LocalDatabase database,
    int listId,
  ) async {
    final progressList = await database.getProgressByListId(listId);
    return progressList.where((p) => p.status == LearningStatus.mastered).length;
  }

  /// 获取需复习单词数量
  static Future<int> getNeedReviewWordCount(
    LocalDatabase database,
    int listId,
  ) async {
    final progressList = await database.getProgressByListId(listId);
    return progressList.where((p) => p.status == LearningStatus.needReview).length;
  }

  /// 获取未学习单词数量
  static Future<int> getNotLearnedWordCount(
    LocalDatabase database,
    int listId,
  ) async {
    final unlearnedIds = await database.getUnlearnedWordIds(listId);
    return unlearnedIds.length;
  }

  /// 获取到期复习单词数量
  static Future<int> getDueReviewWordCount(
    LocalDatabase database,
    int listId,
  ) async {
    final dueReviews = await database.getDueReviews(listId);
    return dueReviews.length;
  }

  /// 创建模拟的API响应数据
  static Map<String, dynamic> createMockLoginResponse({
    String token = 'mock_jwt_token',
    int userId = 1,
    String mobile = '13800138000',
    String nickname = '测试用户',
  }) {
    return {
      'code': 0,
      'msg': '登录成功',
      'data': {
        'token': token,
        'user': {
          'id': userId,
          'mobile': mobile,
          'nickname': nickname,
          'avatar': null,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
      },
    };
  }

  /// 创建模拟的词表列表响应
  static Map<String, dynamic> createMockVocabularyListResponse({
    int count = 5,
  }) {
    final items = List.generate(count, (index) {
      return {
        'id': index + 1,
        'name': 'CET-${index + 4}核心词汇',
        'description': '大学英语${index + 4}级核心词汇',
        'category': 'CET${index + 4}',
        'difficulty_level': index + 1,
        'word_count': (index + 1) * 500,
        'is_official': true,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
    });

    return {
      'code': 0,
      'msg': 'success',
      'data': {
        'total': count,
        'page': 1,
        'limit': 20,
        'items': items,
      },
    };
  }

  /// 创建模拟的词表详情响应
  static Map<String, dynamic> createMockVocabularyDetailResponse({
    int listId = 1,
    int wordCount = 10,
  }) {
    final words = List.generate(wordCount, (index) {
      return {
        'id': index + 1,
        'word': 'word_$index',
        'phonetic': '/wɜːd/',
        'part_of_speech': 'n.',
        'definition': '单词 $index 的释义',
        'example': 'This is an example sentence for word $index.',
        'sort_order': index,
      };
    });

    return {
      'code': 0,
      'msg': 'success',
      'data': {
        'id': listId,
        'name': '测试词表',
        'description': '这是一个测试词表',
        'category': 'test',
        'difficulty_level': 1,
        'word_count': wordCount,
        'is_official': true,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'words': words,
      },
    };
  }

  /// 创建模拟的同步响应
  static Map<String, dynamic> createMockSyncResponse({
    int syncedCount = 10,
  }) {
    return {
      'code': 0,
      'msg': '同步成功',
      'data': {
        'synced_count': syncedCount,
        'conflicts': [],
      },
    };
  }
}
