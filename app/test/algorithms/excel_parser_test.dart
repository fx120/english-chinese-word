import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_vocabulary_app/algorithms/excel_parser.dart';
import 'package:ai_vocabulary_app/models/word.dart';
import 'package:excel/excel.dart';

void main() {
  group('ExcelParser', () {
    late String testFilePath;
    
    setUp(() {
      // 创建临时测试文件路径
      testFilePath = '${Directory.systemTemp.path}/test_vocabulary.xlsx';
    });
    
    tearDown(() {
      // 清理测试文件
      final file = File(testFilePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });
    
    test('should parse valid Excel file with words and definitions', () async {
      // 创建测试Excel文件
      var excel = Excel.createExcel();
      Sheet sheet = excel['Sheet1'];
      
      // 添加标题行
      sheet.appendRow([TextCellValue('单词'), TextCellValue('释义')]);
      
      // 添加数据行
      sheet.appendRow([TextCellValue('hello'), TextCellValue('你好')]);
      sheet.appendRow([TextCellValue('world'), TextCellValue('世界')]);
      sheet.appendRow([TextCellValue('test'), TextCellValue('测试')]);
      
      // 保存文件
      var bytes = excel.encode();
      File(testFilePath).writeAsBytesSync(bytes!);
      
      // 解析文件
      List<Word> words = await ExcelParser.parseExcelFile(testFilePath);
      
      // 验证结果
      expect(words.length, 3);
      expect(words[0].word, 'hello');
      expect(words[0].definition, '你好');
      expect(words[1].word, 'world');
      expect(words[1].definition, '世界');
      expect(words[2].word, 'test');
      expect(words[2].definition, '测试');
    });
    
    test('should skip header row automatically', () async {
      // 创建测试Excel文件
      var excel = Excel.createExcel();
      Sheet sheet = excel['Sheet1'];
      
      // 添加标题行（应该被跳过）
      sheet.appendRow([TextCellValue('Word'), TextCellValue('Definition')]);
      
      // 添加数据行
      sheet.appendRow([TextCellValue('apple'), TextCellValue('苹果')]);
      
      // 保存文件
      var bytes = excel.encode();
      File(testFilePath).writeAsBytesSync(bytes!);
      
      // 解析文件
      List<Word> words = await ExcelParser.parseExcelFile(testFilePath);
      
      // 验证结果 - 应该只有1个单词，标题行被跳过
      expect(words.length, 1);
      expect(words[0].word, 'apple');
      expect(words[0].definition, '苹果');
    });
    
    test('should skip empty rows', () async {
      // 创建测试Excel文件
      var excel = Excel.createExcel();
      Sheet sheet = excel['Sheet1'];
      
      // 添加标题行
      sheet.appendRow([TextCellValue('单词'), TextCellValue('释义')]);
      
      // 添加数据行和空行
      sheet.appendRow([TextCellValue('hello'), TextCellValue('你好')]);
      sheet.appendRow([null, null]); // 空行
      sheet.appendRow([TextCellValue('world'), TextCellValue('世界')]);
      
      // 保存文件
      var bytes = excel.encode();
      File(testFilePath).writeAsBytesSync(bytes!);
      
      // 解析文件
      List<Word> words = await ExcelParser.parseExcelFile(testFilePath);
      
      // 验证结果 - 空行应该被跳过
      expect(words.length, 2);
      expect(words[0].word, 'hello');
      expect(words[1].word, 'world');
    });
    
    test('should skip rows with empty cells', () async {
      // 创建测试Excel文件
      var excel = Excel.createExcel();
      Sheet sheet = excel['Sheet1'];
      
      // 添加标题行
      sheet.appendRow([TextCellValue('单词'), TextCellValue('释义')]);
      
      // 添加数据行，包含空单元格
      sheet.appendRow([TextCellValue('hello'), TextCellValue('你好')]);
      sheet.appendRow([TextCellValue(''), TextCellValue('空单词')]); // 空单词
      sheet.appendRow([TextCellValue('empty'), TextCellValue('')]); // 空释义
      sheet.appendRow([TextCellValue('world'), TextCellValue('世界')]);
      
      // 保存文件
      var bytes = excel.encode();
      File(testFilePath).writeAsBytesSync(bytes!);
      
      // 解析文件
      List<Word> words = await ExcelParser.parseExcelFile(testFilePath);
      
      // 验证结果 - 空单元格的行应该被跳过
      expect(words.length, 2);
      expect(words[0].word, 'hello');
      expect(words[1].word, 'world');
    });
    
    test('should validate parsed words correctly', () async {
      // 创建测试Excel文件
      var excel = Excel.createExcel();
      Sheet sheet = excel['Sheet1'];
      
      sheet.appendRow([TextCellValue('单词'), TextCellValue('释义')]);
      sheet.appendRow([TextCellValue('hello'), TextCellValue('你好')]);
      sheet.appendRow([TextCellValue('world'), TextCellValue('世界')]);
      
      var bytes = excel.encode();
      File(testFilePath).writeAsBytesSync(bytes!);
      
      List<Word> words = await ExcelParser.parseExcelFile(testFilePath);
      
      // 验证解析结果
      expect(ExcelParser.validateParsedWords(words), true);
    });
    
    test('should detect duplicate words in validation', () {
      List<Word> words = [
        Word(id: 0, word: 'hello', definition: '你好', createdAt: DateTime.now()),
        Word(id: 0, word: 'world', definition: '世界', createdAt: DateTime.now()),
        Word(id: 0, word: 'hello', definition: '嗨', createdAt: DateTime.now()), // 重复
      ];
      
      expect(ExcelParser.validateParsedWords(words), false);
    });
    
    test('should return empty list for empty Excel file', () async {
      // 创建空Excel文件
      var excel = Excel.createExcel();
      Sheet sheet = excel['Sheet1'];
      
      // 只有标题行
      sheet.appendRow([TextCellValue('单词'), TextCellValue('释义')]);
      
      var bytes = excel.encode();
      File(testFilePath).writeAsBytesSync(bytes!);
      
      List<Word> words = await ExcelParser.parseExcelFile(testFilePath);
      
      expect(words.isEmpty, true);
    });
    
    test('should parse Excel file with details and report errors', () async {
      // 创建测试Excel文件
      var excel = Excel.createExcel();
      Sheet sheet = excel['Sheet1'];
      
      sheet.appendRow([TextCellValue('单词'), TextCellValue('释义')]);
      sheet.appendRow([TextCellValue('hello'), TextCellValue('你好')]);
      sheet.appendRow([TextCellValue(''), TextCellValue('空单词')]); // 错误行
      sheet.appendRow([TextCellValue('world'), TextCellValue('世界')]);
      
      var bytes = excel.encode();
      File(testFilePath).writeAsBytesSync(bytes!);
      
      ParseResult result = await ExcelParser.parseExcelFileWithDetails(testFilePath);
      
      expect(result.successCount, 2);
      expect(result.hasErrors, true);
      expect(result.errorCount, 1);
      expect(result.errors[0], contains('单词不能为空'));
    });
    
    test('should check if file is supported Excel format', () {
      expect(ExcelParser.isSupportedExcelFile('test.xlsx'), true);
      expect(ExcelParser.isSupportedExcelFile('test.xls'), true);
      expect(ExcelParser.isSupportedExcelFile('test.XLSX'), true);
      expect(ExcelParser.isSupportedExcelFile('test.txt'), false);
      expect(ExcelParser.isSupportedExcelFile('test.csv'), false);
    });
  });
}
