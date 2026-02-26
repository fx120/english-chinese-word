# AI背单词应用

AI背单词应用是一个移动端词汇学习应用，帮助用户通过多种方式导入词表、系统化学习单词，并基于记忆曲线进行智能复习。

## 技术栈

- **前端**: Flutter (Dart)
- **后端**: FastAdmin (PHP)
- **数据库**: MySQL (后端) + SQLite (前端本地)

## 项目结构

```
app/
├── lib/
│   ├── algorithms/          # 核心算法
│   │   ├── memory_curve_algorithm.dart
│   │   ├── random_learning_algorithm.dart
│   │   ├── sequential_learning_algorithm.dart
│   │   └── text_parser.dart
│   ├── database/            # 数据库
│   │   ├── local_database.dart
│   │   └── schema.dart
│   ├── managers/            # 业务管理器
│   │   ├── auth_manager.dart
│   │   ├── learning_manager.dart
│   │   ├── review_manager.dart
│   │   ├── statistics_manager.dart
│   │   ├── sync_manager.dart
│   │   └── vocabulary_manager.dart
│   ├── models/              # 数据模型
│   │   ├── daily_record.dart
│   │   ├── enums.dart
│   │   ├── user.dart
│   │   ├── user_statistics.dart
│   │   ├── user_word_progress.dart
│   │   ├── vocabulary_list.dart
│   │   └── word.dart
│   ├── providers/           # 状态管理
│   │   ├── auth_provider.dart
│   │   ├── learning_provider.dart
│   │   ├── review_provider.dart
│   │   ├── statistics_provider.dart
│   │   └── vocabulary_provider.dart
│   ├── services/            # 服务层
│   │   └── api_client.dart
│   ├── ui/                  # 用户界面
│   │   └── pages/
│   │       ├── login_page.dart
│   │       ├── main_page.dart
│   │       ├── statistics_page.dart
│   │       └── vocabulary_list_page.dart
│   └── main.dart
├── android/                 # Android配置
├── ios/                     # iOS配置
└── pubspec.yaml            # 依赖配置
```

## 开始使用

### 前置要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / Xcode (用于移动端开发)

### 安装依赖

```bash
cd app
flutter pub get
```

### 运行应用

```bash
flutter run
```

### 构建应用

```bash
# Android
flutter build apk

# iOS
flutter build ios
```

## 核心功能

1. **用户认证**: 手机号验证码登录
2. **词表管理**: 下载官方词表、导入自定义词表
3. **学习模式**: 随机学习、顺序学习
4. **复习模式**: 记忆曲线复习、错题复习
5. **学习统计**: 学习天数、掌握单词数、学习曲线
6. **数据同步**: 本地数据与云端同步

## 开发规范

- 遵循 Flutter 官方代码规范
- 使用 Provider 进行状态管理
- 使用 SQLite 进行本地数据存储
- 使用 Dio 进行网络请求

## 许可证

Copyright © 2024
