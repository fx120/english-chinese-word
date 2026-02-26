import 'package:flutter/material.dart';
import '../../models/word.dart';

/// 单词卡片组件
/// 
/// 功能：
/// - 显示单词信息（单词、音标、词性、释义、例句）
/// - 支持显示/隐藏答案模式
/// - 可自定义样式和布局
/// - 支持点击事件
/// 
/// 使用场景：
/// - 学习卡片页面
/// - 复习卡片页面
/// - 词表详情页面
class WordCard extends StatelessWidget {
  /// 单词数据
  final Word word;
  
  /// 是否显示答案（释义、音标、例句等）
  final bool showAnswer;
  
  /// 卡片高度（可选）
  final double? height;
  
  /// 卡片边距
  final EdgeInsetsGeometry? margin;
  
  /// 卡片内边距
  final EdgeInsetsGeometry? padding;
  
  /// 卡片圆角半径
  final double borderRadius;
  
  /// 卡片阴影高度
  final double elevation;
  
  /// 点击事件
  final VoidCallback? onTap;
  
  const WordCard({
    super.key,
    required this.word,
    this.showAnswer = false,
    this.height,
    this.margin,
    this.padding,
    this.borderRadius = 20.0,
    this.elevation = 4.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          height: height,
          padding: padding ?? const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 单词
              Text(
                word.word,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              
              if (showAnswer) ...[
                const SizedBox(height: 32),
                _buildAnswerContent(context),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建答案内容
  Widget _buildAnswerContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 音标
        if (word.phonetic != null && word.phonetic!.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.volume_up,
                color: Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                word.phonetic!,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        
        // 词性
        if (word.partOfSpeech != null && word.partOfSpeech!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              word.partOfSpeech!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // 释义
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '释义',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                word.definition,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        
        // 例句
        if (word.example != null && word.example!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_quote,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '例句',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  word.example!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green.shade900,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 简化版单词卡片
/// 
/// 仅显示单词和释义，适用于列表展示
class SimpleWordCard extends StatelessWidget {
  final Word word;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  
  const SimpleWordCard({
    super.key,
    required this.word,
    this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin ?? const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 单词
                    Text(
                      word.word,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    
                    // 音标
                    if (word.phonetic != null && word.phonetic!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        word.phonetic!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 8),
                    
                    // 释义
                    Text(
                      word.definition,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // 箭头图标
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
