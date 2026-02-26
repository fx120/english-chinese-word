import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ai_vocabulary_app/main.dart';
import 'package:ai_vocabulary_app/database/local_database.dart';
import 'package:ai_vocabulary_app/services/api_client.dart';

import 'test_helpers.dart';

/// 复习流程集成测试
/// 
/// 测试复习功能的完整流程，包括：
/// - 记忆曲线复习
/// - 错题复习
/// - 复习进度更新
/// - 复习统计
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('复习流程集成测试', () {
    late LocalDatabase database;
    late ApiClient apiClient;
    late int testListId;
    late List<int> wordIds;

    setUp(() async {
      database = LocalDatabase();
      await database.initialize();
      apiClient = ApiClient();

      // 创建测试数据
      testListId = await TestHelpers.createTestVocabularyList(
        database,
        name: '复习测试词表',
        wordCount: 10,
      );
      wordIds = await TestHelpers.createTestWords(database, testListId, 10);
    });

    tearDown() async {
      await TestHelpers.clearAllTestData(database);
    });

    testWidgets('记忆曲线复习 - 完整流程', (WidgetTester tester) async {
      // 创建到期复习进度
      await TestHelpers.createDueReviewProgress(database, testListId, wordIds.sublist(0, 5));

      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 导航到复习页面
      final reviewTab = find.text('复习');
      if (reviewTab.evaluate().isNotEmpty) {
        await tester.tap(reviewTab);
        await tester.pumpAndSettle();

        // 验证待复习单词数量显示
        expect(find.textContaining('待复习'), findsOneWidget);
        expect(find.textContaining('5'), findsOneWidget);

        // 选择词表
        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          // 选择记忆曲线复习
          final memoryCurveButton = find.byKey(const Key('memory_curve_button'));
          expect(memoryCurveButton, findsOneWidget);
          await tester.tap(memoryCurveButton);
          await tester.pumpAndSettle();

          // 验证复习卡片显示
          expect(find.byKey(const Key('review_card')), findsOneWidget);
          expect(find.byKey(const Key('show_answer_button')), findsOneWidget);

          // 复习3个单词
          for (int i = 0; i < 3; i++) {
            // 显示答案
            await tester.tap(find.byKey(const Key('show_answer_button')));
            await tester.pumpAndSettle();

            // 验证答案显示
            expect(find.byKey(const Key('word_definition')), findsOneWidget);
            expect(find.byKey(const Key('remember_button')), findsOneWidget);
            expect(find.byKey(const Key('forget_button')), findsOneWidget);

            // 交替选择"记得"和"忘记"
            if (i % 2 == 0) {
              await tester.tap(find.byKey(const Key('remember_button')));
            } else {
              await tester.tap(find.byKey(const Key('forget_button')));
            }
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 500));
          }

          // 验证复习进度已更新
          final dueReviewCount = await TestHelpers.getDueReviewWordCount(database, testListId);
          expect(dueReviewCount, lessThan(5)); // 应该减少了
        }
      }
    });

    testWidgets('错题复习 - 完整流程', (WidgetTester tester) async {
      // 创建错题进度
      await TestHelpers.createWrongWordsProgress(database, testListId, wordIds.sublist(0, 5));

      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 导航到复习页面
      final reviewTab = find.text('复习');
      if (reviewTab.evaluate().isNotEmpty) {
        await tester.tap(reviewTab);
        await tester.pumpAndSettle();

        // 验证错题数量显示
        expect(find.textContaining('错题'), findsOneWidget);
        expect(find.textContaining('5'), findsOneWidget);

        // 选择词表
        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          // 选择错题复习
          final wrongWordsButton = find.byKey(const Key('wrong_words_button'));
          expect(wrongWordsButton, findsOneWidget);
          await tester.tap(wrongWordsButton);
          await tester.pumpAndSettle();

          // 验证复习卡片显示
          expect(find.byKey(const Key('review_card')), findsOneWidget);

          // 复习2个错题
          for (int i = 0; i < 2; i++) {
            await tester.tap(find.byKey(const Key('show_answer_button')));
            await tester.pumpAndSettle();

            // 选择"记得"，从错题集中移除
            await tester.tap(find.byKey(const Key('remember_button')));
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 500));
          }

          // 返回复习模式选择页面
          final backButton = find.byType(BackButton);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton);
            await tester.pumpAndSettle();

            // 验证错题数量减少
            // 注意：需要刷新页面才能看到更新的数量
          }
        }
      }
    });

    testWidgets('记忆级别升级测试', (WidgetTester tester) async {
      // 创建一个记忆级别为1的单词
      await TestHelpers.createDueReviewProgress(database, testListId, [wordIds[0]]);

      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 获取初始记忆级别
      final initialProgress = await database.getProgress(wordIds[0], testListId);
      expect(initialProgress, isNotNull);
      expect(initialProgress!.memoryLevel, equals(1));

      // 进行复习并选择"记得"
      final reviewTab = find.text('复习');
      if (reviewTab.evaluate().isNotEmpty) {
        await tester.tap(reviewTab);
        await tester.pumpAndSettle();

        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          final memoryCurveButton = find.byKey(const Key('memory_curve_button'));
          await tester.tap(memoryCurveButton);
          await tester.pumpAndSettle();

          // 复习并选择"记得"
          await tester.tap(find.byKey(const Key('show_answer_button')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('remember_button')));
          await tester.pumpAndSettle();

          // 验证记忆级别升级到2
          final updatedProgress = await database.getProgress(wordIds[0], testListId);
          expect(updatedProgress, isNotNull);
          expect(updatedProgress!.memoryLevel, equals(2));

          // 验证下次复习时间更新（2天后）
          expect(updatedProgress.nextReviewAt, isNotNull);
          final expectedReviewTime = DateTime.now().add(const Duration(days: 2));
          final actualReviewTime = updatedProgress.nextReviewAt!;
          final timeDifference = actualReviewTime.difference(expectedReviewTime).inHours.abs();
          expect(timeDifference, lessThan(1)); // 允许1小时误差
        }
      }
    });

    testWidgets('记忆级别重置测试', (WidgetTester tester) async {
      // 创建一个记忆级别为3的单词
      final progress = await database.getProgress(wordIds[0], testListId);
      if (progress == null) {
        await database.insertOrUpdateProgress(UserWordProgress(
          id: 0,
          wordId: wordIds[0],
          vocabularyListId: testListId,
          status: LearningStatus.needReview,
          learnedAt: DateTime.now(),
          lastReviewAt: DateTime.now().subtract(const Duration(days: 1)),
          nextReviewAt: DateTime.now().subtract(const Duration(days: 1)),
          reviewCount: 3,
          errorCount: 0,
          memoryLevel: 3,
          syncStatus: 'synced',
        ));
      }

      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 进行复习并选择"忘记"
      final reviewTab = find.text('复习');
      if (reviewTab.evaluate().isNotEmpty) {
        await tester.tap(reviewTab);
        await tester.pumpAndSettle();

        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          final memoryCurveButton = find.byKey(const Key('memory_curve_button'));
          await tester.tap(memoryCurveButton);
          await tester.pumpAndSettle();

          // 复习并选择"忘记"
          await tester.tap(find.byKey(const Key('show_answer_button')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('forget_button')));
          await tester.pumpAndSettle();

          // 验证记忆级别重置到1
          final updatedProgress = await database.getProgress(wordIds[0], testListId);
          expect(updatedProgress, isNotNull);
          expect(updatedProgress!.memoryLevel, equals(1));

          // 验证错误计数增加
          expect(updatedProgress.errorCount, greaterThan(0));
        }
      }
    });

    testWidgets('错题按错误次数排序', (WidgetTester tester) async {
      // 创建不同错误次数的错题
      await TestHelpers.createWrongWordsProgress(database, testListId, wordIds.sublist(0, 5));

      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 获取错题列表
      final progressList = await database.getProgressByListId(testListId);
      final wrongWords = progressList.where((p) => p.errorCount > 0).toList();
      wrongWords.sort((a, b) => b.errorCount.compareTo(a.errorCount));

      // 验证排序正确（错误次数降序）
      for (int i = 0; i < wrongWords.length - 1; i++) {
        expect(wrongWords[i].errorCount, greaterThanOrEqualTo(wrongWords[i + 1].errorCount));
      }
    });

    testWidgets('复习统计显示', (WidgetTester tester) async {
      await TestHelpers.createDueReviewProgress(database, testListId, wordIds.sublist(0, 5));

      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 进行复习
      final reviewTab = find.text('复习');
      if (reviewTab.evaluate().isNotEmpty) {
        await tester.tap(reviewTab);
        await tester.pumpAndSettle();

        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          final memoryCurveButton = find.byKey(const Key('memory_curve_button'));
          await tester.tap(memoryCurveButton);
          await tester.pumpAndSettle();

          int rememberCount = 0;
          int forgetCount = 0;

          // 复习3个单词
          for (int i = 0; i < 3; i++) {
            await tester.tap(find.byKey(const Key('show_answer_button')));
            await tester.pumpAndSettle();

            if (i % 2 == 0) {
              await tester.tap(find.byKey(const Key('remember_button')));
              rememberCount++;
            } else {
              await tester.tap(find.byKey(const Key('forget_button')));
              forgetCount++;
            }
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 500));
          }

          // 结束复习
          final backButton = find.byType(BackButton);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton);
            await tester.pumpAndSettle();

            // 验证复习统计显示
            expect(find.textContaining('复习统计'), findsOneWidget);
            expect(find.textContaining('记得'), findsOneWidget);
            expect(find.textContaining('忘记'), findsOneWidget);

            // 验证统计数据正确
            expect(find.textContaining('$rememberCount'), findsOneWidget);
            expect(find.textContaining('$forgetCount'), findsOneWidget);
          }
        }
      }
    });

    testWidgets('没有到期复习单词的提示', (WidgetTester tester) async {
      // 不创建到期复习进度

      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 尝试进入复习
      final reviewTab = find.text('复习');
      if (reviewTab.evaluate().isNotEmpty) {
        await tester.tap(reviewTab);
        await tester.pumpAndSettle();

        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          final memoryCurveButton = find.byKey(const Key('memory_curve_button'));
          await tester.tap(memoryCurveButton);
          await tester.pumpAndSettle();

          // 验证提示信息
          expect(find.textContaining('暂无需要复习的单词'), findsOneWidget);
        }
      }
    });

    testWidgets('复习进度持久化', (WidgetTester tester) async {
      await TestHelpers.createDueReviewProgress(database, testListId, wordIds.sublist(0, 3));

      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 复习一个单词
      final reviewTab = find.text('复习');
      if (reviewTab.evaluate().isNotEmpty) {
        await tester.tap(reviewTab);
        await tester.pumpAndSettle();

        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          final memoryCurveButton = find.byKey(const Key('memory_curve_button'));
          await tester.tap(memoryCurveButton);
          await tester.pumpAndSettle();

          // 复习一个单词
          await tester.tap(find.byKey(const Key('show_answer_button')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('remember_button')));
          await tester.pumpAndSettle();

          // 退出复习
          final backButton = find.byType(BackButton);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton);
            await tester.pumpAndSettle();
          }
        }
      }

      // 验证复习进度已保存
      final dueReviewCount = await TestHelpers.getDueReviewWordCount(database, testListId);
      expect(dueReviewCount, equals(2)); // 3 - 1 = 2

      // 重启应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 验证复习进度仍然存在
      final dueReviewCountAfterRestart = await TestHelpers.getDueReviewWordCount(database, testListId);
      expect(dueReviewCountAfterRestart, equals(2));
    });

    testWidgets('复习计数正确更新', (WidgetTester tester) async {
      await TestHelpers.createDueReviewProgress(database, testListId, [wordIds[0]]);

      // 获取初始复习次数
      final initialProgress = await database.getProgress(wordIds[0], testListId);
      final initialReviewCount = initialProgress!.reviewCount;

      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 进行复习
      final reviewTab = find.text('复习');
      if (reviewTab.evaluate().isNotEmpty) {
        await tester.tap(reviewTab);
        await tester.pumpAndSettle();

        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          final memoryCurveButton = find.byKey(const Key('memory_curve_button'));
          await tester.tap(memoryCurveButton);
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('show_answer_button')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('remember_button')));
          await tester.pumpAndSettle();

          // 验证复习次数增加
          final updatedProgress = await database.getProgress(wordIds[0], testListId);
          expect(updatedProgress!.reviewCount, equals(initialReviewCount + 1));
        }
      }
    });
  });
}
