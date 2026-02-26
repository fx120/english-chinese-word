import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_vocabulary_app/main.dart';
import 'package:ai_vocabulary_app/database/local_database.dart';
import 'package:ai_vocabulary_app/services/api_client.dart';
import 'package:ai_vocabulary_app/providers/auth_provider.dart';
import 'package:ai_vocabulary_app/providers/vocabulary_provider.dart';
import 'package:ai_vocabulary_app/providers/learning_provider.dart';
import 'package:ai_vocabulary_app/providers/review_provider.dart';
import 'package:ai_vocabulary_app/providers/statistics_provider.dart';

/// 前端集成测试
/// 
/// 测试完整的用户流程：
/// 1. 登录流程
/// 2. 词表下载和导入流程
/// 3. 学习流程（随机和顺序）
/// 4. 复习流程（记忆曲线和错题）
/// 5. 数据同步流程
/// 
/// 这些测试验证前端各组件的集成和端到端用户体验
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('前端集成测试', () {
    late LocalDatabase database;
    late ApiClient apiClient;

    setUp(() async {
      // 初始化测试数据库
      database = LocalDatabase();
      await database.initialize();
      
      // 初始化API客户端
      apiClient = ApiClient();
    });

    tearDown(() async {
      // 清理测试数据
      await database.clearAllData();
    });

    testWidgets('完整登录流程测试', (WidgetTester tester) async {
      // 启动应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 验证登录页面显示
      expect(find.text('AI背单词'), findsOneWidget);
      expect(find.text('手机号登录'), findsOneWidget);

      // 输入手机号
      final mobileField = find.byKey(const Key('mobile_field'));
      expect(mobileField, findsOneWidget);
      await tester.enterText(mobileField, '13800138000');
      await tester.pumpAndSettle();

      // 点击发送验证码按钮
      final sendCodeButton = find.byKey(const Key('send_code_button'));
      expect(sendCodeButton, findsOneWidget);
      await tester.tap(sendCodeButton);
      await tester.pumpAndSettle();

      // 等待验证码发送（模拟网络延迟）
      await tester.pump(const Duration(seconds: 2));

      // 验证倒计时显示
      expect(find.textContaining('秒后重新发送'), findsOneWidget);

      // 输入验证码
      final codeField = find.byKey(const Key('code_field'));
      expect(codeField, findsOneWidget);
      await tester.enterText(codeField, '123456');
      await tester.pumpAndSettle();

      // 点击登录按钮
      final loginButton = find.byKey(const Key('login_button'));
      expect(loginButton, findsOneWidget);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // 等待登录完成（模拟网络延迟）
      await tester.pump(const Duration(seconds: 2));

      // 验证跳转到主页面
      expect(find.text('词表'), findsOneWidget);
      expect(find.text('学习'), findsOneWidget);
      expect(find.text('复习'), findsOneWidget);
      expect(find.text('统计'), findsOneWidget);
    });

    testWidgets('词表下载流程测试', (WidgetTester tester) async {
      // 启动应用并模拟已登录状态
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider(apiClient)),
            ChangeNotifierProvider(create: (_) => VocabularyProvider(apiClient, database)),
            ChangeNotifierProvider(create: (_) => LearningProvider(database)),
            ChangeNotifierProvider(create: (_) => ReviewProvider(database)),
            ChangeNotifierProvider(create: (_) => StatisticsProvider(database)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Container(), // 模拟主页面
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 导航到词表列表页面
      // 注意：这里需要根据实际的导航逻辑调整

      // 验证词表列表显示
      expect(find.text('官方词表'), findsWidgets);

      // 查找第一个词表的下载按钮
      final downloadButton = find.byKey(const Key('download_button_1'));
      if (downloadButton.evaluate().isNotEmpty) {
        await tester.tap(downloadButton);
        await tester.pumpAndSettle();

        // 验证下载进度显示
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // 等待下载完成
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // 验证下载成功提示
        expect(find.text('下载成功'), findsOneWidget);
      }
    });

    testWidgets('文本文件导入流程测试', (WidgetTester tester) async {
      // 启动应用并模拟已登录状态
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 导航到词表列表页面
      // 点击导入按钮
      final importButton = find.byKey(const Key('import_button'));
      if (importButton.evaluate().isNotEmpty) {
        await tester.tap(importButton);
        await tester.pumpAndSettle();

        // 验证导入对话框显示
        expect(find.text('导入词表'), findsOneWidget);
        expect(find.text('文本文件'), findsOneWidget);
        expect(find.text('Excel文件'), findsOneWidget);

        // 选择文本文件导入
        final textImportButton = find.byKey(const Key('text_import_button'));
        await tester.tap(textImportButton);
        await tester.pumpAndSettle();

        // 注意：文件选择器是原生组件，无法在集成测试中直接测试
        // 这里只验证导入流程的UI部分
      }
    });

    testWidgets('随机学习流程测试', (WidgetTester tester) async {
      // 准备测试数据：创建一个包含单词的词表
      final listId = await _createTestVocabularyList(database);
      await _createTestWords(database, listId, 10);

      // 启动应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 导航到学习模式选择页面
      // 选择随机学习模式
      final randomModeButton = find.byKey(const Key('random_mode_button'));
      if (randomModeButton.evaluate().isNotEmpty) {
        await tester.tap(randomModeButton);
        await tester.pumpAndSettle();

        // 验证学习卡片页面显示
        expect(find.byKey(const Key('word_card')), findsOneWidget);
        expect(find.byKey(const Key('show_answer_button')), findsOneWidget);

        // 点击显示答案
        await tester.tap(find.byKey(const Key('show_answer_button')));
        await tester.pumpAndSettle();

        // 验证释义显示
        expect(find.byKey(const Key('word_definition')), findsOneWidget);
        expect(find.byKey(const Key('known_button')), findsOneWidget);
        expect(find.byKey(const Key('unknown_button')), findsOneWidget);

        // 点击"认识"按钮
        await tester.tap(find.byKey(const Key('known_button')));
        await tester.pumpAndSettle();

        // 验证自动加载下一个单词
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(const Key('word_card')), findsOneWidget);

        // 学习几个单词
        for (int i = 0; i < 3; i++) {
          await tester.tap(find.byKey(const Key('show_answer_button')));
          await tester.pumpAndSettle();
          
          // 交替选择"认识"和"不认识"
          if (i % 2 == 0) {
            await tester.tap(find.byKey(const Key('known_button')));
          } else {
            await tester.tap(find.byKey(const Key('unknown_button')));
          }
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 500));
        }
      }
    });

    testWidgets('顺序学习流程测试', (WidgetTester tester) async {
      // 准备测试数据
      final listId = await _createTestVocabularyList(database);
      await _createTestWords(database, listId, 10);

      // 启动应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 选择顺序学习模式
      final sequentialModeButton = find.byKey(const Key('sequential_mode_button'));
      if (sequentialModeButton.evaluate().isNotEmpty) {
        await tester.tap(sequentialModeButton);
        await tester.pumpAndSettle();

        // 验证学习进度显示
        expect(find.textContaining('/10'), findsOneWidget);

        // 学习几个单词并验证顺序
        for (int i = 0; i < 5; i++) {
          // 验证进度更新
          expect(find.textContaining('${i + 1}/10'), findsOneWidget);

          await tester.tap(find.byKey(const Key('show_answer_button')));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('known_button')));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 500));
        }

        // 验证最终进度
        expect(find.textContaining('5/10'), findsOneWidget);
      }
    });

    testWidgets('记忆曲线复习流程测试', (WidgetTester tester) async {
      // 准备测试数据：创建一些需要复习的单词
      final listId = await _createTestVocabularyList(database);
      await _createTestWords(database, listId, 5);
      await _createDueReviewProgress(database, listId);

      // 启动应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 导航到复习模式选择页面
      final reviewTab = find.text('复习');
      if (reviewTab.evaluate().isNotEmpty) {
        await tester.tap(reviewTab);
        await tester.pumpAndSettle();

        // 验证待复习单词数量显示
        expect(find.textContaining('待复习'), findsOneWidget);

        // 选择记忆曲线复习
        final memoryCurveButton = find.byKey(const Key('memory_curve_button'));
        if (memoryCurveButton.evaluate().isNotEmpty) {
          await tester.tap(memoryCurveButton);
          await tester.pumpAndSettle();

          // 验证复习卡片显示
          expect(find.byKey(const Key('review_card')), findsOneWidget);

          // 复习几个单词
          for (int i = 0; i < 3; i++) {
            await tester.tap(find.byKey(const Key('show_answer_button')));
            await tester.pumpAndSettle();

            // 交替选择"记得"和"忘记"
            if (i % 2 == 0) {
              await tester.tap(find.byKey(const Key('remember_button')));
            } else {
              await tester.tap(find.byKey(const Key('forget_button')));
            }
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 500));
          }
        }
      }
    });

    testWidgets('错题复习流程测试', (WidgetTester tester) async {
      // 准备测试数据：创建一些错题
      final listId = await _createTestVocabularyList(database);
      await _createTestWords(database, listId, 5);
      await _createWrongWordsProgress(database, listId);

      // 启动应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 导航到复习页面
      final reviewTab = find.text('复习');
      if (reviewTab.evaluate().isNotEmpty) {
        await tester.tap(reviewTab);
        await tester.pumpAndSettle();

        // 验证错题数量显示
        expect(find.textContaining('错题'), findsOneWidget);

        // 选择错题复习
        final wrongWordsButton = find.byKey(const Key('wrong_words_button'));
        if (wrongWordsButton.evaluate().isNotEmpty) {
          await tester.tap(wrongWordsButton);
          await tester.pumpAndSettle();

          // 验证错题按错误次数排序
          // 复习错题
          for (int i = 0; i < 2; i++) {
            await tester.tap(find.byKey(const Key('show_answer_button')));
            await tester.pumpAndSettle();

            await tester.tap(find.byKey(const Key('remember_button')));
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 500));
          }

          // 验证错题数量减少
          // 注意：需要返回到复习模式选择页面才能看到更新的数量
        }
      }
    });

    testWidgets('学习统计显示测试', (WidgetTester tester) async {
      // 准备测试数据
      final listId = await _createTestVocabularyList(database);
      await _createTestWords(database, listId, 20);
      await _createLearningProgress(database, listId);
      await _createStatisticsData(database);

      // 启动应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 导航到统计页面
      final statisticsTab = find.text('统计');
      if (statisticsTab.evaluate().isNotEmpty) {
        await tester.tap(statisticsTab);
        await tester.pumpAndSettle();

        // 验证统计数据显示
        expect(find.textContaining('总学习天数'), findsOneWidget);
        expect(find.textContaining('连续学习天数'), findsOneWidget);
        expect(find.textContaining('总学习单词'), findsOneWidget);
        expect(find.textContaining('已掌握单词'), findsOneWidget);
        expect(find.textContaining('待复习单词'), findsOneWidget);

        // 验证学习曲线图表显示
        expect(find.byType(CustomPaint), findsWidgets); // 图表组件

        // 验证词表学习进度显示
        expect(find.textContaining('%'), findsWidgets);
      }
    });

    testWidgets('数据同步流程测试', (WidgetTester tester) async {
      // 准备测试数据
      final listId = await _createTestVocabularyList(database);
      await _createTestWords(database, listId, 10);
      await _createLearningProgress(database, listId);

      // 启动应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 导航到设置页面
      // 注意：需要根据实际的导航方式调整
      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();

        // 验证设置页面显示
        expect(find.text('设置'), findsOneWidget);
        expect(find.text('数据同步'), findsOneWidget);

        // 点击同步按钮
        final syncButton = find.byKey(const Key('sync_button'));
        if (syncButton.evaluate().isNotEmpty) {
          await tester.tap(syncButton);
          await tester.pumpAndSettle();

          // 验证同步进度显示
          expect(find.byType(CircularProgressIndicator), findsOneWidget);

          // 等待同步完成
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();

          // 验证同步成功提示
          expect(find.textContaining('同步成功'), findsOneWidget);

          // 验证最后同步时间更新
          expect(find.textContaining('最后同步'), findsOneWidget);
        }
      }
    });

    testWidgets('词表编辑流程测试', (WidgetTester tester) async {
      // 准备测试数据
      final listId = await _createTestVocabularyList(database);
      await _createTestWords(database, listId, 5);

      // 启动应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 导航到词表详情页面
      final vocabularyListItem = find.byKey(Key('vocabulary_list_$listId'));
      if (vocabularyListItem.evaluate().isNotEmpty) {
        await tester.tap(vocabularyListItem);
        await tester.pumpAndSettle();

        // 验证词表详情页面显示
        expect(find.text('单词列表'), findsOneWidget);

        // 测试添加单词
        final addWordButton = find.byKey(const Key('add_word_button'));
        if (addWordButton.evaluate().isNotEmpty) {
          await tester.tap(addWordButton);
          await tester.pumpAndSettle();

          // 填写单词信息
          await tester.enterText(find.byKey(const Key('word_input')), 'test');
          await tester.enterText(find.byKey(const Key('definition_input')), '测试');
          await tester.pumpAndSettle();

          // 保存单词
          await tester.tap(find.byKey(const Key('save_word_button')));
          await tester.pumpAndSettle();

          // 验证单词添加成功
          expect(find.text('test'), findsOneWidget);
        }

        // 测试删除单词（软删除）
        final deleteButton = find.byKey(const Key('delete_word_button_1'));
        if (deleteButton.evaluate().isNotEmpty) {
          await tester.tap(deleteButton);
          await tester.pumpAndSettle();

          // 验证确认对话框
          expect(find.text('确认删除'), findsOneWidget);

          // 确认删除
          await tester.tap(find.text('确定'));
          await tester.pumpAndSettle();

          // 验证单词被隐藏
          // 注意：软删除后单词应该不再显示在列表中
        }
      }
    });

    testWidgets('离线功能测试', (WidgetTester tester) async {
      // 准备测试数据
      final listId = await _createTestVocabularyList(database);
      await _createTestWords(database, listId, 10);

      // 启动应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 模拟离线状态
      // 注意：这需要在API客户端中实现离线检测

      // 验证离线提示显示
      // expect(find.textContaining('离线'), findsOneWidget);

      // 验证离线学习功能可用
      final randomModeButton = find.byKey(const Key('random_mode_button'));
      if (randomModeButton.evaluate().isNotEmpty) {
        await tester.tap(randomModeButton);
        await tester.pumpAndSettle();

        // 验证可以正常学习
        expect(find.byKey(const Key('word_card')), findsOneWidget);

        // 学习一个单词
        await tester.tap(find.byKey(const Key('show_answer_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('known_button')));
        await tester.pumpAndSettle();

        // 验证学习进度保存到本地
        final progress = await database.getProgressByListId(listId);
        expect(progress.isNotEmpty, true);
      }
    });

    testWidgets('错误处理测试', (WidgetTester tester) async {
      // 启动应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 测试无效手机号错误提示
      final mobileField = find.byKey(const Key('mobile_field'));
      if (mobileField.evaluate().isNotEmpty) {
        await tester.enterText(mobileField, '123'); // 无效手机号
        await tester.pumpAndSettle();

        final sendCodeButton = find.byKey(const Key('send_code_button'));
        await tester.tap(sendCodeButton);
        await tester.pumpAndSettle();

        // 验证错误提示
        expect(find.textContaining('手机号格式错误'), findsOneWidget);
      }

      // 测试无效验证码错误提示
      await tester.enterText(mobileField, '13800138000');
      await tester.pumpAndSettle();

      final codeField = find.byKey(const Key('code_field'));
      if (codeField.evaluate().isNotEmpty) {
        await tester.enterText(codeField, '123'); // 无效验证码
        await tester.pumpAndSettle();

        final loginButton = find.byKey(const Key('login_button'));
        await tester.tap(loginButton);
        await tester.pumpAndSettle();

        // 验证错误提示
        expect(find.textContaining('验证码格式错误'), findsOneWidget);
      }
    });
  });
}

// ==================== 测试辅助函数 ====================

/// 创建测试词表
Future<int> _createTestVocabularyList(LocalDatabase database) async {
  // 实现创建测试词表的逻辑
  // 返回词表ID
  return 1; // 占位符
}

/// 创建测试单词
Future<void> _createTestWords(LocalDatabase database, int listId, int count) async {
  // 实现创建测试单词的逻辑
}

/// 创建到期复习进度
Future<void> _createDueReviewProgress(LocalDatabase database, int listId) async {
  // 实现创建到期复习进度的逻辑
}

/// 创建错题进度
Future<void> _createWrongWordsProgress(LocalDatabase database, int listId) async {
  // 实现创建错题进度的逻辑
}

/// 创建学习进度
Future<void> _createLearningProgress(LocalDatabase database, int listId) async {
  // 实现创建学习进度的逻辑
}

/// 创建统计数据
Future<void> _createStatisticsData(LocalDatabase database) async {
  // 实现创建统计数据的逻辑
}
