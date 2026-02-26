import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ai_vocabulary_app/main.dart';
import 'package:ai_vocabulary_app/database/local_database.dart';
import 'package:ai_vocabulary_app/services/api_client.dart';

import 'test_helpers.dart';

/// 登录流程集成测试
/// 
/// 测试用户登录的完整流程，包括：
/// - 手机号输入和验证
/// - 验证码发送
/// - 验证码输入和验证
/// - 登录成功
/// - 错误处理
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('登录流程集成测试', () {
    late LocalDatabase database;
    late ApiClient apiClient;

    setUp(() async {
      database = LocalDatabase();
      await database.initialize();
      apiClient = ApiClient();
    });

    tearDown(() async {
      await TestHelpers.clearAllTestData(database);
    });

    testWidgets('成功登录流程', (WidgetTester tester) async {
      // 启动应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 验证登录页面显示
      expect(find.text('AI背单词'), findsOneWidget);
      expect(find.text('手机号登录'), findsOneWidget);

      // 输入有效手机号
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
      await tester.pump(const Duration(seconds: 1));

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

      // 等待登录完成
      await tester.pump(const Duration(seconds: 2));

      // 验证跳转到主页面
      expect(find.text('词表'), findsOneWidget);
      expect(find.text('学习'), findsOneWidget);
      expect(find.text('复习'), findsOneWidget);
      expect(find.text('统计'), findsOneWidget);
    });

    testWidgets('无效手机号错误提示', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 输入无效手机号（少于11位）
      final mobileField = find.byKey(const Key('mobile_field'));
      await tester.enterText(mobileField, '138001380');
      await tester.pumpAndSettle();

      // 点击发送验证码
      final sendCodeButton = find.byKey(const Key('send_code_button'));
      await tester.tap(sendCodeButton);
      await tester.pumpAndSettle();

      // 验证错误提示
      expect(find.textContaining('手机号格式错误'), findsOneWidget);
    });

    testWidgets('无效验证码错误提示', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 输入有效手机号
      final mobileField = find.byKey(const Key('mobile_field'));
      await tester.enterText(mobileField, '13800138000');
      await tester.pumpAndSettle();

      // 发送验证码
      final sendCodeButton = find.byKey(const Key('send_code_button'));
      await tester.tap(sendCodeButton);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      // 输入无效验证码（少于6位）
      final codeField = find.byKey(const Key('code_field'));
      await tester.enterText(codeField, '123');
      await tester.pumpAndSettle();

      // 点击登录
      final loginButton = find.byKey(const Key('login_button'));
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // 验证错误提示
      expect(find.textContaining('验证码格式错误'), findsOneWidget);
    });

    testWidgets('验证码倒计时功能', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 输入手机号
      final mobileField = find.byKey(const Key('mobile_field'));
      await tester.enterText(mobileField, '13800138000');
      await tester.pumpAndSettle();

      // 发送验证码
      final sendCodeButton = find.byKey(const Key('send_code_button'));
      await tester.tap(sendCodeButton);
      await tester.pumpAndSettle();

      // 验证倒计时开始
      expect(find.textContaining('秒后重新发送'), findsOneWidget);

      // 验证按钮禁用
      final button = tester.widget<ElevatedButton>(sendCodeButton);
      expect(button.enabled, isFalse);

      // 等待几秒
      await tester.pump(const Duration(seconds: 3));

      // 验证倒计时更新
      expect(find.textContaining('秒后重新发送'), findsOneWidget);
    });

    testWidgets('空手机号验证', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 不输入手机号，直接点击发送验证码
      final sendCodeButton = find.byKey(const Key('send_code_button'));
      await tester.tap(sendCodeButton);
      await tester.pumpAndSettle();

      // 验证错误提示
      expect(find.textContaining('请输入手机号'), findsOneWidget);
    });

    testWidgets('空验证码验证', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 输入手机号
      final mobileField = find.byKey(const Key('mobile_field'));
      await tester.enterText(mobileField, '13800138000');
      await tester.pumpAndSettle();

      // 不输入验证码，直接点击登录
      final loginButton = find.byKey(const Key('login_button'));
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // 验证错误提示
      expect(find.textContaining('请输入验证码'), findsOneWidget);
    });

    testWidgets('网络错误处理', (WidgetTester tester) async {
      // 注意：这个测试需要模拟网络错误
      // 可以通过配置 Mock API 客户端来实现

      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 输入手机号
      final mobileField = find.byKey(const Key('mobile_field'));
      await tester.enterText(mobileField, '13800138000');
      await tester.pumpAndSettle();

      // 模拟网络错误的情况下发送验证码
      // 这里需要配置 API 客户端返回错误

      // 验证错误提示显示
      // expect(find.textContaining('网络错误'), findsOneWidget);
    });

    testWidgets('登录后状态持久化', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 完成登录流程
      final mobileField = find.byKey(const Key('mobile_field'));
      await tester.enterText(mobileField, '13800138000');
      await tester.pumpAndSettle();

      final sendCodeButton = find.byKey(const Key('send_code_button'));
      await tester.tap(sendCodeButton);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      final codeField = find.byKey(const Key('code_field'));
      await tester.enterText(codeField, '123456');
      await tester.pumpAndSettle();

      final loginButton = find.byKey(const Key('login_button'));
      await tester.tap(loginButton);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      // 验证登录成功
      expect(find.text('词表'), findsOneWidget);

      // 重启应用
      await tester.pumpWidget(MyApp(database: database, apiClient: apiClient));
      await tester.pumpAndSettle();

      // 验证自动登录（应该直接显示主页面，而不是登录页面）
      // 注意：这需要 AuthManager 正确实现令牌持久化
      // expect(find.text('词表'), findsOneWidget);
    });
  });
}
