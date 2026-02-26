import 'package:flutter_test/flutter_test.dart';
import 'package:ai_vocabulary_app/algorithms/text_parser.dart';
import 'package:ai_vocabulary_app/models/word.dart';

void main() {
  group('TextParser', () {
    test('parseTextFile - 解析空格分隔的文本', () {
      const content = '''
hello 你好
world 世界
test 测试
''';
      
      final words = TextParser.parseTextFile(content);
      
      expect(words.length, 3);
      expect(words[0].word, 'hello');
      expect(words[0].definition, '你好');
      expect(words[1].word, 'world');
      expect(words[1].definition, '世界');
      expect(words[2].word, 'test');
      expect(words[2].definition, '测试');
    });
    
    test('parseTextFile - 解析制表符分隔的文本', () {
      const content = 'apple\t苹果\nbanana\t香蕉';
      
      final words = TextParser.parseTextFile(content);
      
      expect(words.length, 2);
      expect(words[0].word, 'apple');
      expect(words[0].definition, '苹果');
      expect(words[1].word, 'banana');
      expect(words[1].definition, '香蕉');
    });
    
    test('parseTextFile - 忽略空行', () {
      const content = '''
hello 你好

world 世界

''';
      
      final words = TextParser.parseTextFile(content);
      
      expect(words.length, 2);
    });
    
    test('parseTextFile - 处理多个空格的释义', () {
      const content = 'hello 你好 世界 欢迎';
      
      final words = TextParser.parseTextFile(content);
      
      expect(words.length, 1);
      expect(words[0].word, 'hello');
      expect(words[0].definition, '你好 世界 欢迎');
    });
    
    test('parseTextFile - 空内容返回空列表', () {
      const content = '';
      
      final words = TextParser.parseTextFile(content);
      
      expect(words.isEmpty, true);
    });
    
    test('validateParsedWords - 有效的单词列表', () {
      final words = [
        Word(
          id: 0,
          word: 'hello',
          definition: '你好',
          createdAt: DateTime.now(),
        ),
        Word(
          id: 0,
          word: 'world',
          definition: '世界',
          createdAt: DateTime.now(),
        ),
      ];
      
      expect(TextParser.validateParsedWords(words), true);
    });
    
    test('validateParsedWords - 空列表无效', () {
      final words = <Word>[];
      
      expect(TextParser.validateParsedWords(words), false);
    });
    
    test('validateParsedWords - 重复单词无效', () {
      final words = [
        Word(
          id: 0,
          word: 'hello',
          definition: '你好',
          createdAt: DateTime.now(),
        ),
        Word(
          id: 0,
          word: 'hello',
          definition: '你好啊',
          createdAt: DateTime.now(),
        ),
      ];
      
      expect(TextParser.validateParsedWords(words), false);
    });
    
    test('parseTextFileWithDetails - 返回详细错误信息', () {
      const content = '''
hello 你好
invalidline
world 世界
 释义
''';
      
      final result = TextParser.parseTextFileWithDetails(content);
      
      expect(result.successCount, 2);
      expect(result.errorCount, 2);
      expect(result.hasErrors, true);
      expect(result.errors.length, 2);
    });
    
    test('parseTextFileWithDetails - 成功解析无错误', () {
      const content = '''
hello 你好
world 世界
''';
      
      final result = TextParser.parseTextFileWithDetails(content);
      
      expect(result.successCount, 2);
      expect(result.errorCount, 0);
      expect(result.isSuccess, true);
    });
    
    test('parseTextFile - 支持UTF-8编码', () {
      const content = '''
你好 hello
世界 world
测试 test
日本語 Japanese
한국어 Korean
''';
      
      final words = TextParser.parseTextFile(content);
      
      expect(words.length, 5);
      expect(words[0].word, '你好');
      expect(words[0].definition, 'hello');
      expect(words[3].word, '日本語');
      expect(words[3].definition, 'Japanese');
      expect(words[4].word, '한국어');
      expect(words[4].definition, 'Korean');
    });
  });
}
