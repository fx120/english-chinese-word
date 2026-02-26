# Task 5.2 实现本地数据库访问层 - 实现文档

## 任务概述

实现了完整的本地数据库访问层，包含所有表的CRUD操作。

## 实现内容

### 1. 创建的文件

- `app/lib/models/user_word_exclusion.dart` - 用户单词排除模型

### 2. 修改的文件

- `app/lib/database/local_database.dart` - 实现完整的CRUD操作

## 实现的功能模块

### 词表CRUD操作（需求13.2）
- `insertVocabularyList()` - 插入词表
- `getVocabularyList()` - 根据ID获取词表
- `getAllVocabularyLists()` - 获取所有词表
- `getVocabularyListsByCategory()` - 根据分类获取词表
- `updateVocabularyList()` - 更新词表
- `deleteVocabularyList()` - 删除词表
- `updateVocabularyListWordCount()` - 更新词表单词数量

### 单词CRUD操作（需求13.1, 13.3）
- `insertWord()` - 插入单词（忽略重复）
- `insertOrUpdateWord()` - 插入或更新单词
- `getWord()` - 根据ID获取单词
- `getWordByText()` - 根据单词文本获取单词
- `getWordsByListId()` - 获取词表的所有单词（支持排除已标记的单词）
- `updateWord()` - 更新单词
- `deleteWord()` - 删除单词（物理删除）
- `addWordToList()` - 添加单词到词表
- `removeWordFromList()` - 从词表移除单词关联
- `batchInsertWordsToList()` - 批量插入单词到词表

### 学习进度CRUD操作（需求13.6）
- `insertOrUpdateProgress()` - 插入或更新学习进度
- `getProgress()` - 获取单词在特定词表的学习进度
- `getProgressByListId()` - 获取词表的所有学习进度
- `getDueReviews()` - 获取待复习的单词进度
- `getWrongWords()` - 获取错题（错误次数>0的单词）
- `getUnlearnedWordIds()` - 获取未学习的单词ID列表
- `deleteProgress()` - 删除学习进度

### 排除单词CRUD操作（需求13.5）
- `insertExclusion()` - 添加排除单词
- `deleteExclusion()` - 移除排除标记（恢复单词）
- `getExcludedWordIds()` - 获取词表的所有排除单词ID
- `getExclusionsByListId()` - 获取词表的所有排除单词
- `isWordExcluded()` - 检查单词是否被排除

### 统计数据CRUD操作（需求13.7）
- `updateStatistics()` - 更新统计数据
- `getStatistics()` - 获取统计数据
- `deleteStatistics()` - 删除统计数据

### 每日学习记录CRUD操作（需求13.7）
- `insertDailyRecord()` - 插入每日学习记录
- `getDailyRecord()` - 获取指定日期的学习记录
- `getDailyRecords()` - 获取最近N天的学习记录
- `getAllDailyRecords()` - 获取所有学习记录
- `updateDailyRecord()` - 更新每日学习记录
- `deleteDailyRecord()` - 删除每日学习记录

## 关键设计特性

### 1. 数据完整性
- 使用事务确保批量操作的原子性
- 自动更新词表单词数量
- 使用外键约束保证数据一致性

### 2. 软删除机制
- 单词排除使用`user_word_exclusion`表实现软删除
- 不影响全局单词数据
- 支持恢复已排除的单词

### 3. 查询优化
- `getWordsByListId()`支持排除已标记的单词
- `getDueReviews()`按复习时间排序
- `getWrongWords()`按错误次数降序排序
- 使用JOIN查询提高性能

### 4. 灵活性
- 支持冲突处理策略（ignore/replace）
- 支持可选参数控制查询行为
- 返回类型明确（nullable/non-nullable）

## 数据库表关系

```
vocabulary_list (词表)
    ↓ (1:N)
vocabulary_list_word (词表单词关联)
    ↓ (N:1)
word (单词)
    ↓ (1:N)
user_word_progress (学习进度)
user_word_exclusion (排除单词)
```

## 验证需求覆盖

- ✅ 需求13.1: 存储全局单词数据
- ✅ 需求13.2: 存储词表定义数据
- ✅ 需求13.3: 存储词表与单词的关联关系
- ✅ 需求13.4: 存储用户与词表的关联关系（通过vocabulary_list表）
- ✅ 需求13.5: 存储用户对单词的排除标记
- ✅ 需求13.6: 存储用户对单词的学习进度
- ✅ 需求13.7: 存储用户的学习统计数据
- ✅ 需求13.8: 从本地数据库加载所有数据
- ✅ 需求13.9: 立即更新本地数据库
- ✅ 需求13.10: 确保用户数据与全局数据的分离

## 后续工作

1. 编写单元测试验证所有CRUD操作
2. 编写属性测试验证数据一致性
3. 实现数据同步逻辑
4. 实现数据库迁移策略

## 完成时间

2024年（任务完成）
