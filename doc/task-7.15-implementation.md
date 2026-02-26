# Task 7.15 实现文本解析算法 - 实施文档

## 任务概述

实现文本文件解析算法，支持从文本文件中解析单词和释义。

## 实施时间

2024年（具体日期根据实际情况）

## 需求追溯

- 需求 4.2: 支持解析每行格式为"单词 释义"或"单词\t释义"的文本
- 需求 4.4: 支持UTF-8编码
- 需求 15.1-15.5: 文本解析器的详细验收标准

## 实施内容

### 1. 创建文本解析器类

**文件位置**: `app/lib/algorithms/text_parser.dart`

**核心功能**:

1. **parseTextFile** - 基础解析方法
   - 支持空格分隔符
   - 支持制表符分隔符
   - 忽略空行
   - 支持UTF-8编码
   - 处理多个空格的释义（第一个空格前为单词，其余为释义）

2. **validateParsedWords** - 验证解析结果
   - 检查列表是否为空
   - 检查是否有重复单词

3. **parseTextFileWithDetails** - 详细解析方法
   - 返回解析成功的单词列表
   - 返回详细的错误信息（包含行号）
   - 提供统计信息（总行数、成功数、错误数）

### 2. 解析规则

#### 支持的格式

1. **空格分隔**:
   ```
   hello 你好
   world 世界
   ```

2. **制表符分隔**:
   ```
   hello\t你好
   world\t世界
   ```

3. **多个空格的释义**:
   ```
   hello 你好 世界 欢迎
   ```
   解析结果: 单词="hello", 释义="你好 世界 欢迎"

#### 处理规则

- 空行会被自动忽略
- 每行首尾的空白字符会被去除
- 如果一行包含制表符，优先使用制表符分隔
- 如果一行只包含空格，使用第一个空格作为分隔点
- 单词和释义都不能为空

### 3. 错误处理

**parseTextFileWithDetails** 方法提供详细的错误信息：

- 格式错误（缺少分隔符）
- 单词为空
- 释义为空
- 每个错误都包含具体的行号

### 4. UTF-8 编码支持

解析器完全支持UTF-8编码，可以正确处理：
- 中文字符
- 日文字符
- 韩文字符
- 其他Unicode字符

## 测试验证

### 测试文件

**文件位置**: `app/test/algorithms/text_parser_test.dart`

### 测试用例

1. ✅ 解析空格分隔的文本
2. ✅ 解析制表符分隔的文本
3. ✅ 忽略空行
4. ✅ 处理多个空格的释义
5. ✅ 空内容返回空列表
6. ✅ 验证有效的单词列表
7. ✅ 验证空列表无效
8. ✅ 验证重复单词无效
9. ✅ 返回详细错误信息
10. ✅ 成功解析无错误
11. ✅ 支持UTF-8编码

### 测试结果

```
00:05 +11: All tests passed!
```

所有11个测试用例全部通过。

## 代码示例

### 基础使用

```dart
import 'package:ai_vocabulary_app/algorithms/text_parser.dart';

// 解析文本内容
const content = '''
hello 你好
world 世界
test 测试
''';

final words = TextParser.parseTextFile(content);
print('解析到 ${words.length} 个单词');

// 验证解析结果
if (TextParser.validateParsedWords(words)) {
  print('解析结果有效');
} else {
  print('解析结果无效（可能有重复单词）');
}
```

### 详细错误处理

```dart
// 使用详细解析方法
const content = '''
hello 你好
invalidline
world 世界
''';

final result = TextParser.parseTextFileWithDetails(content);

print('成功解析: ${result.successCount} 个单词');
print('错误数量: ${result.errorCount}');

if (result.hasErrors) {
  print('错误详情:');
  for (var error in result.errors) {
    print('  - $error');
  }
}

// 使用解析的单词
for (var word in result.words) {
  print('${word.word}: ${word.definition}');
}
```

## 技术细节

### 分隔符处理逻辑

1. 首先检查行中是否包含制表符 `\t`
2. 如果包含制表符，使用制表符分割
3. 如果不包含制表符，查找第一个空格的位置
4. 使用第一个空格作为分隔点，将行分为两部分

### 性能考虑

- 使用 `String.indexOf` 而不是正则表达式分割，提高性能
- 单次遍历处理所有行
- 避免不必要的字符串操作

## 集成说明

### 在VocabularyManager中使用

```dart
class VocabularyManager {
  Future<VocabularyList> importFromText(File file) async {
    // 读取文件内容
    final content = await file.readAsString();
    
    // 解析文本
    final result = TextParser.parseTextFileWithDetails(content);
    
    // 检查错误
    if (result.hasErrors) {
      throw Exception('解析失败:\n${result.errors.join('\n')}');
    }
    
    // 创建词表
    final list = await _createVocabularyList(result.words);
    
    return list;
  }
}
```

## 符合的需求

✅ 需求 4.2: 支持解析每行格式为"单词 释义"或"单词\t释义"的文本  
✅ 需求 4.4: 支持UTF-8编码  
✅ 需求 15.1: 解析有效的文本文件  
✅ 需求 15.2: 支持空格和制表符作为分隔符  
✅ 需求 15.3: 忽略空行  
✅ 需求 15.4: 支持UTF-8编码  
✅ 需求 15.5: 返回单词列表  

## 后续任务

- [ ] 7.16: 编写属性测试 - 文本解析往返属性
- [ ] 7.17: 编写属性测试 - 文本解析分隔符支持
- [ ] 集成到VocabularyManager中
- [ ] 添加UI界面支持文件选择和导入

## 注意事项

1. **编码问题**: 确保文件以UTF-8编码保存，否则可能出现乱码
2. **格式要求**: 每行必须包含分隔符（空格或制表符），否则该行会被跳过
3. **重复检查**: validateParsedWords方法会检查重复单词，但parseTextFile不会自动去重
4. **临时ID**: 解析后的Word对象的id字段为0，需要在插入数据库时分配实际ID

## 总结

Task 7.15 已成功完成，实现了完整的文本解析算法，支持：
- 空格和制表符两种分隔符
- UTF-8编码
- 详细的错误报告
- 完善的测试覆盖

所有测试用例通过，代码质量良好，可以进入下一阶段的集成工作。
