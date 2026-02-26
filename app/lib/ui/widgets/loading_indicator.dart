import 'package:flutter/material.dart';

/// 加载指示器组件
/// 
/// 功能：
/// - 显示加载状态
/// - 支持多种样式（圆形、线性、覆盖层）
/// - 可自定义颜色和大小
/// - 支持显示加载文本
/// 
/// 使用场景：
/// - 数据加载时
/// - 网络请求时
/// - 文件导入时
/// - 页面切换时
class LoadingIndicator extends StatelessWidget {
  /// 加载文本
  final String? message;
  
  /// 指示器大小
  final double size;
  
  /// 指示器颜色
  final Color? color;
  
  /// 文本样式
  final TextStyle? textStyle;
  
  /// 指示器和文本之间的间距
  final double spacing;
  
  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 40.0,
    this.color,
    this.textStyle,
    this.spacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final indicatorColor = color ?? Theme.of(context).primaryColor;
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 圆形进度指示器
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: size * 0.1,
              valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
            ),
          ),
          
          // 加载文本
          if (message != null) ...[
            SizedBox(height: spacing),
            Text(
              message!,
              style: textStyle ?? TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// 小型加载指示器
/// 
/// 适用于按钮内或小空间
class SmallLoadingIndicator extends StatelessWidget {
  final Color? color;
  final double size;
  
  const SmallLoadingIndicator({
    super.key,
    this.color,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.0,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Colors.white,
        ),
      ),
    );
  }
}

/// 覆盖层加载指示器
/// 
/// 在整个屏幕上显示半透明遮罩和加载指示器
class OverlayLoadingIndicator extends StatelessWidget {
  /// 加载文本
  final String? message;
  
  /// 遮罩颜色
  final Color? overlayColor;
  
  /// 指示器颜色
  final Color? indicatorColor;
  
  /// 是否可以点击遮罩关闭
  final bool dismissible;
  
  const OverlayLoadingIndicator({
    super.key,
    this.message,
    this.overlayColor,
    this.indicatorColor,
    this.dismissible = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: overlayColor ?? Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      indicatorColor ?? Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    message!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// 显示覆盖层加载指示器
  static void show(
    BuildContext context, {
    String? message,
    Color? overlayColor,
    Color? indicatorColor,
    bool dismissible = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: Colors.transparent,
      builder: (context) => OverlayLoadingIndicator(
        message: message,
        overlayColor: overlayColor,
        indicatorColor: indicatorColor,
        dismissible: dismissible,
      ),
    );
  }
  
  /// 隐藏覆盖层加载指示器
  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }
}

/// 线性加载指示器
/// 
/// 显示线性进度条，适用于有明确进度的加载
class LinearLoadingIndicator extends StatelessWidget {
  /// 当前进度 (0.0 - 1.0)，null表示不确定进度
  final double? value;
  
  /// 进度条高度
  final double height;
  
  /// 进度条颜色
  final Color? color;
  
  /// 背景颜色
  final Color? backgroundColor;
  
  /// 是否显示百分比
  final bool showPercentage;
  
  /// 加载文本
  final String? message;
  
  const LinearLoadingIndicator({
    super.key,
    this.value,
    this.height = 4.0,
    this.color,
    this.backgroundColor,
    this.showPercentage = false,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? Theme.of(context).primaryColor;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 加载文本和百分比
        if (message != null || (showPercentage && value != null)) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (message != null)
                Expanded(
                  child: Text(
                    message!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              if (showPercentage && value != null)
                Text(
                  '${(value! * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        
        // 进度条
        SizedBox(
          height: height,
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: backgroundColor ?? Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}

/// 刷新指示器
/// 
/// 用于下拉刷新场景
class RefreshLoadingIndicator extends StatelessWidget {
  final Color? color;
  
  const RefreshLoadingIndicator({
    super.key,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
}

/// 骨架屏加载指示器
/// 
/// 显示内容占位符，提供更好的加载体验
class SkeletonLoadingIndicator extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  
  const SkeletonLoadingIndicator({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<SkeletonLoadingIndicator> createState() => _SkeletonLoadingIndicatorState();
}

class _SkeletonLoadingIndicatorState extends State<SkeletonLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade200,
                Colors.grey.shade300,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}
