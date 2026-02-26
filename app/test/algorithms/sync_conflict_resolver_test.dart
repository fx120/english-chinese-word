import 'package:flutter_test/flutter_test.dart';
import 'package:ai_vocabulary_app/algorithms/sync_conflict_resolver.dart';
import 'package:ai_vocabulary_app/models/user_word_progress.dart';
import 'package:ai_vocabulary_app/models/user_statistics.dart';

void main() {
  group('SyncConflictResolver - resolveProgressConflict', () {
    test('应该保留记忆级别更高的本地数据', () {
      final local = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 2,
        lastReviewAt: DateTime(2024, 1, 15),
      );
      
      final remote = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 2,
        reviewCount: 3,
        lastReviewAt: DateTime(2024, 1, 16),
      );
      
      final result = SyncConflictResolver.resolveProgressConflict(local, remote);
      
      expect(result.memoryLevel, equals(3));
      expect(result, equals(local));
    });
    
    test('应该保留记忆级别更高的远程数据', () {
      final local = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 2,
        reviewCount: 5,
        lastReviewAt: DateTime(2024, 1, 16),
      );
      
      final remote = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 4,
        reviewCount: 2,
        lastReviewAt: DateTime(2024, 1, 15),
      );
      
      final result = SyncConflictResolver.resolveProgressConflict(local, remote);
      
      expect(result.memoryLevel, equals(4));
      expect(result, equals(remote));
    });
    
    test('记忆级别相同时，应该保留复习次数更多的本地数据', () {
      final local = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 5,
        lastReviewAt: DateTime(2024, 1, 15),
      );
      
      final remote = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 3,
        lastReviewAt: DateTime(2024, 1, 16),
      );
      
      final result = SyncConflictResolver.resolveProgressConflict(local, remote);
      
      expect(result.reviewCount, equals(5));
      expect(result, equals(local));
    });
    
    test('记忆级别相同时，应该保留复习次数更多的远程数据', () {
      final local = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 2,
        lastReviewAt: DateTime(2024, 1, 16),
      );
      
      final remote = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 4,
        lastReviewAt: DateTime(2024, 1, 15),
      );
      
      final result = SyncConflictResolver.resolveProgressConflict(local, remote);
      
      expect(result.reviewCount, equals(4));
      expect(result, equals(remote));
    });
    
    test('记忆级别和复习次数都相同时，应该保留最后复习时间更新的本地数据', () {
      final local = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 5,
        lastReviewAt: DateTime(2024, 1, 16, 10, 0),
      );
      
      final remote = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 5,
        lastReviewAt: DateTime(2024, 1, 16, 9, 0),
      );
      
      final result = SyncConflictResolver.resolveProgressConflict(local, remote);
      
      expect(result.lastReviewAt, equals(DateTime(2024, 1, 16, 10, 0)));
      expect(result, equals(local));
    });
    
    test('记忆级别和复习次数都相同时，应该保留最后复习时间更新的远程数据', () {
      final local = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 5,
        lastReviewAt: DateTime(2024, 1, 16, 9, 0),
      );
      
      final remote = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 5,
        lastReviewAt: DateTime(2024, 1, 16, 10, 0),
      );
      
      final result = SyncConflictResolver.resolveProgressConflict(local, remote);
      
      expect(result.lastReviewAt, equals(DateTime(2024, 1, 16, 10, 0)));
      expect(result, equals(remote));
    });
    
    test('当本地有复习时间而远程没有时，应该保留本地数据', () {
      final local = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 5,
        lastReviewAt: DateTime(2024, 1, 16),
      );
      
      final remote = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 5,
        lastReviewAt: null,
      );
      
      final result = SyncConflictResolver.resolveProgressConflict(local, remote);
      
      expect(result, equals(local));
    });
    
    test('当远程有复习时间而本地没有时，应该保留远程数据', () {
      final local = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 5,
        lastReviewAt: null,
      );
      
      final remote = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 5,
        lastReviewAt: DateTime(2024, 1, 16),
      );
      
      final result = SyncConflictResolver.resolveProgressConflict(local, remote);
      
      expect(result, equals(remote));
    });
    
    test('当所有条件都相同时，应该默认保留本地数据', () {
      final local = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 5,
        lastReviewAt: null,
      );
      
      final remote = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 3,
        reviewCount: 5,
        lastReviewAt: null,
      );
      
      final result = SyncConflictResolver.resolveProgressConflict(local, remote);
      
      expect(result, equals(local));
    });
    
    test('边界情况：记忆级别为0的数据', () {
      final local = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 0,
        reviewCount: 0,
      );
      
      final remote = UserWordProgress(
        id: 1,
        wordId: 1,
        vocabularyListId: 1,
        memoryLevel: 1,
        reviewCount: 1,
      );
      
      final result = SyncConflictResolver.resolveProgressConflict(local, remote);
      
      expect(result.memoryLevel, equals(1));
      expect(result, equals(remote));
    });
  });
  
  group('SyncConflictResolver - mergeStatistics', () {
    test('应该取所有字段的最大值', () {
      final local = UserStatistics(
        totalDays: 30,
        continuousDays: 5,
        totalWordsLearned: 500,
        totalWordsMastered: 300,
        lastLearnDate: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );
      
      final remote = UserStatistics(
        totalDays: 25,
        continuousDays: 7,
        totalWordsLearned: 450,
        totalWordsMastered: 350,
        lastLearnDate: DateTime(2024, 1, 16),
        updatedAt: DateTime(2024, 1, 16),
      );
      
      final result = SyncConflictResolver.mergeStatistics(local, remote);
      
      expect(result.totalDays, equals(30));
      expect(result.continuousDays, equals(7));
      expect(result.totalWordsLearned, equals(500));
      expect(result.totalWordsMastered, equals(350));
      expect(result.lastLearnDate, equals(DateTime(2024, 1, 16)));
    });
    
    test('当本地数据全部更大时，应该保留本地数据（除了updatedAt）', () {
      final local = UserStatistics(
        totalDays: 30,
        continuousDays: 7,
        totalWordsLearned: 500,
        totalWordsMastered: 350,
        lastLearnDate: DateTime(2024, 1, 16),
        updatedAt: DateTime(2024, 1, 15),
      );
      
      final remote = UserStatistics(
        totalDays: 25,
        continuousDays: 5,
        totalWordsLearned: 450,
        totalWordsMastered: 300,
        lastLearnDate: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 16),
      );
      
      final result = SyncConflictResolver.mergeStatistics(local, remote);
      
      expect(result.totalDays, equals(30));
      expect(result.continuousDays, equals(7));
      expect(result.totalWordsLearned, equals(500));
      expect(result.totalWordsMastered, equals(350));
      expect(result.lastLearnDate, equals(DateTime(2024, 1, 16)));
    });
    
    test('当远程数据全部更大时，应该保留远程数据（除了updatedAt）', () {
      final local = UserStatistics(
        totalDays: 25,
        continuousDays: 5,
        totalWordsLearned: 450,
        totalWordsMastered: 300,
        lastLearnDate: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );
      
      final remote = UserStatistics(
        totalDays: 30,
        continuousDays: 7,
        totalWordsLearned: 500,
        totalWordsMastered: 350,
        lastLearnDate: DateTime(2024, 1, 16),
        updatedAt: DateTime(2024, 1, 16),
      );
      
      final result = SyncConflictResolver.mergeStatistics(local, remote);
      
      expect(result.totalDays, equals(30));
      expect(result.continuousDays, equals(7));
      expect(result.totalWordsLearned, equals(500));
      expect(result.totalWordsMastered, equals(350));
      expect(result.lastLearnDate, equals(DateTime(2024, 1, 16)));
    });
    
    test('当本地lastLearnDate为null时，应该使用远程的日期', () {
      final local = UserStatistics(
        totalDays: 30,
        continuousDays: 7,
        totalWordsLearned: 500,
        totalWordsMastered: 350,
        lastLearnDate: null,
        updatedAt: DateTime(2024, 1, 15),
      );
      
      final remote = UserStatistics(
        totalDays: 25,
        continuousDays: 5,
        totalWordsLearned: 450,
        totalWordsMastered: 300,
        lastLearnDate: DateTime(2024, 1, 16),
        updatedAt: DateTime(2024, 1, 16),
      );
      
      final result = SyncConflictResolver.mergeStatistics(local, remote);
      
      expect(result.lastLearnDate, equals(DateTime(2024, 1, 16)));
    });
    
    test('当远程lastLearnDate为null时，应该使用本地的日期', () {
      final local = UserStatistics(
        totalDays: 30,
        continuousDays: 7,
        totalWordsLearned: 500,
        totalWordsMastered: 350,
        lastLearnDate: DateTime(2024, 1, 16),
        updatedAt: DateTime(2024, 1, 15),
      );
      
      final remote = UserStatistics(
        totalDays: 25,
        continuousDays: 5,
        totalWordsLearned: 450,
        totalWordsMastered: 300,
        lastLearnDate: null,
        updatedAt: DateTime(2024, 1, 16),
      );
      
      final result = SyncConflictResolver.mergeStatistics(local, remote);
      
      expect(result.lastLearnDate, equals(DateTime(2024, 1, 16)));
    });
    
    test('当两个lastLearnDate都为null时，结果也应该为null', () {
      final local = UserStatistics(
        totalDays: 30,
        continuousDays: 7,
        totalWordsLearned: 500,
        totalWordsMastered: 350,
        lastLearnDate: null,
        updatedAt: DateTime(2024, 1, 15),
      );
      
      final remote = UserStatistics(
        totalDays: 25,
        continuousDays: 5,
        totalWordsLearned: 450,
        totalWordsMastered: 300,
        lastLearnDate: null,
        updatedAt: DateTime(2024, 1, 16),
      );
      
      final result = SyncConflictResolver.mergeStatistics(local, remote);
      
      expect(result.lastLearnDate, isNull);
    });
    
    test('边界情况：所有统计数据为0', () {
      final local = UserStatistics(
        totalDays: 0,
        continuousDays: 0,
        totalWordsLearned: 0,
        totalWordsMastered: 0,
        lastLearnDate: null,
        updatedAt: DateTime(2024, 1, 15),
      );
      
      final remote = UserStatistics(
        totalDays: 0,
        continuousDays: 0,
        totalWordsLearned: 0,
        totalWordsMastered: 0,
        lastLearnDate: null,
        updatedAt: DateTime(2024, 1, 16),
      );
      
      final result = SyncConflictResolver.mergeStatistics(local, remote);
      
      expect(result.totalDays, equals(0));
      expect(result.continuousDays, equals(0));
      expect(result.totalWordsLearned, equals(0));
      expect(result.totalWordsMastered, equals(0));
      expect(result.lastLearnDate, isNull);
    });
    
    test('updatedAt应该总是设置为当前时间', () {
      final now = DateTime.now();
      
      final local = UserStatistics(
        totalDays: 30,
        continuousDays: 7,
        totalWordsLearned: 500,
        totalWordsMastered: 350,
        lastLearnDate: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );
      
      final remote = UserStatistics(
        totalDays: 25,
        continuousDays: 5,
        totalWordsLearned: 450,
        totalWordsMastered: 300,
        lastLearnDate: DateTime(2024, 1, 16),
        updatedAt: DateTime(2024, 1, 16),
      );
      
      final result = SyncConflictResolver.mergeStatistics(local, remote);
      
      // 验证updatedAt是最近的时间（允许1秒误差）
      final difference = result.updatedAt.difference(now).inSeconds.abs();
      expect(difference, lessThan(2));
    });
  });
}
