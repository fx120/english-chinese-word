import '../models/word.dart';

/// 文本文件解析器
/// 支持解析格式为 "单词 释义" 或 "单词\t释义" 的文本文件
/// 支持UTF-8编码
class TextParser {
  /// 解析文本文件
  /// 支持格式: "单词 释义" 或 "单词\t释义"
  /// [content] 文件内容（UTF-8编码）
  /// 返回解析后的单词列表
  /// 
  /// 解析规则：
  /// - 每行一个单词条目
  /// - 单词和释义之间用制表符或空格分隔
  /// - 空行会被忽略
  /// - 如果一行包含多个空格，第一个空格前为单词，其余为释义
  static List<Word> parseTextFile(String content) {
    List<Word> words = [];
    List<String> lines = content.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      
      // 跳过空行
      if (line.isEmpty) continue;
      
      List<String> parts;
      
      // 尝试用制表符分割
      if (line.contains('\t')) {
        parts = line.split('\t');
      } else {
        // 使用空格分割，只分割成两部分（单词和释义）
        int firstSpaceIndex = line.indexOf(RegExp(r'\s+'));
        if (firstSpaceIndex != -1) {
          parts = [
            line.substring(0, firstSpaceIndex),
            line.substring(firstSpaceIndex).trim()
          ];
        } else {
          // 没有空格或制表符，跳过这行
          continue;
        }
      }
      
      if (parts.length >= 2) {
        String word = parts[0].trim();
        String definition = parts[1].trim();
        
        if (word.isNotEmpty && definition.isNotEmpty) {
          words.add(Word(
            id: 0, // 临时ID，插入数据库时会分配
            word: word,
            definition: definition,
            createdAt: DateTime.now(),
          ));
        }
      }
    }
    
    return words;
  }
  
  /// 验证解析结果
  /// 检查解析的单词列表是否有效
  /// [words] 解析后的单词列表
  /// 返回true表示有效，false表示无效
  /// 
  /// 验证规则：
  /// - 列表不能为空
  /// - 不能有重复的单词
  static bool validateParsedWords(List<Word> words) {
    if (words.isEmpty) return false;
    
    // 检查是否有重复单词
    Set<String> wordSet = {};
    for (var word in words) {
      if (wordSet.contains(word.word)) {
        return false; // 有重复
      }
      wordSet.add(word.word);
    }
    
    return true;
  }
  
  /// 解析文本文件并返回详细结果
  /// [content] 文件内容
  /// 返回包含解析结果和错误信息的对象
  static ParseResult parseTextFileWithDetails(String content) {
    List<Word> words = [];
    List<String> errors = [];
    List<String> lines = content.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      int lineNumber = i + 1;
      
      // 跳过空行
      if (line.isEmpty) continue;
      
      List<String> parts;
      
      // 尝试用制表符分割
      if (line.contains('\t')) {
        parts = line.split('\t');
      } else {
        // 使用空格分割
        int firstSpaceIndex = line.indexOf(RegExp(r'\s+'));
        if (firstSpaceIndex != -1) {
          parts = [
            line.substring(0, firstSpaceIndex),
            line.substring(firstSpaceIndex).trim()
          ];
        } else {
          // 没有分隔符
          errors.add('第 $lineNumber 行: 格式错误，缺少分隔符（空格或制表符）');
          continue;
        }
      }
      
      if (parts.length < 2) {
        errors.add('第 $lineNumber 行: 格式错误，缺少释义');
        continue;
      }
      
      String word = parts[0].trim();
      String definition = parts[1].trim();
      
      if (word.isEmpty) {
        errors.add('第 $lineNumber 行: 单词不能为空');
        continue;
      }
      
      if (definition.isEmpty) {
        errors.add('第 $lineNumber 行: 释义不能为空');
        continue;
      }
      
      words.add(Word(
        id: 0,
        word: word,
        definition: definition,
        createdAt: DateTime.now(),
      ));
    }
    
    return ParseResult(
      words: words,
      errors: errors,
      totalLines: lines.length,
      successCount: words.length,
    );
  }
}

/// 解析结果类
class ParseResult {
  final List<Word> words;
  final List<String> errors;
  final int totalLines;
  final int successCount;
  
  ParseResult({
    required this.words,
    required this.errors,
    required this.totalLines,
    required this.successCount,
  });
  
  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess => words.isNotEmpty && errors.isEmpty;
  int get errorCount => errors.length;
}
