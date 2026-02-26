# 后端集成测试文档

## 概述

本目录包含AI背单词应用后端API的集成测试。测试使用PHPUnit框架，覆盖以下核心功能：

1. **用户注册登录流程** (`AuthIntegrationTest.php`)
2. **词表下载流程** (`VocabularyDownloadIntegrationTest.php`)
3. **数据同步流程** (`DataSyncIntegrationTest.php`)

## 测试覆盖的需求

### 用户认证测试 (需求 1.1-1.4)
- ✅ 完整的验证码登录流程
- ✅ 验证码时效性（5分钟）
- ✅ JWT令牌生成和有效期（30天）
- ✅ 错误验证码处理
- ✅ 过期验证码处理
- ✅ 验证码重复使用防护
- ✅ 同一手机号使用同一账户

### 词表下载测试 (需求 2.1-2.10)
- ✅ 完整的词表下载流程
- ✅ 词表和单词数据结构
- ✅ 单词全局一致性
- ✅ 单词多对多关联
- ✅ 词表按分类查询
- ✅ 词表单词数量统计
- ✅ 重复下载防护
- ✅ 单词排序顺序

### 数据同步测试 (需求 3.1-3.8, 14.1-14.7)
- ✅ 完整的学习进度同步流程
- ✅ 同步冲突解决策略
- ✅ 排除单词同步
- ✅ 统计数据同步
- ✅ 增量同步
- ✅ 多设备数据合并
- ✅ 同步时间戳记录

## 环境要求

- PHP >= 7.4
- MySQL >= 5.7
- Composer
- PHPUnit >= 9.5

## 安装依赖

首先需要安装PHPUnit测试框架：

```bash
cd www.jpwenku.com
composer require --dev phpunit/phpunit ^9.5
```

## 数据库配置

测试使用独立的测试数据库，需要在 `application/database.php` 中配置：

```php
// 测试环境数据库配置
if (getenv('APP_ENV') === 'testing') {
    return [
        'type'            => 'mysql',
        'hostname'        => '127.0.0.1',
        'database'        => 'test_vocabulary_app',
        'username'        => 'root',
        'password'        => '',
        'hostport'        => '3306',
        'charset'         => 'utf8mb4',
        'prefix'          => 'fa_',
    ];
}
```

创建测试数据库：

```sql
CREATE DATABASE test_vocabulary_app CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

运行数据库迁移脚本创建测试表结构（使用与生产环境相同的表结构）。

## 运行测试

### 运行所有集成测试

```bash
cd www.jpwenku.com
./vendor/bin/phpunit tests/integration
```

### 运行特定测试文件

```bash
# 运行用户认证测试
./vendor/bin/phpunit tests/integration/AuthIntegrationTest.php

# 运行词表下载测试
./vendor/bin/phpunit tests/integration/VocabularyDownloadIntegrationTest.php

# 运行数据同步测试
./vendor/bin/phpunit tests/integration/DataSyncIntegrationTest.php
```

### 运行特定测试方法

```bash
./vendor/bin/phpunit --filter testCompleteVerificationCodeLoginFlow tests/integration/AuthIntegrationTest.php
```

### 生成代码覆盖率报告

```bash
./vendor/bin/phpunit --coverage-html coverage tests/integration
```

报告将生成在 `coverage/` 目录中，使用浏览器打开 `coverage/index.html` 查看。

## 测试结构

### 基础测试类 (`TestCase.php`)

提供通用的测试辅助方法：

- `createTestUser()` - 创建测试用户
- `generateTestToken()` - 生成JWT令牌
- `createTestSmsCode()` - 创建验证码
- `createTestWord()` - 创建测试单词
- `createTestVocabularyList()` - 创建测试词表
- `attachWordToList()` - 关联单词到词表
- `createUserVocabularyList()` - 创建用户词表关联
- `createUserWordProgress()` - 创建学习进度

### 测试隔离

每个测试方法都在独立的数据库事务中运行：

- `setUp()` - 开启事务
- `tearDown()` - 回滚事务

这确保测试之间互不影响，测试数据自动清理。

## 测试命名规范

测试方法使用描述性命名，清晰表达测试意图：

```php
/**
 * @test
 * 测试完整的验证码登录流程
 * 
 * 验证需求: 1.1-1.4
 */
public function testCompleteVerificationCodeLoginFlow()
{
    // 测试代码
}
```

## 断言方法

常用的断言方法：

- `assertEquals($expected, $actual)` - 断言相等
- `assertNotEmpty($value)` - 断言非空
- `assertGreaterThan($expected, $actual)` - 断言大于
- `assertCount($expectedCount, $array)` - 断言数组长度
- `assertArrayHasKey($key, $array)` - 断言数组包含键
- `assertTrue($condition)` - 断言为真
- `assertFalse($condition)` - 断言为假

## 持续集成

建议在CI/CD流程中自动运行测试：

```yaml
# .gitlab-ci.yml 示例
test:
  stage: test
  script:
    - composer install
    - php think migrate:run --env=testing
    - ./vendor/bin/phpunit tests/integration
  only:
    - merge_requests
    - master
```

## 故障排查

### 测试失败

1. 检查数据库连接配置
2. 确认测试数据库已创建
3. 确认表结构已创建
4. 查看详细错误信息：`./vendor/bin/phpunit --verbose`

### 数据库连接错误

确保测试环境变量已设置：

```bash
export APP_ENV=testing
```

### 依赖缺失

重新安装依赖：

```bash
composer install
```

## 最佳实践

1. **测试独立性** - 每个测试应该独立运行，不依赖其他测试
2. **数据清理** - 使用事务自动回滚，保持测试环境干净
3. **描述性命名** - 测试方法名清晰描述测试内容
4. **注释文档** - 标注测试覆盖的需求编号
5. **边界测试** - 测试正常情况和异常情况
6. **性能考虑** - 避免创建过多测试数据

## 扩展测试

如需添加新的集成测试：

1. 在 `tests/integration/` 目录创建新的测试文件
2. 继承 `tests\TestCase` 基类
3. 使用 `@test` 注解标记测试方法
4. 在方法注释中标注覆盖的需求编号
5. 运行测试验证功能

## 联系方式

如有问题或建议，请联系开发团队。
