import 'package:flutter/material.dart';

/// 错误提示组件
/// 
/// 功能：
/// - 显示错误信息
/// - 支持多种样式（内联、卡片、对话框、SnackBar）
/// - 可自定义图标和颜色
/// - 支持重试操作
/// 
/// 使用场景：
/// - 网络请求失败
/// - 数据加载失败
/// - 表单验证错误
/// - 操作失败提示
class ErrorMessage extends StatelessWidget {
  /// 错误信息
  final String message;
  
  /// 错误图标
  final IconData? icon;
  
  /// 图标颜色
  final Color? iconColor;
  
  /// 文本颜色
  final Color? textColor;
  
  /// 背景颜色
  final Color? backgroundColor;
  
  /// 重试按钮文本
  final String? retryText;
  
  /// 重试回调
  final VoidCallback? onRetry;
  
  /// 边距
  final EdgeInsetsGeometry? margin;
  
  /// 内边距
  final EdgeInsetsGeometry? padding;
  
  const ErrorMessage({
    super.key,
    required this.message,
    this.icon,
    this.iconColor,
    this.textColor,
    this.backgroundColor,
    this.retryText,
    this.onRetry,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final defaultIconColor = iconColor ?? Colors.red.shade600;
    final defaultTextColor = textColor ?? Colors.red.shade900;
    final defaultBgColor = backgroundColor ?? Colors.red.shade50;
    
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: defaultBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.shade200,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 错误图标
          Icon(
            icon ?? Icons.error_outline,
            color: defaultIconColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          
          // 错误信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: defaultTextColor,
                    height: 1.4,
                  ),
                ),
                
                // 重试按钮
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(retryText ?? '重试'),
                    style: TextButton.styleFrom(
                      foregroundColor: defaultIconColor,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 显示SnackBar错误提示
  static void showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }
  
  /// 显示对话框错误提示
  static Future<void> showDialog(
    BuildContext context,
    String message, {
    String title = '错误',
    String buttonText = '确定',
    VoidCallback? onRetry,
    String? retryText,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text(retryText ?? '重试'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}

/// 空状态错误提示
/// 
/// 用于显示空列表或无数据的情况
class EmptyStateMessage extends StatelessWidget {
  /// 图标
  final IconData icon;
  
  /// 主要消息
  final String message;
  
  /// 次要消息（提示）
  final String? hint;
  
  /// 图标颜色
  final Color? iconColor;
  
  /// 操作按钮
  final Widget? action;
  
  const EmptyStateMessage({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.iconColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: iconColor ?? Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 网络错误提示
/// 
/// 专门用于网络连接错误的提示
class NetworkErrorMessage extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  
  const NetworkErrorMessage({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateMessage(
      icon: Icons.wifi_off,
      message: message ?? '网络连接失败',
      hint: '请检查网络连接后重试',
      iconColor: Colors.orange.shade300,
      action: onRetry != null
          ? ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            )
          : null,
    );
  }
}

/// 内联错误提示
/// 
/// 用于表单字段下方的错误提示
class InlineErrorMessage extends StatelessWidget {
  final String message;
  final EdgeInsetsGeometry? padding;
  
  const InlineErrorMessage({
    super.key,
    required this.message,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(top: 8, left: 12),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: Colors.red.shade600,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 警告提示
/// 
/// 用于显示警告信息
class WarningMessage extends StatelessWidget {
  final String message;
  final IconData? icon;
  final VoidCallback? onDismiss;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  
  const WarningMessage({
    super.key,
    required this.message,
    this.icon,
    this.onDismiss,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange.shade900,
                height: 1.4,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onDismiss,
              child: Icon(
                Icons.close,
                size: 20,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 成功提示
/// 
/// 用于显示操作成功的信息
class SuccessMessage extends StatelessWidget {
  final String message;
  final IconData? icon;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  
  const SuccessMessage({
    super.key,
    required this.message,
    this.icon,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? Icons.check_circle_outline,
            color: Colors.green.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 显示SnackBar成功提示
  static void showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 信息提示
/// 
/// 用于显示一般信息
class InfoMessage extends StatelessWidget {
  final String message;
  final IconData? icon;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  
  const InfoMessage({
    super.key,
    required this.message,
    this.icon,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? Icons.info_outline,
            color: Colors.blue.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
