import 'dart:math';
import '../database/local_database.dart';
import '../models/word.dart';

class RandomLearningAlgorithm {
  /// 获取随机未学习单词
  /// [listId] 词表ID
  /// [excludedIds] 已排除的单词ID列表
  /// [learnedIds] 已学习的单词ID列表
  /// 返回随机选择的单词ID
  static Future<int?> getRandomUnlearnedWord(
    LocalDatabase db,
    int listId,
    List<int> excludedIds,
    List<int> learnedIds,
  ) async {
    // 获取词表所有单词
    List<Word> allWords = await db.getWordsByListId(listId);
    
    // 过滤已排除和已学习的单词
    List<Word> unlearnedWords = allWords.where((word) {
      return !excludedIds.contains(word.id) && !learnedIds.contains(word.id);
    }).toList();
    
    if (unlearnedWords.isEmpty) {
      return null; // 没有未学习的单词
    }
    
    // 随机选择
    final random = Random();
    int randomIndex = random.nextInt(unlearnedWords.length);
    return unlearnedWords[randomIndex].id;
  }
}
