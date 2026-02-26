# Task 11.1 登录页面实现文档

## 任务概述

实现AI背单词应用的登录页面，提供手机号验证码登录功能。

**任务编号**: 11.1  
**实施日期**: 2024年  
**状态**: 已完成

## 需求映射

本任务实现以下需求：
- **需求 1.1**: 用户提交手机号，后端发送6位数字验证码
- **需求 1.2**: 验证码在5分钟内有效
- **需求 1.3**: 用户提交手机号和验证码，后端创建或登录用户账户

## 实现内容

### 1. 登录页面 UI 组件

**文件位置**: `app/lib/ui/pages/login_page.dart`

#### 主要功能

1. **手机号输入框**
   - 限制输入11位数字
   - 实时格式验证（1开头的11位手机号）
   - 显示输入提示和错误信息

2. **验证码输入框**
   - 限制输入6位数字
   - 验证码格式校验
   - 与发送按钮配合使用

3. **发送验证码按钮**
   - 60秒倒计时功能
   - 倒计时期间按钮禁用
   - 显示剩余秒数
   - 倒计时结束后自动恢复

4. **登录按钮**
   - 集成加载状态指示器
   - 防止重复提交
   - 表单验证通过后才能提交

5. **用户体验优化**
   - 自动检查登录状态
   - 已登录用户自动跳转主页
   - 友好的错误提示
   - 加载状态显示
   - 美观的UI设计

### 2. 状态管理

使用 Provider 模式管理认证状态：

- **AuthProvider**: 提供认证相关的状态和方法
  - `isLoading`: 加载状态
  - `isLoggedIn`: 登录状态
  - `sendCode()`: 发送验证码
  - `login()`: 登录
  - `checkLoginStatus()`: 检查登录状态

### 3. 表单验证

实现了完整的表单验证逻辑：

- **手机号验证**:
  - 非空检查
  - 长度检查（11位）
  - 格式检查（1开头的11位数字）

- **验证码验证**:
  - 非空检查
  - 长度检查（6位）
  - 数字格式检查

### 4. 倒计时功能

实现了60秒倒计时机制：

```dart
void _startCountdown() {
  setState(() {
    _codeSent = true;
    _countdown = 60;
  });
  
  _countdownTimer?.cancel();
  _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (_countdown > 0) {
      setState(() {
        _countdown--;
      });
    } else {
      timer.cancel();
      setState(() {
        _codeSent = false;
      });
    }
  });
}
```

### 5. 错误处理

实现了友好的错误提示：

- 网络错误提示
- 验证码发送失败提示
- 登录失败提示
- 表单验证错误提示
- 使用不同颜色区分错误类型（红色、橙色、绿色）

### 6. 导航流程

- 登录成功后跳转到主页 (`/main`)
- 已登录用户打开登录页自动跳转主页
- 使用 `pushReplacementNamed` 防止返回登录页

## 技术实现细节

### 依赖项

```dart
import 'dart:async';  // Timer 倒计时
import 'package:flutter/material.dart';  // Flutter UI
import 'package:flutter/services.dart';  // 输入格式化
import 'package:provider/provider.dart';  // 状态管理
```

### 关键代码片段

#### 1. 手机号输入框配置

```dart
TextFormField(
  controller: _mobileController,
  keyboardType: TextInputType.phone,
  maxLength: 11,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
  ],
  validator: (value) {
    if (value == null || value.isEmpty) {
      return '请输入手机号';
    }
    if (value.length != 11) {
      return '请输入11位手机号';
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) {
      return '请输入正确的手机号';
    }
    return null;
  },
)
```

#### 2. 发送验证码逻辑

```dart
Future<void> _sendCode() async {
  if (!_validateMobile()) {
    return;
  }
  
  final mobile = _mobileController.text.trim();
  final authProvider = context.read<AuthProvider>();
  
  try {
    await authProvider.sendCode(mobile);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('验证码已发送，请注意查收'),
        backgroundColor: Colors.green,
      ),
    );
    
    _startCountdown();
  } catch (e) {
    // 错误处理
  }
}
```

#### 3. 登录逻辑

```dart
Future<void> _login() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }
  
  final mobile = _mobileController.text.trim();
  final code = _codeController.text.trim();
  final authProvider = context.read<AuthProvider>();
  
  try {
    await authProvider.login(mobile, code);
    
    if (!mounted) return;
    
    Navigator.of(context).pushReplacementNamed('/main');
  } catch (e) {
    // 错误处理
  }
}
```

## 修复的问题

### AuthProvider 修复

修复了 `checkLoginStatus()` 方法中的异步调用问题：

**修复前**:
```dart
Future<void> checkLoginStatus() async {
  final isLoggedIn = await _authManager.isLoggedIn();  // 错误：isLoggedIn() 是同步方法
  if (isLoggedIn) {
    _user = _authManager.getCurrentUser();
    notifyListeners();
  }
}
```

**修复后**:
```dart
Future<void> checkLoginStatus() async {
  await _authManager.initialize();  // 确保初始化
  if (_authManager.isLoggedIn()) {  // 正确：同步调用
    _user = _authManager.getCurrentUser();
    notifyListeners();
  }
}
```

## UI 设计

### 布局结构

```
SafeArea
└── Center
    └── SingleChildScrollView
        └── Form
            ├── Logo (Icon)
            ├── 标题文本
            ├── 副标题文本
            ├── 手机号输入框
            ├── 验证码输入框 + 发送按钮
            ├── 登录按钮
            └── 提示文本
```

### 样式特点

- 圆角边框（12px）
- 蓝色主题色
- 响应式布局
- Material Design 3
- 清晰的视觉层次
- 友好的交互反馈

## 测试建议

### 功能测试

1. **手机号验证测试**
   - 测试空手机号
   - 测试非11位手机号
   - 测试非法格式手机号
   - 测试正确格式手机号

2. **验证码发送测试**
   - 测试发送成功场景
   - 测试网络错误场景
   - 测试倒计时功能
   - 测试重复发送限制

3. **登录测试**
   - 测试正确验证码登录
   - 测试错误验证码
   - 测试过期验证码
   - 测试网络错误

4. **导航测试**
   - 测试登录成功跳转
   - 测试已登录自动跳转
   - 测试返回按钮行为

### UI 测试

1. 测试不同屏幕尺寸的适配
2. 测试键盘弹出时的布局
3. 测试加载状态显示
4. 测试错误提示显示

## 集成说明

### 依赖组件

- `AuthManager`: 认证管理器（已实现）
- `AuthProvider`: 认证状态提供者（已实现并修复）
- `ApiClient`: API客户端（已实现）
- `MainPage`: 主页面（已实现）

### 路由配置

在 `main.dart` 中已配置路由：

```dart
routes: {
  '/login': (context) => const LoginPage(),
  '/main': (context) => const MainPage(),
}
```

## 后续任务

本任务完成后，可以继续实现：

- Task 11.2: 词表列表页面
- Task 11.3: 词表详情页面
- Task 11.4: 文件导入对话框

## 验证结果

- ✅ 代码编译通过，无语法错误
- ✅ 代码诊断通过，无警告
- ✅ 符合 Flutter 代码规范
- ✅ 符合项目目录结构规范
- ✅ 集成 AuthManager 和 AuthProvider
- ✅ 实现所有需求功能
- ✅ 提供友好的用户体验

## 总结

Task 11.1 登录页面已成功实现，包含：

1. ✅ 手机号输入界面（带验证）
2. ✅ 验证码输入界面（带验证）
3. ✅ 发送验证码按钮（60秒倒计时）
4. ✅ 登录按钮（带加载状态）
5. ✅ 集成 AuthManager
6. ✅ 自动登录状态检查
7. ✅ 友好的错误提示
8. ✅ 美观的UI设计

所有功能均已实现并通过验证，可以进入下一个任务。
