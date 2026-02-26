# Task 11.4 实现文件导入对话框 - 实施文档

## 任务概述

实现文件导入对话框组件，支持文本文件、Excel文件和OCR拍照（预留）三种导入方式。

## 实施内容

### 1. 创建的文件

- `app/lib/ui/widgets/import_dialog.dart` - 文件导入对话框组件

### 2. 组件功能

#### 2.1 导入方式选择
- 文本文件导入（.txt）
- Excel文件导入（.xlsx, .xls）
- OCR拍照导入（预留，显示为禁用状态）

#### 2.2 文件选择
- 使用 `file_picker` 包选择文本和Excel文件
- 使用 `image_picker` 包选择相机拍照（OCR预留）
- 支持的文件格式验证

#### 2.3 词表信息输入
- 词表名称输入（必填，最多50字符）
- 词表描述输入（可选，最多200字符）
- 显示选中的文件名

#### 2.4 导入进度显示
- 显示加载指示器
- 显示导入状态提示

#### 2.5 导入结果显示
- 成功：显示导入的单词数量和词表信息
- 失败：显示错误信息和重试选项

### 3. 状态管理

#### 3.1 导入状态（ImportState）
```dart
enum ImportState {
  selectMethod,  // 选择导入方式
  inputInfo,     // 输入词表信息
  importing,     // 导入中
  success,       // 导入成功
  error,         // 导入失败
}
```

#### 3.2 导入方式（ImportMethod）
```dart
enum ImportMethod {
  text,   // 文本文件
  excel,  // Excel文件
  ocr,    // OCR拍照
}
```

### 4. 用户交互流程

```
1. 打开对话框 → 选择导入方式
   ↓
2. 选择文件（通过系统文件选择器）
   ↓
3. 输入词表名称和描述
   ↓
4. 点击"开始导入"按钮
   ↓
5. 显示导入进度
   ↓
6. 显示导入结果（成功/失败）
   ↓
7. 点击"完成"关闭对话框并返回结果
```

### 5. 集成方式

#### 5.1 在页面中使用

```dart
// 显示导入对话框
final result = await showDialog<VocabularyList>(
  context: context,
  builder: (context) => ImportDialog(
    vocabularyManager: vocabularyManager,
  ),
);

// 处理导入结果
if (result != null) {
  // 导入成功，result 是创建的词表对象
  print('导入成功: ${result.name}');
}
```

#### 5.2 依赖注入

对话框需要 `VocabularyManager` 实例来执行导入操作：

```dart
final vocabularyManager = context.read<VocabularyManager>();
```

### 6. UI设计特点

#### 6.1 响应式布局
- 使用 `Dialog` 组件，最大宽度500px
- 适配不同屏幕尺寸

#### 6.2 视觉反馈
- 导入方式选项使用卡片式设计
- 禁用的选项显示灰色
- 成功/失败使用不同颜色的图标和提示

#### 6.3 用户体验
- 支持返回上一步
- 支持取消操作
- 错误信息清晰明确
- 提供重试功能

### 7. 错误处理

#### 7.1 文件选择错误
- 捕获文件选择器异常
- 显示友好的错误提示

#### 7.2 导入错误
- 捕获解析错误（格式错误、编码错误等）
- 捕获数据库错误
- 显示详细的错误信息

#### 7.3 验证错误
- 词表名称不能为空
- 文件格式必须正确

### 8. 依赖的包

- `file_picker: ^6.1.1` - 文件选择
- `image_picker: ^1.0.7` - 图片/相机选择
- `flutter/material.dart` - UI组件

### 9. 与VocabularyManager的集成

对话框调用以下VocabularyManager方法：

```dart
// 导入文本文件
Future<VocabularyList> importFromText(
  File file, {
  required String name,
  String? description,
  String? category,
})

// 导入Excel文件
Future<VocabularyList> importFromExcel(
  File file, {
  required String name,
  String? description,
  String? category,
})

// 导入OCR图片（预留）
Future<List<Word>> importFromOCR(File image)
```

### 10. 测试建议

#### 10.1 单元测试
- 测试状态转换逻辑
- 测试输入验证
- 测试错误处理

#### 10.2 Widget测试
- 测试UI渲染
- 测试用户交互
- 测试不同状态的显示

#### 10.3 集成测试
- 测试完整的导入流程
- 测试文件选择
- 测试导入成功/失败场景

### 11. 未来改进

#### 11.1 OCR功能实现
- 集成OCR服务（百度OCR、腾讯OCR等）
- 实现图片预处理
- 实现识别结果编辑

#### 11.2 批量导入
- 支持一次选择多个文件
- 显示批量导入进度

#### 11.3 导入预览
- 在导入前预览解析结果
- 允许用户编辑和确认

#### 11.4 导入历史
- 记录导入历史
- 支持重新导入

## 验收标准

- [x] 创建 `app/lib/ui/widgets/import_dialog.dart`
- [x] 实现文本文件选择和导入
- [x] 实现Excel文件选择和导入
- [x] 实现OCR拍照和导入（预留接口）
- [x] 显示导入进度和结果
- [x] 显示错误提示
- [x] 集成VocabularyManager
- [x] 响应式UI设计
- [x] 完整的错误处理

## 相关需求

- 需求 4.1-4.6: 用户导入Text文件词表
- 需求 5.1-5.6: 用户导入Excel文件词表
- 需求 6.1-6.8: 用户拍照OCR导入词表

## 相关文件

- `app/lib/managers/vocabulary_manager.dart` - 词表管理器
- `app/lib/algorithms/text_parser.dart` - 文本解析器
- `app/lib/algorithms/excel_parser.dart` - Excel解析器
- `app/lib/models/vocabulary_list.dart` - 词表模型
- `app/lib/models/word.dart` - 单词模型

## 实施日期

2024年（根据实际日期填写）

## 实施人员

Kiro AI Assistant
