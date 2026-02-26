import '../database/local_database.dart';
import '../models/word.dart';

class SequentialLearningAlgorithm {
  /// 获取下一个顺序单词
  /// [listId] 词表ID
  /// [excludedIds] 已排除的单词ID列表
  /// [currentIndex] 当前学习索引
  /// 返回下一个单词ID和新的索引
  static Future<({int? wordId, int nextIndex})> getNextSequentialWord(
    LocalDatabase db,
    int listId,
    List<int> excludedIds,
    int currentIndex,
  ) async {
    // 获取词表所有单词(按sort_order排序)
    List<Word> allWords = await db.getWordsByListId(listId);
    
    // 过滤已排除的单词
    List<Word> availableWords = allWords.where((word) {
      return !excludedIds.contains(word.id);
    }).toList();
    
    if (availableWords.isEmpty) {
      return (wordId: null, nextIndex: 0);
    }
    
    // 检查索引是否越界
    if (currentIndex >= availableWords.length) {
      return (wordId: null, nextIndex: availableWords.length);
    }
    
    return (
      wordId: availableWords[currentIndex].id,
      nextIndex: currentIndex + 1
    );
  }
  
  /// 计算学习进度百分比
  static double calculateProgress(int learnedCount, int totalCount) {
    if (totalCount == 0) return 0.0;
    return (learnedCount / totalCount * 100).clamp(0.0, 100.0);
  }
}
