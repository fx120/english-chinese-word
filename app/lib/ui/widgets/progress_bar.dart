import 'package:flutter/material.dart';

/// 进度条组件
/// 
/// 功能：
/// - 显示学习/复习进度
/// - 支持百分比和分数显示
/// - 可自定义颜色和样式
/// - 支持动画效果
/// 
/// 使用场景：
/// - 学习卡片页面
/// - 复习卡片页面
/// - 统计页面
/// - 词表详情页面
class ProgressBar extends StatelessWidget {
  /// 当前进度值 (0.0 - 1.0)
  final double value;
  
  /// 进度条高度
  final double height;
  
  /// 进度条颜色
  final Color? color;
  
  /// 背景颜色
  final Color? backgroundColor;
  
  /// 圆角半径
  final double borderRadius;
  
  /// 是否显示百分比文本
  final bool showPercentage;
  
  /// 百分比文本样式
  final TextStyle? percentageStyle;
  
  /// 是否显示动画
  final bool animated;
  
  const ProgressBar({
    super.key,
    required this.value,
    this.height = 8.0,
    this.color,
    this.backgroundColor,
    this.borderRadius = 4.0,
    this.showPercentage = false,
    this.percentageStyle,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? Theme.of(context).primaryColor;
    final bgColor = backgroundColor ?? Colors.grey.shade200;
    
    if (showPercentage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 百分比文本
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '进度',
                style: percentageStyle ?? TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '${(value * 100).toInt()}%',
                style: percentageStyle ?? TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 进度条
          _buildProgressBar(progressColor, bgColor),
        ],
      );
    }
    
    return _buildProgressBar(progressColor, bgColor);
  }
  
  Widget _buildProgressBar(Color progressColor, Color bgColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: bgColor,
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
        ),
      ),
    );
  }
}

/// 带标签的进度条
/// 
/// 显示进度条和当前/总数标签
class LabeledProgressBar extends StatelessWidget {
  /// 当前值
  final int current;
  
  /// 总数
  final int total;
  
  /// 进度条高度
  final double height;
  
  /// 进度条颜色
  final Color? color;
  
  /// 背景颜色
  final Color? backgroundColor;
  
  /// 标签文本样式
  final TextStyle? labelStyle;
  
  const LabeledProgressBar({
    super.key,
    required this.current,
    required this.total,
    this.height = 8.0,
    this.color,
    this.backgroundColor,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final value = total > 0 ? current / total : 0.0;
    final progressColor = color ?? Theme.of(context).primaryColor;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标签
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '进度',
              style: labelStyle ?? TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              '$current / $total',
              style: labelStyle ?? TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: progressColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // 进度条
        ProgressBar(
          value: value,
          height: height,
          color: color,
          backgroundColor: backgroundColor,
        ),
      ],
    );
  }
}

/// 圆形进度指示器
/// 
/// 显示圆形进度和百分比
class CircularProgressBar extends StatelessWidget {
  /// 当前进度值 (0.0 - 1.0)
  final double value;
  
  /// 圆形大小
  final double size;
  
  /// 进度条宽度
  final double strokeWidth;
  
  /// 进度条颜色
  final Color? color;
  
  /// 背景颜色
  final Color? backgroundColor;
  
  /// 是否显示百分比文本
  final bool showPercentage;
  
  /// 百分比文本样式
  final TextStyle? percentageStyle;
  
  const CircularProgressBar({
    super.key,
    required this.value,
    this.size = 100.0,
    this.strokeWidth = 8.0,
    this.color,
    this.backgroundColor,
    this.showPercentage = true,
    this.percentageStyle,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? Theme.of(context).primaryColor;
    final bgColor = backgroundColor ?? Colors.grey.shade200;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 圆形进度条
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              backgroundColor: bgColor,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          
          // 百分比文本
          if (showPercentage)
            Text(
              '${(value * 100).toInt()}%',
              style: percentageStyle ?? TextStyle(
                fontSize: size * 0.2,
                fontWeight: FontWeight.bold,
                color: progressColor,
              ),
            ),
        ],
      ),
    );
  }
}

/// 多段进度条
/// 
/// 显示多个分段的进度条，适用于显示不同状态的统计
class SegmentedProgressBar extends StatelessWidget {
  /// 分段数据列表
  final List<ProgressSegment> segments;
  
  /// 进度条高度
  final double height;
  
  /// 圆角半径
  final double borderRadius;
  
  /// 是否显示图例
  final bool showLegend;
  
  const SegmentedProgressBar({
    super.key,
    required this.segments,
    this.height = 24.0,
    this.borderRadius = 12.0,
    this.showLegend = true,
  });

  @override
  Widget build(BuildContext context) {
    // 计算总数
    final total = segments.fold<int>(0, (sum, segment) => sum + segment.value);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 分段进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox(
            height: height,
            child: Row(
              children: segments.map((segment) {
                final ratio = total > 0 ? segment.value / total : 0.0;
                return Expanded(
                  flex: (ratio * 100).toInt(),
                  child: Container(
                    color: segment.color,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        
        // 图例
        if (showLegend) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: segments.map((segment) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: segment.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${segment.label}: ${segment.value}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// 进度分段数据
class ProgressSegment {
  final String label;
  final int value;
  final Color color;
  
  const ProgressSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}
