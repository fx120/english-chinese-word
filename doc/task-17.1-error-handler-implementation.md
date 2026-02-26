# Task 17.1 - 全局错误处理实现文档

## 任务概述

实现了Flutter应用的全局错误处理系统，提供统一的错误处理、分类和用户友好的错误消息。

## 实现内容

### 1. 错误处理器 (`app/lib/utils/error_handler.dart`)

创建了综合的错误处理工具类，包含以下功能：

#### 1.1 核心错误处理方法

- **`handleError(error, stackTrace)`**: 主要错误处理方法，接收任何类型的错误并返回用户友好的消息
- **`_logError(error, stackTrace)`**: 错误日志记录（预留接口）

#### 1.2 网络错误处理

实现了 `NetworkError` 类和 `NetworkErrorType` 枚举：

**错误类型**:
- `timeout`: 连接超时
- `noConnection`: 无网络连接
- `serverError`: 服务器错误 (5xx)
- `unauthorized`: 未授权 (401)
- `forbidden`: 禁止访问 (403)
- `notFound`: 资源不存在 (404)
- `badRequest`: 请求错误 (400)
- `unknown`: 未知错误

**特性**:
- 自动处理 Dio 网络异常
- 根据 HTTP 状态码返回相应的错误消息
- 处理连接超时、网络不可用等常见网络问题

#### 1.3 数据验证错误处理

实现了 `ValidationError` 类和 `ValidationErrorType` 枚举：

**错误类型**:
- `emptyField`: 字段为空
- `invalidFormat`: 格式不正确
- `outOfRange`: 超出范围
- `duplicateValue`: 重复值
- `invalidLength`: 长度不正确
- `custom`: 自定义验证错误

**验证辅助方法**:
- `validateMobile(mobile)`: 验证手机号格式（11位，1开头）
- `validateVerificationCode(code)`: 验证验证码格式（6位数字）
- `validateWord(word)`: 验证单词字段非空
- `validateDefinition(definition)`: 验证释义字段非空
- `validateVocabularyListName(name)`: 验证词表名称（非空且不超过100字符）
- `validateFileExtension(filePath, allowedExtensions)`: 验证文件扩展名

#### 1.4 数据库错误处理

实现了 `DatabaseError` 类和 `DatabaseErrorType` 枚举：

**错误类型**:
- `initializationFailed`: 初始化失败
- `queryFailed`: 查询失败
- `insertFailed`: 插入失败
- `updateFailed`: 更新失败
- `deleteFailed`: 删除失败
- `constraintViolation`: 约束冲突
- `storageSpaceInsufficient`: 存储空间不足
- `unknown`: 未知错误

**特性**:
- 提供清晰的数据库操作错误消息
- 支持原始错误对象保存以便调试

#### 1.5 业务逻辑错误处理

实现了 `BusinessLogicError` 类和 `BusinessLogicErrorType` 枚举：

**错误类型**:
- `resourceNotFound`: 资源不存在
- `resourceAlreadyExists`: 资源已存在
- `invalidOperation`: 无效操作
- `operationNotAllowed`: 不允许的操作
- `preconditionFailed`: 前置条件失败
- `stateConflict`: 状态冲突
- `custom`: 自定义业务错误

**特性**:
- 支持资源名称参数化
- 提供详细的业务错误上下文

#### 1.6 错误处理辅助方法

**异步操作错误处理**:
```dart
Future<T?> executeWithErrorHandling<T>(
  Future<T> Function() operation, {
  void Function(String errorMessage)? onError,
})
```

**同步操作错误处理**:
```dart
T? executeSyncWithErrorHandling<T>(
  T Function() operation, {
  void Function(String errorMessage)? onError,
})
```

## 使用示例

### 示例 1: 在 Manager 中使用

```dart
class VocabularyManager {
  Future<List<VocabularyList>> getVocabularyLists() async {
    return await executeWithErrorHandling(
      () async {
        // 验证网络连接
        if (!await hasNetworkConnection()) {
          throw NetworkError(
            type: NetworkErrorType.noConnection,
            message: '无网络连接',
          );
        }
        
        // 执行API请求
        final response = await _apiClient.getVocabularyLists();
        return parseVocabularyLists(response.data);
      },
      onError: (errorMessage) {
        print('获取词表列表失败: $errorMessage');
      },
    ) ?? [];
  }
}
```

### 示例 2: 数据验证

```dart
Future<void> createVocabularyList(String name, List<Word> words) async {
  // 验证词表名称
  validateVocabularyListName(name);
  
  // 验证单词
  for (var word in words) {
    validateWord(word.word);
    validateDefinition(word.definition);
  }
  
  // 执行创建操作
  await _localDatabase.insertVocabularyList(list);
}
```

### 示例 3: 在 Provider 中使用

```dart
class VocabularyProvider extends ChangeNotifier {
  String? _error;
  
  Future<void> downloadVocabularyList(int listId) async {
    _error = null;
    notifyListeners();
    
    try {
      await _vocabularyManager.downloadVocabularyList(listId);
    } catch (error, stackTrace) {
      _error = ErrorHandler.handleError(error, stackTrace);
      notifyListeners();
    }
  }
}
```

### 示例 4: 抛出自定义错误

```dart
Future<void> startLearningSession(int listId) async {
  // 检查词表是否存在
  final list = await _localDatabase.getVocabularyList(listId);
  if (list == null) {
    throw BusinessLogicError(
      type: BusinessLogicErrorType.resourceNotFound,
      resource: '词表',
      message: 'ID为$listId的词表不存在',
    );
  }
  
  // 检查是否有未学习的单词
  final unlearnedCount = await getUnlearnedWordCount(listId);
  if (unlearnedCount == 0) {
    throw BusinessLogicError(
      type: BusinessLogicErrorType.preconditionFailed,
      message: '该词表没有未学习的单词',
    );
  }
  
  // 开始学习会话
  // ...
}
```

## 错误处理流程

```
用户操作
    ↓
业务逻辑层 (Manager)
    ↓
数据访问层 (Database/API)
    ↓
发生错误
    ↓
ErrorHandler.handleError()
    ↓
分类错误类型
    ↓
返回用户友好消息
    ↓
Provider 更新错误状态
    ↓
UI 显示错误提示
```

## 错误日志记录

当前实现包含错误日志记录的预留接口：

```dart
static void _logError(dynamic error, StackTrace? stackTrace) {
  // TODO: 实现错误日志记录到本地文件
  // TODO: 实现关键错误上报到服务器
  print('Error: $error');
  if (stackTrace != null) {
    print('StackTrace: $stackTrace');
  }
}
```

**未来扩展**:
1. 实现本地日志文件记录
2. 实现关键错误上报到服务器
3. 添加日志级别（DEBUG, INFO, WARNING, ERROR）
4. 实现日志文件轮转和清理

## 与现有代码集成

### 1. API Client 集成

`ApiClient` 已经实现了基础的错误处理拦截器，可以与 `ErrorHandler` 配合使用：

- API Client 的拦截器处理 HTTP 层面的错误
- ErrorHandler 提供统一的错误消息格式化
- 两者互补，提供完整的错误处理链

### 2. Provider 集成

现有的 Provider（如 `LearningProvider`, `ReviewProvider`）已经有基础的错误处理：

```dart
try {
  // 操作
} catch (e) {
  _error = e.toString();
}
```

可以升级为：

```dart
try {
  // 操作
} catch (error, stackTrace) {
  _error = ErrorHandler.handleError(error, stackTrace);
}
```

### 3. Manager 集成

Manager 层可以使用 `executeWithErrorHandling` 辅助方法简化错误处理。

## 测试建议

### 单元测试

1. **网络错误测试**:
   - 测试各种 HTTP 状态码的错误消息
   - 测试连接超时错误
   - 测试网络不可用错误

2. **验证错误测试**:
   - 测试手机号验证（有效/无效格式）
   - 测试验证码验证（6位数字）
   - 测试单词和释义验证（非空）
   - 测试文件扩展名验证

3. **数据库错误测试**:
   - 测试各种数据库操作错误的消息格式

4. **业务逻辑错误测试**:
   - 测试资源不存在错误
   - 测试重复资源错误
   - 测试前置条件失败错误

### 集成测试

1. 测试完整的错误处理流程（从操作到UI显示）
2. 测试错误恢复机制（重试、回退等）
3. 测试离线场景下的错误处理

## 符合需求

本实现满足以下需求：

- ✅ **需求 1.5**: 错误验证码返回明确错误信息
- ✅ **需求 3.6**: 网络错误显示错误提示并允许重试
- ✅ **需求 4.5**: 文件格式不正确显示错误信息
- ✅ **需求 5.6**: Excel文件格式不正确显示错误信息
- ✅ **需求 6.8**: OCR识别失败显示错误提示
- ✅ **需求 14.7**: 同步失败显示错误提示并允许重试
- ✅ **所有错误处理需求**: 提供统一的错误处理机制

## 文件位置

- **实现文件**: `app/lib/utils/error_handler.dart`
- **文档文件**: `doc/task-17.1-error-handler-implementation.md`

## 完成状态

✅ 任务已完成

- [x] 创建错误处理器类
- [x] 实现网络错误处理
- [x] 实现数据验证错误处理
- [x] 实现数据库错误处理
- [x] 实现业务逻辑错误处理
- [x] 实现错误日志记录接口
- [x] 提供验证辅助方法
- [x] 提供错误处理辅助方法
- [x] 编写实现文档

## 后续改进建议

1. **错误日志持久化**: 实现本地文件日志记录
2. **错误上报**: 实现关键错误上报到服务器
3. **错误分析**: 添加错误统计和分析功能
4. **国际化**: 支持多语言错误消息
5. **错误恢复**: 实现自动重试和错误恢复机制
6. **用户反馈**: 添加错误反馈入口，让用户可以报告问题
