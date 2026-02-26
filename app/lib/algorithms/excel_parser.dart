import 'dart:io';
import 'package:excel/excel.dart';
import '../models/word.dart';

/// Excel文件解析器
/// 支持解析.xlsx和.xls格式的Excel文件
/// 第一列为单词，第二列为释义
/// 自动跳过标题行
class ExcelParser {
  /// 解析Excel文件
  /// [filePath] Excel文件路径
  /// 返回解析后的单词列表
  /// 
  /// 解析规则：
  /// - 第一列为单词，第二列为释义
  /// - 自动跳过第一行（标题行）
  /// - 空行会被忽略
  /// - 支持.xlsx和.xls格式
  static Future<List<Word>> parseExcelFile(String filePath) async {
    List<Word> words = [];
    
    try {
      // 读取Excel文件
      var bytes = File(filePath).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      
      // 获取第一个sheet
      if (excel.tables.isEmpty) {
        return words;
      }
      
      var sheetName = excel.tables.keys.first;
      var sheet = excel.tables[sheetName];
      
      if (sheet == null || sheet.rows.isEmpty) {
        return words;
      }
      
      bool isFirstRow = true;
      
      // 遍历所有行
      for (var row in sheet.rows) {
        // 跳过标题行
        if (isFirstRow) {
          isFirstRow = false;
          continue;
        }
        
        // 确保至少有两列
        if (row.length < 2) continue;
        
        var wordCell = row[0];
        var definitionCell = row[1];
        
        // 跳过空单元格
        if (wordCell == null || definitionCell == null) continue;
        if (wordCell.value == null || definitionCell.value == null) continue;
        
        String word = wordCell.value.toString().trim();
        String definition = definitionCell.value.toString().trim();
        
        // 跳过空值
        if (word.isEmpty || definition.isEmpty) continue;
        
        words.add(Word(
          id: 0, // 临时ID，插入数据库时会分配
          word: word,
          definition: definition,
          createdAt: DateTime.now(),
        ));
      }
    } catch (e) {
      // 解析失败，返回空列表
      // 错误会在调用方处理
      return [];
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
  
  /// 解析Excel文件并返回详细结果
  /// [filePath] Excel文件路径
  /// 返回包含解析结果和错误信息的对象
  static Future<ParseResult> parseExcelFileWithDetails(String filePath) async {
    List<Word> words = [];
    List<String> errors = [];
    int totalRows = 0;
    
    try {
      // 读取Excel文件
      var bytes = File(filePath).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      
      // 检查是否有sheet
      if (excel.tables.isEmpty) {
        errors.add('Excel文件中没有工作表');
        return ParseResult(
          words: words,
          errors: errors,
          totalRows: 0,
          successCount: 0,
        );
      }
      
      var sheetName = excel.tables.keys.first;
      var sheet = excel.tables[sheetName];
      
      if (sheet == null || sheet.rows.isEmpty) {
        errors.add('工作表为空');
        return ParseResult(
          words: words,
          errors: errors,
          totalRows: 0,
          successCount: 0,
        );
      }
      
      totalRows = sheet.rows.length;
      bool isFirstRow = true;
      int rowNumber = 0;
      
      // 遍历所有行
      for (var row in sheet.rows) {
        rowNumber++;
        
        // 跳过标题行
        if (isFirstRow) {
          isFirstRow = false;
          continue;
        }
        
        // 确保至少有两列
        if (row.length < 2) {
          errors.add('第 $rowNumber 行: 列数不足，至少需要两列（单词和释义）');
          continue;
        }
        
        var wordCell = row[0];
        var definitionCell = row[1];
        
        // 检查空单元格
        if (wordCell == null || wordCell.value == null) {
          errors.add('第 $rowNumber 行: 单词列为空');
          continue;
        }
        
        if (definitionCell == null || definitionCell.value == null) {
          errors.add('第 $rowNumber 行: 释义列为空');
          continue;
        }
        
        String word = wordCell.value.toString().trim();
        String definition = definitionCell.value.toString().trim();
        
        // 检查空值
        if (word.isEmpty) {
          errors.add('第 $rowNumber 行: 单词不能为空');
          continue;
        }
        
        if (definition.isEmpty) {
          errors.add('第 $rowNumber 行: 释义不能为空');
          continue;
        }
        
        words.add(Word(
          id: 0,
          word: word,
          definition: definition,
          createdAt: DateTime.now(),
        ));
      }
    } catch (e) {
      errors.add('解析Excel文件失败: ${e.toString()}');
    }
    
    return ParseResult(
      words: words,
      errors: errors,
      totalRows: totalRows,
      successCount: words.length,
    );
  }
  
  /// 检查文件是否为支持的Excel格式
  /// [filePath] 文件路径
  /// 返回true表示支持，false表示不支持
  static bool isSupportedExcelFile(String filePath) {
    String extension = filePath.toLowerCase();
    return extension.endsWith('.xlsx') || extension.endsWith('.xls');
  }
}

/// 解析结果类
class ParseResult {
  final List<Word> words;
  final List<String> errors;
  final int totalRows;
  final int successCount;
  
  ParseResult({
    required this.words,
    required this.errors,
    required this.totalRows,
    required this.successCount,
  });
  
  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess => words.isNotEmpty && errors.isEmpty;
  int get errorCount => errors.length;
}
