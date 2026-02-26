import 'package:flutter/foundation.dart';
import '../managers/auth_manager.dart';
import '../models/user.dart';
import '../services/api_client.dart';

/// 认证Provider
/// 
/// 封装AuthManager，提供状态管理和UI通知功能
/// 
/// 功能包括：
/// - 发送验证码
/// - 验证码登录
/// - 登出
/// - 检查登录状态
/// - 刷新令牌
/// - 加载状态管理
/// - 错误处理
class AuthProvider with ChangeNotifier {
  late final AuthManager _authManager;
  User? _user;
  bool _isLoading = false;
  String? _error;
  int? _codeExpiredAt; // 验证码过期时间戳
  
  AuthProvider(ApiClient apiClient) {
    _authManager = AuthManager(apiClient);
    _initialize();
  }
  
  // ==================== Getters ====================
  
  /// 获取当前用户
  User? get user => _user;
  
  /// 获取加载状态
  bool get isLoading => _isLoading;
  
  /// 获取错误信息
  String? get error => _error;
  
  /// 获取验证码过期时间戳
  int? get codeExpiredAt => _codeExpiredAt;
  
  /// 检查是否已登录
  bool get isLoggedIn => _user != null;
  
  /// 获取AuthManager实例（供高级用法使用）
  AuthManager get authManager => _authManager;
  
  // ==================== 初始化 ====================
  
  /// 初始化Provider
  /// 自动检查登录状态
  Future<void> _initialize() async {
    await checkLoginStatus();
  }
  
  // ==================== 发送验证码 ====================
  
  /// 发送验证码
  /// 
  /// [mobile] 手机号
  /// 
  /// 成功时设置验证码过期时间
  /// 失败时设置错误信息
  Future<void> sendCode(String mobile) async {
    _isLoading = true;
    _error = null;
    _codeExpiredAt = null;
    notifyListeners();
    
    try {
      final expiredAt = await _authManager.sendVerificationCode(mobile);
      _codeExpiredAt = expiredAt;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ==================== 登录 ====================
  
  /// 验证码登录
  Future<void> login(String mobile, String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _user = await _authManager.loginWithCode(mobile, code);
      _codeExpiredAt = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 用户名密码登录
  Future<void> loginByPassword(String account, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _user = await _authManager.loginWithPassword(account, password);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ==================== 登出 ====================
  
  /// 登出
  /// 
  /// 清除用户信息和令牌
  Future<void> logout() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _authManager.logout();
      _user = null;
      _codeExpiredAt = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ==================== 检查登录状态 ====================
  
  /// 检查登录状态
  /// 
  /// 从本地存储加载用户信息和令牌
  /// 应用启动时自动调用
  Future<void> checkLoginStatus() async {
    try {
      await _authManager.initialize();
      if (_authManager.isLoggedIn()) {
        _user = _authManager.getCurrentUser();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  // ==================== 刷新令牌 ====================
  
  /// 刷新JWT令牌
  /// 
  /// 当令牌即将过期时调用
  /// 失败时自动登出
  Future<void> refreshToken() async {
    try {
      await _authManager.refreshToken();
    } catch (e) {
      _error = e.toString();
      // 刷新失败，自动登出
      _user = null;
      notifyListeners();
    }
  }
  
  // ==================== 清除错误 ====================
  
  /// 更新用户资料
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _user = await _authManager.updateProfile(data);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 从服务器刷新用户信息
  Future<void> refreshUserInfo() async {
    try {
      _user = await _authManager.refreshUserInfo();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  /// 清除错误信息
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
