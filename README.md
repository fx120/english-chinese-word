# AI背单词

一款面向中小学生的英语单词学习应用，支持多种词表导入方式、基于记忆曲线的智能复习、OCR拍照识别纸质词表等功能。

## 技术架构

| 层级 | 技术栈 | 目录 |
|------|--------|------|
| 前端 | Flutter (Dart) | `app/` |
| 后端 | FastAdmin (ThinkPHP 5.x / PHP) | `www.jpwenku.com/` |
| 数据库 | MySQL (云端) + SQLite (本地) | - |
| 文档 | Markdown | `doc/` |

## 核心功能

### 词表管理
- 下载官方词表（线上词库）
- 文本/Excel/JSON 导入自定义词表
- **OCR拍照识别**：拍摄纸质课本词表，自动解析单词、音标、释义
  - 支持多页连续拍照，合并到同一词表
  - 支持区域框选，只识别选中区域
  - 自动处理双列排版（课本常见格式）
  - 从线上词库匹配准确音标和例句

### 学习模式
- 顺序学习 / 随机学习
- 单词卡片翻转交互
- 发音播放（美音/英音）

### 复习系统
- 基于艾宾浩斯记忆曲线的智能复习调度
- 复习优先级算法
- 错题重点复习

### 搜索
- 云端词典搜索（按单词名去重）
- 显示单词所属词表来源
- 支持中英文搜索

### 学习统计
- 连续学习天数
- 每日学习/复习单词数
- 掌握进度可视化

### 其他
- 手机号验证码登录
- 本地数据与云端同步
- 后台管理（FastAdmin）：词表管理、单词管理、OCR配置

## 项目结构

```
├── app/                          # Flutter 前端
│   ├── lib/
│   │   ├── algorithms/           # 核心算法（记忆曲线、解析器等）
│   │   ├── database/             # SQLite 本地数据库
│   │   ├── managers/             # 业务逻辑管理器
│   │   ├── models/               # 数据模型
│   │   ├── providers/            # 状态管理 (Provider)
│   │   ├── services/             # API 客户端
│   │   ├── ui/pages/             # 页面
│   │   ├── ui/widgets/           # 通用组件
│   │   └── main.dart
│   ├── android/                  # Android 配置
│   ├── macos/                    # macOS 配置
│   └── pubspec.yaml
│
├── www.jpwenku.com/              # FastAdmin 后端
│   ├── application/
│   │   ├── api/controller/       # API 接口
│   │   ├── admin/controller/     # 后台管理控制器
│   │   ├── common/library/       # 公共服务（OcrService 等）
│   │   └── extra/                # 配置文件
│   └── database/migrations/      # 数据库迁移脚本
│
└── doc/                          # 项目文档
```

## 快速开始

### 前端

```bash
cd app
flutter pub get
flutter run
```

要求：Flutter SDK >= 3.0.0

### 后端

FastAdmin 标准部署，配置数据库连接后即可运行。OCR 功能需要在后台「常规管理 > 系统配置 > OCR识别」中配置百度 OCR API 密钥。

## 构建

```bash
# Android APK
cd app && flutter build apk

# iOS
cd app && flutter build ios
```

## 许可证

Copyright © 2024-2026
