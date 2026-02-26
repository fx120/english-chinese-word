import 'dart:convert';
import '../models/word.dart';

/// JSON词表解析器
/// 支持解析网络获取的词表JSON格式
/// 
/// 每行一个JSON对象，格式如：
/// {"wordRank":1,"headWord":"beddings","content":{"word":{...}},"bookId":"GaoZhongluan_2"}
/// 
/// 支持自动提取：单词、音标、词性、释义、例句
class JsonVocabularyParser {
  /// 解析JSON词表内容
  /// 
  /// [content] JSON文件内容，每行一个JSON对象，或整个文件为JSON数组
  /// 返回解析结果，包含按bookId分组的词表信息
  static JsonParseResult parseJsonContent(String content) {
    final List<JsonWordEntry> entries = [];
    final List<String> errors = [];
    int totalCount = 0;

    // 尝试按行解析（每行一个JSON对象）
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // 尝试检测是否为连续的JSON对象（无换行分隔）
    if (lines.length == 1 && lines[0].trim().startsWith('{')) {
      // 可能是多个JSON对象连在一起，尝试拆分
      final splitEntries = _splitConcatenatedJson(lines[0].trim());
      if (splitEntries.length > 1) {
        for (int i = 0; i < splitEntries.length; i++) {
          totalCount++;
          try {
            final entry = _parseSingleEntry(splitEntries[i]);
            if (entry != null) entries.add(entry);
          } catch (e) {
            errors.add('第 ${i + 1} 条: 解析失败 - ${e.toString()}');
          }
        }
      } else {
        // 单个JSON对象
        totalCount = 1;
        try {
          final entry = _parseSingleEntry(jsonDecode(lines[0].trim()));
          if (entry != null) entries.add(entry);
        } catch (e) {
          errors.add('解析失败: ${e.toString()}');
        }
      }
    } else if (lines.length == 1 && lines[0].trim().startsWith('[')) {
      // JSON数组格式
      try {
        final list = jsonDecode(lines[0].trim()) as List;
        totalCount = list.length;
        for (int i = 0; i < list.length; i++) {
          try {
            final entry = _parseSingleEntry(list[i]);
            if (entry != null) entries.add(entry);
          } catch (e) {
            errors.add('第 ${i + 1} 条: 解析失败 - ${e.toString()}');
          }
        }
      } catch (e) {
        errors.add('JSON数组解析失败: ${e.toString()}');
      }
    } else {
      // 多行格式，每行一个JSON
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        totalCount++;
        try {
          final json = jsonDecode(line);
          final entry = _parseSingleEntry(json);
          if (entry != null) entries.add(entry);
        } catch (e) {
          errors.add('第 ${i + 1} 行: 解析失败 - ${e.toString()}');
        }
      }
    }

    // 按bookId分组
    final Map<String, List<JsonWordEntry>> grouped = {};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.bookId, () => []);
      grouped[entry.bookId]!.add(entry);
    }

    // 每组按wordRank排序
    for (final list in grouped.values) {
      list.sort((a, b) => a.wordRank.compareTo(b.wordRank));
    }

    return JsonParseResult(
      entries: entries,
      groupedByBook: grouped,
      errors: errors,
      totalCount: totalCount,
      successCount: entries.length,
    );
  }

  /// 拆分连续的JSON对象字符串
  static List<Map<String, dynamic>> _splitConcatenatedJson(String text) {
    final List<Map<String, dynamic>> results = [];
    int depth = 0;
    int start = 0;

    for (int i = 0; i < text.length; i++) {
      if (text[i] == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (text[i] == '}') {
        depth--;
        if (depth == 0) {
          try {
            final jsonStr = text.substring(start, i + 1);
            results.add(jsonDecode(jsonStr) as Map<String, dynamic>);
          } catch (_) {}
        }
      }
    }
    return results;
  }

  /// 解析单个词条
  static JsonWordEntry? _parseSingleEntry(Map<String, dynamic> json) {
    final headWord = json['headWord'] as String?;
    final bookId = json['bookId'] as String? ?? 'unknown';
    final wordRank = json['wordRank'] as int? ?? 0;

    if (headWord == null || headWord.isEmpty) return null;

    final content = json['content'] as Map<String, dynamic>?;
    final wordData = content?['word'] as Map<String, dynamic>?;
    final wordContent = wordData?['content'] as Map<String, dynamic>?;

    // 提取音标（优先美式）
    String? phonetic;
    if (wordContent != null) {
      phonetic = wordContent['usphone'] as String? ??
          wordContent['ukphone'] as String? ??
          wordContent['phone'] as String?;
    }

    // 提取词性和释义
    String partOfSpeech = '';
    String definition = '';
    final trans = wordContent?['trans'] as List?;
    if (trans != null && trans.isNotEmpty) {
      final parts = <String>[];
      final posList = <String>[];
      for (final t in trans) {
        final pos = t['pos'] as String? ?? '';
        final cn = t['tranCn'] as String? ?? '';
        if (cn.isNotEmpty) {
          if (pos.isNotEmpty) {
            parts.add('$pos. $cn');
            if (!posList.contains(pos)) posList.add(pos);
          } else {
            parts.add(cn);
          }
        }
      }
      definition = parts.join('；');
      partOfSpeech = posList.join('/');
    }

    if (definition.isEmpty) return null;

    // 提取例句
    String? example;
    final sentenceData = wordContent?['sentence'] as Map<String, dynamic>?;
    final sentences = sentenceData?['sentences'] as List?;
    if (sentences != null && sentences.isNotEmpty) {
      final s = sentences[0];
      final en = s['sContent'] as String? ?? '';
      final cn = s['sCn'] as String? ?? '';
      if (en.isNotEmpty) {
        example = cn.isNotEmpty ? '$en\n$cn' : en;
      }
    }

    return JsonWordEntry(
      headWord: headWord,
      bookId: bookId,
      wordRank: wordRank,
      phonetic: phonetic,
      partOfSpeech: partOfSpeech,
      definition: definition,
      example: example,
    );
  }

  /// 将解析结果转换为Word列表
  static List<Word> toWordList(List<JsonWordEntry> entries) {
    return entries.map((e) => Word(
      id: 0,
      word: e.headWord,
      phonetic: e.phonetic,
      partOfSpeech: e.partOfSpeech,
      definition: e.definition,
      example: e.example,
      createdAt: DateTime.now(),
    )).toList();
  }

  /// 根据bookId生成可读的词表名称
  static String bookIdToName(String bookId) {
    // 常见bookId映射
    const nameMap = {
      'GaoZhongluan_2': '高中核心词汇',
      'ChuZhongluan_2': '初中核心词汇',
      'CET4luan_2': '四级核心词汇',
      'CET6luan_2': '六级核心词汇',
      'KaoYanluan_2': '考研核心词汇',
    };
    if (nameMap.containsKey(bookId)) return nameMap[bookId]!;
    // 尝试从bookId提取可读名称
    return bookId.replaceAll('_', ' ').replaceAll('luan', '');
  }
}

/// 单个词条解析结果
class JsonWordEntry {
  final String headWord;
  final String bookId;
  final int wordRank;
  final String? phonetic;
  final String partOfSpeech;
  final String definition;
  final String? example;

  JsonWordEntry({
    required this.headWord,
    required this.bookId,
    required this.wordRank,
    this.phonetic,
    required this.partOfSpeech,
    required this.definition,
    this.example,
  });
}

/// JSON解析总结果
class JsonParseResult {
  final List<JsonWordEntry> entries;
  final Map<String, List<JsonWordEntry>> groupedByBook;
  final List<String> errors;
  final int totalCount;
  final int successCount;

  JsonParseResult({
    required this.entries,
    required this.groupedByBook,
    required this.errors,
    required this.totalCount,
    required this.successCount,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess => entries.isNotEmpty;
  int get bookCount => groupedByBook.length;
}
