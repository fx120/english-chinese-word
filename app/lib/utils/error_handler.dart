import 'dart:io';
import 'package:dio/dio.dart';

/// 全局错误处理器
/// 
/// 提供统一的错误处理、分类和用户友好的错误消息
/// 支持网络错误、数据验证错误、数据库错误和业务逻辑错误
class ErrorHandler {
  /// 处理错误并返回用户友好的错误消息
  /// 
  /// [error] 原始错误对象
  /// [stackTrace] 堆栈跟踪（可选）
  /// 返回格式化的错误消息
  static String handleError(dynamic error, [StackTrace? stackTrace]) {
    // 记录错误日志
    _logError(error, stackTrace);
    
    // 根据错误类型返回相应的消息
    if (error is NetworkError) {
      return _handleNetworkError(error);
    } else if (error is ValidationError) {
      return _handleValidationError(error);
    } else if (error is DatabaseError) {
      return _handleDatabaseError(error);
    } else if (error is BusinessLogicError) {
      return _handleBusinessLogicError(error);
    } else if (error is DioException) {
      return _handleDioException(error);
    } else if (error is SocketException) {
      return '网络连接失败，请检查网络设置';
    } else if (error is FormatException) {
      return '数据格式错误：${error.message}';
    } else if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    } else {
      return '发生未知错误，请稍后重试';
    }
  }
  
  /// 处理网络错误
  static String _handleNetworkError(NetworkError error) {
    switch (error.type) {
      case NetworkErrorType.timeout:
        return '网络连接超时，请检查网络设置';
      case NetworkErrorType.noConnection:
        return '网络连接失败，请检查网络设置';
      case NetworkErrorType.serverError:
        return '服务器错误：${error.message ?? "服务器繁忙，请稍后重试"}';
      case NetworkErrorType.unauthorized:
        return '登录已过期，请重新登录';
      case NetworkErrorType.forbidden:
        return '没有访问权限';
      case NetworkErrorType.notFound:
        return '请求的资源不存在';
      case NetworkErrorType.badRequest:
        return '请求参数错误：${error.message ?? ""}';
      case NetworkErrorType.unknown:
        return error.message ?? '网络请求失败';
    }
  }
  
  /// 处理数据验证错误
  static String _handleValidationError(ValidationError error) {
    switch (error.type) {
      case ValidationErrorType.emptyField:
        return '${error.field ?? "字段"}不能为空';
      case ValidationErrorType.invalidFormat:
        return '${error.field ?? "字段"}格式不正确：${error.message ?? ""}';
      case ValidationErrorType.outOfRange:
        return '${error.field ?? "字段"}超出有效范围：${error.message ?? ""}';
      case ValidationErrorType.duplicateValue:
        return '${error.field ?? "字段"}已存在：${error.message ?? ""}';
      case ValidationErrorType.invalidLength:
        return '${error.field ?? "字段"}长度不正确：${error.message ?? ""}';
      case ValidationErrorType.custom:
        return error.message ?? '数据验证失败';
    }
  }
  
  /// 处理数据库错误
  static String _handleDatabaseError(DatabaseError error) {
    switch (error.type) {
      case DatabaseErrorType.initializationFailed:
        return '数据库初始化失败：${error.message ?? ""}';
      case DatabaseErrorType.queryFailed:
        return '数据查询失败：${error.message ?? ""}';
      case DatabaseErrorType.insertFailed:
        return '数据插入失败：${error.message ?? ""}';
      case DatabaseErrorType.updateFailed:
        return '数据更新失败：${error.message ?? ""}';
      case DatabaseErrorType.deleteFailed:
        return '数据删除失败：${error.message ?? ""}';
      case DatabaseErrorType.constraintViolation:
        return '数据约束冲突：${error.message ?? ""}';
      case DatabaseErrorType.storageSpaceInsufficient:
        return '存储空间不足，请清理设备存储';
      case DatabaseErrorType.unknown:
        return error.message ?? '数据库操作失败';
    }
  }
  
  /// 处理业务逻辑错误
  static String _handleBusinessLogicError(BusinessLogicError error) {
    switch (error.type) {
      case BusinessLogicErrorType.resourceNotFound:
        return '${error.resource ?? "资源"}不存在';
      case BusinessLogicErrorType.resourceAlreadyExists:
        return '${error.resource ?? "资源"}已存在';
      case BusinessLogicErrorType.invalidOperation:
        return '无效的操作：${error.message ?? ""}';
      case BusinessLogicErrorType.operationNotAllowed:
        return '不允许的操作：${error.message ?? ""}';
      case BusinessLogicErrorType.preconditionFailed:
        return '操作前置条件不满足：${error.message ?? ""}';
      case BusinessLogicErrorType.stateConflict:
        return '状态冲突：${error.message ?? ""}';
      case BusinessLogicErrorType.custom:
        return error.message ?? '操作失败';
    }
  }
  
  /// 处理Dio异常
  static String _handleDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '网络连接超时，请检查网络设置';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络设置';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          return '登录已过期，请重新登录';
        } else if (statusCode == 403) {
          return '没有访问权限';
        } else if (statusCode == 404) {
          return '请求的资源不存在';
        } else if (statusCode == 500) {
          return '服务器内部错误';
        } else if (statusCode == 503) {
          return '服务器繁忙，请稍后重试';
        }
        return error.error?.toString() ?? '请求失败';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.badCertificate:
        return '证书验证失败';
      case DioExceptionType.unknown:
        return error.error?.toString() ?? '网络请求失败';
    }
  }
  
  /// 记录错误日志
  static void _logError(dynamic error, StackTrace? stackTrace) {
    // TODO: 实现错误日志记录到本地文件
    // TODO: 实现关键错误上报到服务器
    print('Error: $error');
    if (stackTrace != null) {
      print('StackTrace: $stackTrace');
    }
  }
}

// ==================== 自定义错误类型 ====================

/// 网络错误
class NetworkError implements Exception {
  final NetworkErrorType type;
  final String? message;
  final int? statusCode;
  
  NetworkError({
    required this.type,
    this.message,
    this.statusCode,
  });
  
  @override
  String toString() => 'NetworkError: $type - $message';
}

/// 网络错误类型
enum NetworkErrorType {
  timeout,          // 连接超时
  noConnection,     // 无网络连接
  serverError,      // 服务器错误 (5xx)
  unauthorized,     // 未授权 (401)
  forbidden,        // 禁止访问 (403)
  notFound,         // 资源不存在 (404)
  badRequest,       // 请求错误 (400)
  unknown,          // 未知错误
}

/// 数据验证错误
class ValidationError implements Exception {
  final ValidationErrorType type;
  final String? field;
  final String? message;
  
  ValidationError({
    required this.type,
    this.field,
    this.message,
  });
  
  @override
  String toString() => 'ValidationError: $type - $field - $message';
}

/// 数据验证错误类型
enum ValidationErrorType {
  emptyField,       // 字段为空
  invalidFormat,    // 格式不正确
  outOfRange,       // 超出范围
  duplicateValue,   // 重复值
  invalidLength,    // 长度不正确
  custom,           // 自定义验证错误
}

/// 数据库错误
class DatabaseError implements Exception {
  final DatabaseErrorType type;
  final String? message;
  final dynamic originalError;
  
  DatabaseError({
    required this.type,
    this.message,
    this.originalError,
  });
  
  @override
  String toString() => 'DatabaseError: $type - $message';
}

/// 数据库错误类型
enum DatabaseErrorType {
  initializationFailed,      // 初始化失败
  queryFailed,               // 查询失败
  insertFailed,              // 插入失败
  updateFailed,              // 更新失败
  deleteFailed,              // 删除失败
  constraintViolation,       // 约束冲突
  storageSpaceInsufficient,  // 存储空间不足
  unknown,                   // 未知错误
}

/// 业务逻辑错误
class BusinessLogicError implements Exception {
  final BusinessLogicErrorType type;
  final String? message;
  final String? resource;
  
  BusinessLogicError({
    required this.type,
    this.message,
    this.resource,
  });
  
  @override
  String toString() => 'BusinessLogicError: $type - $resource - $message';
}

/// 业务逻辑错误类型
enum BusinessLogicErrorType {
  resourceNotFound,       // 资源不存在
  resourceAlreadyExists,  // 资源已存在
  invalidOperation,       // 无效操作
  operationNotAllowed,    // 不允许的操作
  preconditionFailed,     // 前置条件失败
  stateConflict,          // 状态冲突
  custom,                 // 自定义业务错误
}

// ==================== 错误处理辅助方法 ====================

/// 执行异步操作并处理错误
/// 
/// [operation] 要执行的异步操作
/// [onError] 错误回调（可选）
/// 返回操作结果或null（如果发生错误）
Future<T?> executeWithErrorHandling<T>(
  Future<T> Function() operation, {
  void Function(String errorMessage)? onError,
}) async {
  try {
    return await operation();
  } catch (error, stackTrace) {
    final errorMessage = ErrorHandler.handleError(error, stackTrace);
    onError?.call(errorMessage);
    return null;
  }
}

/// 执行同步操作并处理错误
/// 
/// [operation] 要执行的同步操作
/// [onError] 错误回调（可选）
/// 返回操作结果或null（如果发生错误）
T? executeSyncWithErrorHandling<T>(
  T Function() operation, {
  void Function(String errorMessage)? onError,
}) {
  try {
    return operation();
  } catch (error, stackTrace) {
    final errorMessage = ErrorHandler.handleError(error, stackTrace);
    onError?.call(errorMessage);
    return null;
  }
}

// ==================== 数据验证辅助方法 ====================

/// 验证手机号格式
/// 
/// [mobile] 手机号
/// 抛出ValidationError如果格式不正确
void validateMobile(String mobile) {
  if (mobile.isEmpty) {
    throw ValidationError(
      type: ValidationErrorType.emptyField,
      field: '手机号',
    );
  }
  
  final mobileRegex = RegExp(r'^1[3-9]\d{9}$');
  if (!mobileRegex.hasMatch(mobile)) {
    throw ValidationError(
      type: ValidationErrorType.invalidFormat,
      field: '手机号',
      message: '请输入11位有效手机号',
    );
  }
}

/// 验证验证码格式
/// 
/// [code] 验证码
/// 抛出ValidationError如果格式不正确
void validateVerificationCode(String code) {
  if (code.isEmpty) {
    throw ValidationError(
      type: ValidationErrorType.emptyField,
      field: '验证码',
    );
  }
  
  final codeRegex = RegExp(r'^\d{6}$');
  if (!codeRegex.hasMatch(code)) {
    throw ValidationError(
      type: ValidationErrorType.invalidFormat,
      field: '验证码',
      message: '请输入6位数字验证码',
    );
  }
}

/// 验证单词字段
/// 
/// [word] 单词
/// 抛出ValidationError如果为空
void validateWord(String word) {
  if (word.trim().isEmpty) {
    throw ValidationError(
      type: ValidationErrorType.emptyField,
      field: '单词',
    );
  }
}

/// 验证释义字段
/// 
/// [definition] 释义
/// 抛出ValidationError如果为空
void validateDefinition(String definition) {
  if (definition.trim().isEmpty) {
    throw ValidationError(
      type: ValidationErrorType.emptyField,
      field: '释义',
    );
  }
}

/// 验证词表名称
/// 
/// [name] 词表名称
/// 抛出ValidationError如果为空或过长
void validateVocabularyListName(String name) {
  if (name.trim().isEmpty) {
    throw ValidationError(
      type: ValidationErrorType.emptyField,
      field: '词表名称',
    );
  }
  
  if (name.length > 100) {
    throw ValidationError(
      type: ValidationErrorType.invalidLength,
      field: '词表名称',
      message: '词表名称不能超过100个字符',
    );
  }
}

/// 验证文件扩展名
/// 
/// [filePath] 文件路径
/// [allowedExtensions] 允许的扩展名列表
/// 抛出ValidationError如果扩展名不匹配
void validateFileExtension(String filePath, List<String> allowedExtensions) {
  final extension = filePath.split('.').last.toLowerCase();
  if (!allowedExtensions.contains(extension)) {
    throw ValidationError(
      type: ValidationErrorType.invalidFormat,
      field: '文件',
      message: '只支持 ${allowedExtensions.join(", ")} 格式',
    );
  }
}
