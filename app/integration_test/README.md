# Flutter 前端集成测试

## 概述

本目录包含 AI背单词应用的 Flutter 前端集成测试。这些测试验证端到端的用户工作流程，确保各组件正确集成和协同工作。

## 测试文件结构

```
integration_test/
├── README.md                  # 本文件
├── test_helpers.dart          # 测试辅助工具类
├── app_test.dart              # 主集成测试文件（综合测试）
├── login_flow_test.dart       # 登录流程测试
├── learning_flow_test.dart    # 学习流程测试
└── review_flow_test.dart      # 复习流程测试
```

## 测试覆盖范围

### 1. 登录流程测试 (`login_flow_test.dart`)
- ✅ 成功登录流程
- ✅ 无效手机号错误提示
- ✅ 无效验证码错误提示
- ✅ 验证码倒计时功能
- ✅ 空输入验证
- ✅ 网络错误处理
- ✅ 登录状态持久化

### 2. 学习流程测试 (`learning_flow_test.dart`)
- ✅ 随机学习模式完整流程
- ✅ 顺序学习模式完整流程
- ✅ 学习会话统计
- ✅ 学习进度持久化
- ✅ 空词表错误处理
- ✅ 学习完成提示
- ✅ 学习中断和恢复
- ✅ 记忆级别正确更新

### 3. 复习流程测试 (`review_flow_test.dart`)
- ✅ 记忆曲线复习完整流程
- ✅ 错题复习完整流程
- ✅ 记忆级别升级
- ✅ 记忆级别重置
- ✅ 错题按错误次数排序
- ✅ 复习统计显示
- ✅ 无复习单词提示
- ✅ 复习进度持久化
- ✅ 复习计数更新

### 4. 综合测试 (`app_test.dart`)
- ✅ 完整用户流程
- ✅ 词表下载和导入
- ✅ 数据同步
- ✅ 词表编辑
- ✅ 学习统计
- ✅ 离线功能
- ✅ 错误处理

## 运行测试

### 前提条件

1. 安装 Flutter SDK
2. 配置开发环境
3. 连接测试设备或启动模拟器

### 运行所有集成测试

```bash
cd app
flutter test integration_test/
```

### 运行特定测试文件

```bash
# 运行登录流程测试
flutter test integration_test/login_flow_test.dart

# 运行学习流程测试
flutter test integration_test/learning_flow_test.dart

# 运行复习流程测试
flutter test integration_test/review_flow_test.dart

# 运行综合测试
flutter test integration_test/app_test.dart
```

### 在真实设备上运行

```bash
# 列出可用设备
flutter devices

# 在特定设备上运行
flutter test integration_test/app_test.dart --device-id=<device_id>
```

### 生成测试覆盖率报告

```bash
# 运行测试并生成覆盖率数据
flutter test integration_test/ --coverage

# 查看覆盖率报告
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 测试辅助工具

### TestHelpers 类

`test_helpers.dart` 提供了一系列辅助方法来简化测试数据的创建和验证：

#### 数据创建方法

```dart
// 创建测试词表
final listId = await TestHelpers.createTestVocabularyList(
  database,
  name: '测试词表',
  wordCount: 20,
);

// 创建测试单词
final wordIds = await TestHelpers.createTestWords(database, listId, 20);

// 创建到期复习进度
await TestHelpers.createDueReviewProgress(database, listId, wordIds);

// 创建错题进度
await TestHelpers.createWrongWordsProgress(database, listId, wordIds);

// 创建学习进度
await TestHelpers.createLearningProgress(database, listId, wordIds);

// 创建统计数据
await TestHelpers.createStatisticsData(database);
```

#### 数据验证方法

```dart
// 验证词表是否存在
final exists = await TestHelpers.vocabularyListExists(database, listId);

// 获取单词数量
final wordCount = await TestHelpers.getWordCount(database, listId);

// 获取已掌握单词数量
final masteredCount = await TestHelpers.getMasteredWordCount(database, listId);

// 获取需复习单词数量
final needReviewCount = await TestHelpers.getNeedReviewWordCount(database, listId);

// 获取未学习单词数量
final notLearnedCount = await TestHelpers.getNotLearnedWordCount(database, listId);

// 获取到期复习单词数量
final dueReviewCount = await TestHelpers.getDueReviewWordCount(database, listId);
```

#### 数据清理方法

```dart
// 清理所有测试数据
await TestHelpers.clearAllTestData(database);
```

## 测试最佳实践

### 1. 测试数据隔离

每个测试应该使用独立的测试数据，避免测试之间的相互影响：

```dart
setUp(() async {
  database = LocalDatabase();
  await database.initialize();
  // 创建测试数据
});

tearDown() async {
  await TestHelpers.clearAllTestData(database);
});
```

### 2. 异步操作处理

正确处理异步操作和动画：

```dart
// 等待所有动画完成
await tester.pumpAndSettle();

// 手动推进帧
await tester.pump(const Duration(milliseconds: 500));

// 等待特定时长
await tester.pump(const Duration(seconds: 2));
```

### 3. Widget 查找

使用合适的查找方法：

```dart
// 使用 Key 查找（推荐）
final button = find.byKey(const Key('login_button'));

// 使用文本查找
final text = find.text('登录');

// 使用类型查找
final backButton = find.byType(BackButton);

// 使用包含文本查找
final message = find.textContaining('成功');
```

### 4. 用户交互模拟

模拟真实的用户操作：

```dart
// 点击
await tester.tap(find.byKey(const Key('button')));

// 输入文本
await tester.enterText(find.byKey(const Key('field')), 'text');

// 滑动
await tester.drag(find.byType(ListView), const Offset(0, -300));

// 长按
await tester.longPress(find.byKey(const Key('item')));
```

### 5. 状态验证

验证 UI 和数据状态：

```dart
// 验证 Widget 存在
expect(find.text('成功'), findsOneWidget);

// 验证 Widget 不存在
expect(find.text('错误'), findsNothing);

// 验证数据库状态
final progress = await database.getProgress(wordId, listId);
expect(progress, isNotNull);
expect(progress!.memoryLevel, equals(1));
```

## 已知限制

### 1. 原生组件

某些原生组件无法在集成测试中直接测试：

- **文件选择器**: 无法模拟文件选择，只能测试选择后的处理逻辑
- **相机和相册**: 无法模拟拍照和选择图片
- **系统对话框**: 某些系统级对话框无法交互

**解决方案**: 使用模拟数据测试这些功能的处理逻辑

### 2. 网络请求

集成测试中的网络请求需要特殊处理：

- 使用 Mock API 客户端
- 使用测试服务器
- 模拟网络响应

### 3. 第三方服务

避免在测试中调用真实的第三方服务：

- 短信服务需要模拟
- OCR 服务需要模拟
- 支付服务需要模拟

## 故障排除

### 测试超时

如果测试超时，可以增加超时时间：

```dart
testWidgets('test name', (WidgetTester tester) async {
  // ...
}, timeout: const Timeout(Duration(minutes: 5)));
```

### Widget 未找到

如果找不到 Widget，检查：

1. Widget 是否已渲染（使用 `pumpAndSettle()`）
2. Key 是否正确
3. Widget 是否在当前页面

### 数据库错误

如果遇到数据库错误：

1. 确保数据库已初始化
2. 检查数据库路径
3. 清理旧的测试数据

### 状态不一致

如果状态不一致：

1. 检查 Provider 是否正确配置
2. 验证数据持久化逻辑
3. 确保测试数据隔离

## 持续集成

### GitHub Actions 示例

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter test integration_test/
```

## 贡献指南

### 添加新测试

1. 在适当的测试文件中添加新的测试用例
2. 使用描述性的测试名称
3. 添加必要的注释
4. 确保测试可以独立运行
5. 更新本 README 文件

### 测试命名规范

```dart
testWidgets('功能描述 - 测试场景', (WidgetTester tester) async {
  // 测试代码
});
```

### 代码风格

- 遵循 Dart 代码风格指南
- 使用有意义的变量名
- 添加必要的注释
- 保持测试简洁明了

## 参考资料

- [Flutter Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Flutter Test Package](https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html)
- [Integration Test Package](https://pub.dev/packages/integration_test)
- [项目需求文档](../../doc/requirements.md)
- [项目设计文档](../../doc/design.md)
- [测试实施文档](../../doc/task-15.2-frontend-integration-tests.md)

## 联系方式

如有问题或建议，请联系开发团队或提交 Issue。
