import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ai_vocabulary_app/main.dart';
import 'package:ai_vocabulary_app/database/local_database.dart';
import 'package:ai_vocabulary_app/services/api_client.dart';

import 'test_helpers.dart';

/// 学习流程集成测试
/// 
/// 测试学习功能的完整流程，包括：
/// - 随机学习模式
/// - 顺序学习模式
/// - 学习进度更新
/// - 学习统计
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('学习流程集成测试', () {
    late LocalDatabase database;
    late ApiClient apiClient;
    late int testListId;

    setUp(() async {
      database = LocalDatabase();
      await database.initialize();
      apiClient = ApiClient();

      // 创建测试数据
      testListId = await TestHelpers.createTestVocabularyList(
        database,
        name: '测试词表',
        wordCount: 20,
      );
      await TestHelpers.createTestWords(database, testListId, 20);
    });

    tearDown(() async {
      await TestHelpers.clearAllTestData(database);
    });

    testWidgets('随机学习模式 - 完整流程', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 导航到学习页面（假设已登录）
      final learningTab = find.text('学习');
      if (learningTab.evaluate().isNotEmpty) {
        await tester.tap(learningTab);
        await tester.pumpAndSettle();

        // 选择词表
        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          // 选择随机学习模式
          final randomModeButton = find.byKey(const Key('random_mode_button'));
          expect(randomModeButton, findsOneWidget);
          await tester.tap(randomModeButton);
          await tester.pumpAndSettle();

          // 验证学习卡片显示
          expect(find.byKey(const Key('word_card')), findsOneWidget);
          expect(find.byKey(const Key('show_answer_button')), findsOneWidget);

          // 学习5个单词
          for (int i = 0; i < 5; i++) {
            // 点击显示答案
            await tester.tap(find.byKey(const Key('show_answer_button')));
            await tester.pumpAndSettle();

            // 验证答案显示
            expect(find.byKey(const Key('word_definition')), findsOneWidget);
            expect(find.byKey(const Key('known_button')), findsOneWidget);
            expect(find.byKey(const Key('unknown_button')), findsOneWidget);

            // 交替选择"认识"和"不认识"
            if (i % 2 == 0) {
              await tester.tap(find.byKey(const Key('known_button')));
            } else {
              await tester.tap(find.byKey(const Key('unknown_button')));
            }
            await tester.pumpAndSettle();

            // 等待加载下一个单词
            await tester.pump(const Duration(milliseconds: 500));
          }

          // 验证学习进度已更新
          final learnedCount = await TestHelpers.getMasteredWordCount(database, testListId) +
              await TestHelpers.getNeedReviewWordCount(database, testListId);
          expect(learnedCount, equals(5));
        }
      }
    });

    testWidgets('顺序学习模式 - 完整流程', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 导航到学习页面
      final learningTab = find.text('学习');
      if (learningTab.evaluate().isNotEmpty) {
        await tester.tap(learningTab);
        await tester.pumpAndSettle();

        // 选择词表
        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          // 选择顺序学习模式
          final sequentialModeButton = find.byKey(const Key('sequential_mode_button'));
          expect(sequentialModeButton, findsOneWidget);
          await tester.tap(sequentialModeButton);
          await tester.pumpAndSettle();

          // 验证学习进度显示
          expect(find.textContaining('/20'), findsOneWidget);

          // 学习10个单词
          for (int i = 0; i < 10; i++) {
            // 验证进度更新
            expect(find.textContaining('${i + 1}/20'), findsOneWidget);

            // 显示答案
            await tester.tap(find.byKey(const Key('show_answer_button')));
            await tester.pumpAndSettle();

            // 选择"认识"
            await tester.tap(find.byKey(const Key('known_button')));
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 500));
          }

          // 验证最终进度
          expect(find.textContaining('10/20'), findsOneWidget);

          // 验证学习进度已保存
          final masteredCount = await TestHelpers.getMasteredWordCount(database, testListId);
          expect(masteredCount, equals(10));
        }
      }
    });

    testWidgets('学习会话统计', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 开始学习会话
      final learningTab = find.text('学习');
      if (learningTab.evaluate().isNotEmpty) {
        await tester.tap(learningTab);
        await tester.pumpAndSettle();

        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          final randomModeButton = find.byKey(const Key('random_mode_button'));
          await tester.tap(randomModeButton);
          await tester.pumpAndSettle();

          // 学习几个单词
          int knownCount = 0;
          int unknownCount = 0;

          for (int i = 0; i < 5; i++) {
            await tester.tap(find.byKey(const Key('show_answer_button')));
            await tester.pumpAndSettle();

            if (i % 2 == 0) {
              await tester.tap(find.byKey(const Key('known_button')));
              knownCount++;
            } else {
              await tester.tap(find.byKey(const Key('unknown_button')));
              unknownCount++;
            }
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 500));
          }

          // 结束学习会话（返回或完成所有单词）
          final backButton = find.byType(BackButton);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton);
            await tester.pumpAndSettle();

            // 验证学习统计显示
            expect(find.textContaining('学习统计'), findsOneWidget);
            expect(find.textContaining('已学习'), findsOneWidget);
            expect(find.textContaining('认识'), findsOneWidget);
            expect(find.textContaining('不认识'), findsOneWidget);

            // 验证统计数据正确
            expect(find.textContaining('$knownCount'), findsOneWidget);
            expect(find.textContaining('$unknownCount'), findsOneWidget);
          }
        }
      }
    });

    testWidgets('学习进度持久化', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 学习几个单词
      final learningTab = find.text('学习');
      if (learningTab.evaluate().isNotEmpty) {
        await tester.tap(learningTab);
        await tester.pumpAndSettle();

        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          final randomModeButton = find.byKey(const Key('random_mode_button'));
          await tester.tap(randomModeButton);
          await tester.pumpAndSettle();

          // 学习3个单词
          for (int i = 0; i < 3; i++) {
            await tester.tap(find.byKey(const Key('show_answer_button')));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('known_button')));
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 500));
          }

          // 退出学习
          final backButton = find.byType(BackButton);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton);
            await tester.pumpAndSettle();
          }
        }
      }

      // 验证学习进度已保存到数据库
      final masteredCount = await TestHelpers.getMasteredWordCount(database, testListId);
      expect(masteredCount, equals(3));

      // 重启应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 验证学习进度仍然存在
      final masteredCountAfterRestart = await TestHelpers.getMasteredWordCount(database, testListId);
      expect(masteredCountAfterRestart, equals(3));
    });

    testWidgets('学习空词表错误处理', (WidgetTester tester) async {
      // 创建一个空词表
      final emptyListId = await TestHelpers.createTestVocabularyList(
        database,
        name: '空词表',
        wordCount: 0,
      );

      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 尝试学习空词表
      final learningTab = find.text('学习');
      if (learningTab.evaluate().isNotEmpty) {
        await tester.tap(learningTab);
        await tester.pumpAndSettle();

        final emptyListItem = find.byKey(Key('vocabulary_list_$emptyListId'));
        if (emptyListItem.evaluate().isNotEmpty) {
          await tester.tap(emptyListItem);
          await tester.pumpAndSettle();

          final randomModeButton = find.byKey(const Key('random_mode_button'));
          await tester.tap(randomModeButton);
          await tester.pumpAndSettle();

          // 验证错误提示
          expect(find.textContaining('没有可学习的单词'), findsOneWidget);
        }
      }
    });

    testWidgets('学习完所有单词后的提示', (WidgetTester tester) async {
      // 创建一个只有3个单词的词表
      final smallListId = await TestHelpers.createTestVocabularyList(
        database,
        name: '小词表',
        wordCount: 3,
      );
      await TestHelpers.createTestWords(database, smallListId, 3);

      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 学习所有单词
      final learningTab = find.text('学习');
      if (learningTab.evaluate().isNotEmpty) {
        await tester.tap(learningTab);
        await tester.pumpAndSettle();

        final smallListItem = find.byKey(Key('vocabulary_list_$smallListId'));
        if (smallListItem.evaluate().isNotEmpty) {
          await tester.tap(smallListItem);
          await tester.pumpAndSettle();

          final randomModeButton = find.byKey(const Key('random_mode_button'));
          await tester.tap(randomModeButton);
          await tester.pumpAndSettle();

          // 学习所有3个单词
          for (int i = 0; i < 3; i++) {
            await tester.tap(find.byKey(const Key('show_answer_button')));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('known_button')));
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 500));
          }

          // 验证完成提示
          expect(find.textContaining('学习完成'), findsOneWidget);
          expect(find.textContaining('恭喜'), findsOneWidget);
        }
      }
    });

    testWidgets('学习中断和恢复', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 开始学习
      final learningTab = find.text('学习');
      if (learningTab.evaluate().isNotEmpty) {
        await tester.tap(learningTab);
        await tester.pumpAndSettle();

        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          final randomModeButton = find.byKey(const Key('random_mode_button'));
          await tester.tap(randomModeButton);
          await tester.pumpAndSettle();

          // 学习2个单词
          for (int i = 0; i < 2; i++) {
            await tester.tap(find.byKey(const Key('show_answer_button')));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('known_button')));
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 500));
          }

          // 中断学习（返回）
          final backButton = find.byType(BackButton);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton);
            await tester.pumpAndSettle();
          }

          // 再次开始学习
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();
          await tester.tap(randomModeButton);
          await tester.pumpAndSettle();

          // 验证可以继续学习剩余的单词
          expect(find.byKey(const Key('word_card')), findsOneWidget);

          // 验证之前学习的单词不会再次出现
          final notLearnedCount = await TestHelpers.getNotLearnedWordCount(database, testListId);
          expect(notLearnedCount, equals(18)); // 20 - 2 = 18
        }
      }
    });

    testWidgets('记忆级别正确更新', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 学习一个单词并标记为"认识"
      final learningTab = find.text('学习');
      if (learningTab.evaluate().isNotEmpty) {
        await tester.tap(learningTab);
        await tester.pumpAndSettle();

        final vocabularyListItem = find.byKey(Key('vocabulary_list_$testListId'));
        if (vocabularyListItem.evaluate().isNotEmpty) {
          await tester.tap(vocabularyListItem);
          await tester.pumpAndSettle();

          final randomModeButton = find.byKey(const Key('random_mode_button'));
          await tester.tap(randomModeButton);
          await tester.pumpAndSettle();

          // 学习一个单词
          await tester.tap(find.byKey(const Key('show_answer_button')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('known_button')));
          await tester.pumpAndSettle();

          // 获取学习进度
          final progressList = await database.getProgressByListId(testListId);
          final learnedProgress = progressList.where((p) => p.status != LearningStatus.notLearned).toList();

          // 验证记忆级别为1
          expect(learnedProgress.isNotEmpty, true);
          expect(learnedProgress.first.memoryLevel, equals(1));

          // 验证下次复习时间已设置（1天后）
          expect(learnedProgress.first.nextReviewAt, isNotNull);
          final expectedReviewTime = DateTime.now().add(const Duration(days: 1));
          final actualReviewTime = learnedProgress.first.nextReviewAt!;
          final timeDifference = actualReviewTime.difference(expectedReviewTime).inHours.abs();
          expect(timeDifference, lessThan(1)); // 允许1小时误差
        }
      }
    });
  });
}
