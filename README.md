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

## 部署安装

### 1. 后端部署

```bash
# 克隆代码
git clone https://github.com/fx120/english-chinese-word.git
cd english-chinese-word
```

后端基于 FastAdmin 框架，需要先完成 FastAdmin 标准安装：
- PHP >= 7.1，MySQL >= 5.7，Nginx/Apache
- 将 `www.jpwenku.com/` 目录部署为网站根目录
- 配置数据库连接：`www.jpwenku.com/application/database.php`
- 完成 FastAdmin 安装向导

### 2. 导入业务表

```bash
# 导入业务表结构（9张表：用户、单词、词表、学习进度等）
mysql -u root -p your_db < www.jpwenku.com/database/install.sql
```

`install.sql` 包含：
- 9张业务数据表（fa_word, fa_vocabulary_list 等）
- 后台菜单（词表管理、OCR配置、词库导出）
- OCR 系统配置项（百度OCR API密钥，需在后台填写）

### 3. 导入词库数据（可选）

如果需要预置词库，可以导入种子数据：

```bash
mysql -u root -p your_db < www.jpwenku.com/database/seed_data.sql
```

种子数据可以通过后台「词库导出」功能生成，选择需要的词表导出为 SQL 文件。

### 4. 配置 OCR（可选）

在后台「常规管理 > 系统配置 > OCR识别」中填入百度 OCR API 密钥。
或访问「OCR配置」菜单，首次访问会自动初始化配置项。

申请地址：[百度智能云OCR](https://cloud.baidu.com/product/ocr)（免费额度：每月1000次）

### 5. 前端

```bash
cd app
flutter pub get
flutter run
```

需要修改 `app/lib/services/api_client.dart` 中的 `BASE_URL` 为你自己的后端地址。

要求：Flutter SDK >= 3.0.0

### 构建发布

```bash
# Android APK
cd app && flutter build apk

# iOS
cd app && flutter build ios
```

## 许可证

Copyright © 2024-2026
