# Task 9.13 实现文档 - LearningManager 学习管理器

## 任务信息

- **任务编号**: 9.13
- **任务名称**: 实现LearningManager - 学习管理器
- **实施日期**: 2024
- **实施状态**: 已完成

## 实现概述

LearningManager 是 AI 背单词应用的核心业务管理器之一，负责管理学习会话和学习进度的更新。

### 文件位置

- **实现文件**: `app/lib/managers/learning_manager.dart`
- **依赖文件**:
  - `app/lib/database/local_database.dart` - 本地数据库访问
  - `app/lib/algorithms/random_learning_algorithm.dart` - 随机学习算法
  - `app/lib/algorithms/sequential_learning_algorithm.dart` - 顺序学习算法
  - `app/lib/algorithms/memory_curve_algorithm.dart` - 记忆曲线算法
  - `app/lib/models/word.dart` - 单词模型
  - `app/lib/models/user_word_progress.dart` - 学习进度模型

## 核心功能实现

### 1. 学习模式支持

实现了两种学习模式：

```dart
enum LearningMode {
  random,      // 随机学习模式
  sequential,  // 顺序学习模式
}
```

### 2. 学习会话管理

#### LearningSession 类

学习会话类记录一次学习活动的状态：

- `listId`: 词表ID
- `mode`: 学习模式（随机/顺序）
- `startTime`: 开始时间
- `learnedWordIds`: 已学习的单词ID列表
- `knownWordIds`: 认识的单词ID列表
- `unknownWordIds`: 不认识的单词ID列表
- `currentIndex`: 当前索引（用于顺序学习）

#### LearningStatistics 类

学习统计类记录学习会话的统计信息：

- `totalWordsLearned`: 总学习单词数
- `knownWordsCount`: 认识的单词数
- `unknownWordsCount`: 不认识的单词数
- `duration`: 学习时长

### 3. 核心方法实现

#### startLearningSession()

开始学习会话：

1. 检查是否已有进行中的会话
2. 验证词表是否存在
3. 检查是否有可学习的单词
4. 创建并返回学习会话对象

**验证需求**: 7.1, 8.1

#### getNextWord()

获取下一个单词：

1. 验证会话有效性
2. 获取已排除的单词ID列表
3. 根据学习模式调用相应算法：
   - 随机模式：调用 `RandomLearningAlgorithm.getRandomUnlearnedWord()`
   - 顺序模式：调用 `SequentialLearningAlgorithm.getNextSequentialWord()`
4. 返回单词对象或 null（无更多单词）

**验证需求**: 7.1, 7.2, 8.1, 8.2

#### markWordAsKnown()

标记单词为认识：

1. 检查是否已有学习进度
2. 更新学习进度：
   - 状态：`LearningStatus.mastered`（已掌握）
   - 记忆级别：1
   - 下次复习时间：当前时间 + 1天
   - 复习次数：+1
3. 保存到数据库
4. 更新会话统计

**验证需求**: 7.5, 8.6

#### markWordAsUnknown()

标记单词为不认识：

1. 检查是否已有学习进度
2. 更新学习进度：
   - 状态：`LearningStatus.needReview`（需复习）
   - 记忆级别：1
   - 下次复习时间：当前时间 + 1天
   - 复习次数：+1
   - 错误次数：+1
3. 保存到数据库
4. 更新会话统计

**验证需求**: 7.6, 8.7

#### endLearningSession()

结束学习会话：

1. 验证会话有效性
2. 计算学习时长
3. 创建学习统计对象
4. 清除当前会话
5. 返回统计信息

**验证需求**: 7.8, 8.9

### 4. 辅助方法

#### getCurrentSession()

获取当前进行中的学习会话。

#### getLearningProgress()

计算并返回词表的学习进度百分比（0.0-100.0）。

**验证需求**: 8.2, 12.6

#### getUnlearnedWordCount()

获取未学习的单词数量。

#### getMasteredWordCount()

获取已掌握的单词数量。

#### getNeedReviewWordCount()

获取需复习的单词数量。

## 记忆曲线算法集成

LearningManager 集成了记忆曲线算法，实现智能复习时间计算：

### 记忆级别和复习间隔

- 级别 0（未学习）→ 级别 1：1天后复习
- 级别 1 → 级别 2：2天后复习
- 级别 2 → 级别 3：4天后复习
- 级别 3 → 级别 4：7天后复习
- 级别 4 → 级别 5：15天后复习

### 状态转换规则

1. **首次学习 - 选择"认识"**:
   - 状态：未学习 → 已掌握
   - 记忆级别：0 → 1
   - 下次复习：1天后

2. **首次学习 - 选择"不认识"**:
   - 状态：未学习 → 需复习
   - 记忆级别：0 → 1
   - 错误次数：+1
   - 下次复习：1天后

3. **复习时 - 选择"记得"**:
   - 记忆级别：+1（最高5）
   - 下次复习：根据新级别计算

4. **复习时 - 选择"忘记"**:
   - 记忆级别：重置为1
   - 错误次数：+1
   - 下次复习：1天后

## 数据持久化

所有学习进度数据通过 `LocalDatabase` 持久化到本地 SQLite 数据库：

- 表名：`user_word_progress`
- 同步状态：标记为 `'pending'`，等待后续同步到服务器

## 错误处理

实现了完善的错误处理机制：

1. **会话冲突检查**: 防止同时开启多个学习会话
2. **词表验证**: 确保词表存在
3. **单词可用性检查**: 确保有可学习的单词
4. **会话有效性验证**: 所有操作前验证会话有效性

## 需求覆盖

### 需求 7: 随机学习模式

- ✅ 7.1: 随机抽取未学习的单词
- ✅ 7.2: 显示单词，隐藏释义（UI层实现）
- ✅ 7.3: 显示答案（UI层实现）
- ✅ 7.4: 提供"认识"和"不认识"选项（UI层实现）
- ✅ 7.5: 选择"认识"标记为已掌握
- ✅ 7.6: 选择"不认识"标记为需复习
- ✅ 7.7: 自动加载下一个单词（通过getNextWord实现）
- ✅ 7.8: 显示学习统计（通过endLearningSession实现）

### 需求 8: 顺序学习模式

- ✅ 8.1: 按顺序显示未学习的单词
- ✅ 8.2: 显示学习进度（通过getLearningProgress实现）
- ✅ 8.3: 显示单词，隐藏释义（UI层实现）
- ✅ 8.4: 显示答案（UI层实现）
- ✅ 8.5: 提供"认识"和"不认识"选项（UI层实现）
- ✅ 8.6: 选择"认识"标记为已掌握
- ✅ 8.7: 选择"不认识"标记为需复习
- ✅ 8.8: 自动加载下一个单词（通过getNextWord实现）
- ✅ 8.9: 显示学习统计（通过endLearningSession实现）

## 代码质量

### 代码规范

- ✅ 遵循 Dart 官方代码规范
- ✅ 使用清晰的命名约定
- ✅ 完整的文档注释
- ✅ 合理的错误处理

### 静态分析

```bash
flutter analyze lib/managers/learning_manager.dart
```

结果：**No issues found!**

## 使用示例

```dart
// 创建学习管理器
final learningManager = LearningManager(
  localDatabase: localDatabase,
);

// 开始随机学习会话
final session = await learningManager.startLearningSession(
  listId,
  LearningMode.random,
);

// 获取下一个单词
final word = await learningManager.getNextWord(session);

if (word != null) {
  // 显示单词给用户
  print('单词: ${word.word}');
  
  // 用户选择"认识"
  await learningManager.markWordAsKnown(word.id, listId);
  
  // 或用户选择"不认识"
  // await learningManager.markWordAsUnknown(word.id, listId);
}

// 结束学习会话
final statistics = await learningManager.endLearningSession(session);
print('学习统计:');
print('总学习单词数: ${statistics.totalWordsLearned}');
print('认识: ${statistics.knownWordsCount}');
print('不认识: ${statistics.unknownWordsCount}');
print('学习时长: ${statistics.duration}');
```

## 后续工作

### 待实现的测试（可选）

根据任务计划，以下测试任务标记为可选：

- [ ] 9.14: 编写LearningManager单元测试
- [ ] 9.15: 编写属性测试 - 学习状态转换正确性

### UI集成

LearningManager 已准备好与 UI 层集成：

- 12.1: 实现学习模式选择页面
- 12.2: 实现学习卡片页面

## 总结

LearningManager 的实现完成了以下目标：

1. ✅ 支持随机和顺序两种学习模式
2. ✅ 完整的学习会话管理
3. ✅ 集成记忆曲线算法
4. ✅ 学习进度持久化
5. ✅ 完善的错误处理
6. ✅ 清晰的代码结构和文档
7. ✅ 符合项目设计规范

该实现为用户提供了灵活的学习方式，并通过记忆曲线算法优化了复习计划，是应用核心功能的重要组成部分。
