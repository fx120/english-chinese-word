# 任务 3.1 实施文档 - 后端数据模型类实现

## 任务概述

**任务ID**: 3.1  
**任务名称**: 实现后端数据模型类  
**完成时间**: 2024-01-15  
**状态**: 已完成

## 实施内容

### 创建的模型文件

在 `www.jpwenku.com/application/api/model/` 目录下创建了以下9个模型类：

#### 1. User.php - 用户模型
- **位置**: `www.jpwenku.com/application/api/model/User.php`
- **说明**: 扩展通用用户模型，添加API特定的方法
- **关系定义**:
  - 与词表的多对多关系 (vocabularyLists)
  - 与学习进度的一对多关系 (wordProgress)
  - 与排除单词的一对多关系 (wordExclusions)
  - 与统计数据的一对一关系 (statistics)
- **核心方法**:
  - `getByMobile()`: 根据手机号获取用户
  - `createOrGet()`: 创建或获取用户

#### 2. Word.php - 全局单词模型
- **位置**: `www.jpwenku.com/application/api/model/Word.php`
- **说明**: 存储全局共享的单词数据，避免重复存储
- **关系定义**:
  - 与词表的多对多关系 (vocabularyLists)
  - 与用户学习进度的一对多关系 (userProgress)
  - 与用户排除记录的一对多关系 (userExclusions)
- **核心方法**:
  - `findOrCreate()`: 根据单词文本查找或创建单词
  - `batchFindOrCreate()`: 批量查找或创建单词

#### 3. VocabularyList.php - 词表定义模型
- **位置**: `www.jpwenku.com/application/api/model/VocabularyList.php`
- **说明**: 存储词表的元信息，包括官方词表和用户自定义词表
- **关系定义**:
  - 与单词的多对多关系 (words)
  - 与用户的多对多关系 (users)
  - 与词表单词关联的一对多关系 (listWords)
  - 与用户词表关联的一对多关系 (userLists)
  - 与用户学习进度的一对多关系 (userProgress)
  - 与用户排除记录的一对多关系 (userExclusions)
- **核心方法**:
  - `getWordCount()`: 获取词表的单词数量
  - `updateWordCount()`: 更新词表的单词数量

#### 4. VocabularyListWord.php - 词表单词关联模型
- **位置**: `www.jpwenku.com/application/api/model/VocabularyListWord.php`
- **说明**: 建立词表和单词的多对多关系，一个单词可以属于多个词表
- **关系定义**:
  - 与词表的关联关系 (vocabularyList)
  - 与单词的关联关系 (word)
- **核心方法**:
  - `batchAdd()`: 批量添加单词到词表
  - `removeWord()`: 从词表中移除单词
  - `getWordIds()`: 获取词表中的所有单词ID

#### 5. UserVocabularyList.php - 用户词表关联模型
- **位置**: `www.jpwenku.com/application/api/model/UserVocabularyList.php`
- **说明**: 记录用户下载或创建的词表
- **关系定义**:
  - 与用户的关联关系 (user)
  - 与词表的关联关系 (vocabularyList)
- **核心方法**:
  - `downloadList()`: 用户下载词表
  - `hasDownloaded()`: 检查用户是否已下载词表
  - `getUserListIds()`: 获取用户的所有词表ID
  - `getUserLists()`: 获取用户的词表列表（带词表详情）

#### 6. UserWordProgress.php - 用户单词学习进度模型
- **位置**: `www.jpwenku.com/application/api/model/UserWordProgress.php`
- **说明**: 记录用户对每个单词的学习进度和复习计划
- **关系定义**:
  - 与用户的关联关系 (user)
  - 与单词的关联关系 (word)
  - 与词表的关联关系 (vocabularyList)
- **常量定义**:
  - 学习状态: `STATUS_NOT_LEARNED`, `STATUS_MASTERED`, `STATUS_NEED_REVIEW`
  - 最大记忆级别: `MAX_MEMORY_LEVEL = 5`
  - 记忆曲线间隔: `REVIEW_INTERVALS` (0天, 1天, 2天, 4天, 7天, 15天)
- **核心方法**:
  - `markAsKnown()`: 标记单词为已认识
  - `markAsUnknown()`: 标记单词为不认识
  - `getOrCreate()`: 获取或创建学习进度记录
  - `getDueReviews()`: 获取待复习的单词
  - `getWrongWords()`: 获取错题列表
  - `getStatistics()`: 获取学习统计

#### 7. UserWordExclusion.php - 用户单词排除模型
- **位置**: `www.jpwenku.com/application/api/model/UserWordExclusion.php`
- **说明**: 记录用户在特定词表中删除(排除)的单词，实现软删除
- **关系定义**:
  - 与用户的关联关系 (user)
  - 与单词的关联关系 (word)
  - 与词表的关联关系 (vocabularyList)
- **核心方法**:
  - `excludeWord()`: 排除单词（软删除）
  - `restoreWord()`: 恢复单词（取消排除）
  - `isExcluded()`: 检查单词是否被排除
  - `getExcludedWordIds()`: 获取用户在词表中排除的所有单词ID
  - `batchExclude()`: 批量排除单词

#### 8. UserStatistics.php - 用户学习统计模型
- **位置**: `www.jpwenku.com/application/api/model/UserStatistics.php`
- **说明**: 记录用户的学习统计数据，用于展示学习进度和成就
- **关系定义**:
  - 与用户的关联关系 (user)
- **核心方法**:
  - `getOrCreate()`: 获取或创建用户统计记录
  - `updateStatistics()`: 更新学习统计
  - `getUserStats()`: 获取用户统计数据
  - `checkContinuousDays()`: 检查并更新连续学习天数

#### 9. SmsCode.php - 短信验证码模型
- **位置**: `www.jpwenku.com/application/api/model/SmsCode.php`
- **说明**: 存储短信验证码，用于用户登录验证
- **常量定义**:
  - 验证码有效期: `EXPIRE_TIME = 300` (5分钟)
- **核心方法**:
  - `generate()`: 生成验证码
  - `verify()`: 验证验证码
  - `checkFrequency()`: 检查验证码发送频率
  - `cleanExpired()`: 清理过期验证码

## 模型关系图

```
User (用户)
├── vocabularyLists (多对多) → VocabularyList
├── wordProgress (一对多) → UserWordProgress
├── wordExclusions (一对多) → UserWordExclusion
└── statistics (一对一) → UserStatistics

Word (单词)
├── vocabularyLists (多对多) → VocabularyList
├── userProgress (一对多) → UserWordProgress
└── userExclusions (一对多) → UserWordExclusion

VocabularyList (词表)
├── words (多对多) → Word
├── users (多对多) → User
├── listWords (一对多) → VocabularyListWord
├── userLists (一对多) → UserVocabularyList
├── userProgress (一对多) → UserWordProgress
└── userExclusions (一对多) → UserWordExclusion

VocabularyListWord (词表单词关联)
├── vocabularyList (多对一) → VocabularyList
└── word (多对一) → Word

UserVocabularyList (用户词表关联)
├── user (多对一) → User
└── vocabularyList (多对一) → VocabularyList

UserWordProgress (学习进度)
├── user (多对一) → User
├── word (多对一) → Word
└── vocabularyList (多对一) → VocabularyList

UserWordExclusion (单词排除)
├── user (多对一) → User
├── word (多对一) → Word
└── vocabularyList (多对一) → VocabularyList

UserStatistics (学习统计)
└── user (多对一) → User

SmsCode (验证码)
└── (独立表，无关联)
```

## 数据验证规则

### 1. 字段类型验证
所有模型都定义了 `$type` 属性，确保字段类型正确：
- 整数字段: `id`, `user_id`, `word_id`, `vocabulary_list_id`, 时间戳等
- 字符串字段: `mobile`, `word`, `code`, `status` 等

### 2. 时间戳自动管理
- 使用 ThinkPHP 的自动时间戳功能
- 创建时间字段: `created_at`
- 更新时间字段: `updated_at`
- 时间戳格式: Unix 时间戳 (整数)

### 3. 唯一性约束
通过数据库唯一索引和模型方法确保：
- 用户手机号唯一
- 单词文本唯一
- 用户-词表关联唯一
- 用户-单词-词表学习进度唯一
- 用户-单词-词表排除记录唯一

### 4. 业务逻辑验证
- 验证码有效期验证 (5分钟)
- 验证码使用状态验证
- 记忆级别范围验证 (0-5)
- 学习状态枚举验证

## 核心功能实现

### 1. 单词全局共享机制
- 使用 `Word::findOrCreate()` 确保单词全局唯一
- 通过 `VocabularyListWord` 关联表实现多对多关系
- 避免单词数据重复存储

### 2. 软删除机制
- 使用 `UserWordExclusion` 表记录排除的单词
- 不删除全局单词数据
- 支持恢复已排除的单词
- 排除操作仅影响特定用户和词表

### 3. 记忆曲线算法
- 定义5个记忆级别 (1-5)
- 对应复习间隔: 1天, 2天, 4天, 7天, 15天
- 实现 `markAsKnown()` 和 `markAsUnknown()` 方法
- 自动计算下次复习时间

### 4. 学习统计自动更新
- 自动计算总学习天数
- 自动计算连续学习天数
- 自动统计已掌握单词数
- 自动统计待复习单词数

## 遵循的规范

### FastAdmin 框架规范
- 模型继承 `think\Model`
- 使用 `$name` 属性指定表名
- 使用 `$autoWriteTimestamp` 启用自动时间戳
- 使用 `$createTime` 和 `$updateTime` 自定义时间戳字段名

### ThinkPHP 5.x 规范
- 使用命名空间 `app\api\model`
- 使用关联方法定义模型关系
- 使用静态方法实现业务逻辑
- 使用查询构造器进行数据库操作

### 代码规范
- 完整的 PHPDoc 注释
- 清晰的方法命名
- 合理的代码组织
- 遵循 PSR 编码标准

## 验证需求

本任务实现满足以下需求：

- **需求 2.1**: 维护全局共享的单词数据库 ✓
- **需求 2.2**: 维护词表定义数据库 ✓
- **需求 2.3**: 维护词表与单词的多对多关联关系 ✓

## 后续任务

模型类已完成，可以继续以下任务：
- 3.2 实现 AuthService - 认证服务
- 3.3 实现 VocabularyService - 词表服务
- 3.4 实现 WordService - 单词服务
- 3.5 实现 SyncService - 数据同步服务

## 注意事项

1. **模型位置**: 所有模型文件位于 `www.jpwenku.com/application/api/model/` 目录
2. **命名空间**: 使用 `app\api\model` 命名空间
3. **关系定义**: 所有模型关系已完整定义，支持关联查询
4. **数据验证**: 模型层实现了基础的数据验证，控制器层需要额外的业务验证
5. **性能优化**: 使用了合适的索引和查询优化方法

## 测试建议

建议编写以下测试：
1. 模型创建和查询测试
2. 模型关系测试
3. 业务方法测试（如 `markAsKnown`, `excludeWord` 等）
4. 数据验证测试
5. 边界情况测试

## 总结

任务 3.1 已成功完成，创建了9个完整的后端数据模型类，包含：
- 完整的模型关系定义
- 丰富的业务方法
- 数据验证规则
- 符合 FastAdmin 和 ThinkPHP 规范

所有模型文件已放置在正确的目录 `www.jpwenku.com/application/api/model/`，严格遵循项目结构规范。
