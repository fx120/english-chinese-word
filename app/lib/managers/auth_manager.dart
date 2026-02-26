import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../models/user.dart';

/// 认证管理器
/// 
/// 负责用户认证相关功能：
/// - 发送验证码
/// - 验证码登录
/// - 令牌管理（存储、刷新、清除）
/// - 用户状态管理
/// 
/// 使用SharedPreferences存储JWT令牌和用户信息
class AuthManager {
  // SharedPreferences键名
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user';
  
  final ApiClient _apiClient;
  late SharedPreferences _prefs;
  User? _currentUser;
  bool _initialized = false;
  
  AuthManager(this._apiClient);
  
  /// 初始化AuthManager
  /// 从本地存储加载令牌和用户信息
  Future<void> initialize() async {
    if (_initialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    
    // 加载保存的令牌
    final token = _prefs.getString(_keyToken);
    if (token != null) {
      // FastAdmin token是UUID格式，如果是旧的JWT格式（含.号）则清除
      if (token.contains('.')) {
        await _clearLocalData();
      } else {
        _apiClient.setToken(token);
      }
    }
    
    // 加载保存的用户信息
    final userJson = _prefs.getString(_keyUser);
    if (userJson != null) {
      try {
        final userMap = json.decode(userJson) as Map<String, dynamic>;
        _currentUser = User.fromJson(userMap);
      } catch (e) {
        // 解析失败，清除无效数据
        await _clearLocalData();
      }
    }
    
    _initialized = true;
  }
  
  /// 发送验证码到手机号
  /// 
  /// [mobile] 手机号（11位数字）
  /// 
  /// 返回验证码过期时间戳
  /// 
  /// 抛出异常：
  /// - 手机号格式错误
  /// - 网络错误
  /// - 服务器错误
  Future<int> sendVerificationCode(String mobile) async {
    await _ensureInitialized();
    
    // 验证手机号格式
    if (!_isValidMobile(mobile)) {
      throw Exception('手机号格式错误，请输入11位数字');
    }
    
    try {
      final response = await _apiClient.sendCode(mobile);
      
      // sendCode成功即可，返回预估过期时间（5分钟后）
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300;
    } catch (e) {
      throw Exception('发送验证码失败: ${e.toString()}');
    }
  }
  
  /// 使用验证码登录
  /// 
  /// [mobile] 手机号
  /// [code] 6位数字验证码
  /// 
  /// 返回登录的用户对象
  /// 
  /// 抛出异常：
  /// - 手机号或验证码格式错误
  /// - 验证码错误或过期
  /// - 网络错误
  /// - 服务器错误
  Future<User> loginWithCode(String mobile, String code) async {
    await _ensureInitialized();
    
    // 验证手机号格式
    if (!_isValidMobile(mobile)) {
      throw Exception('手机号格式错误，请输入11位数字');
    }
    
    // 验证验证码格式
    if (!_isValidCode(code)) {
      throw Exception('验证码格式错误，请输入6位数字');
    }
    
    try {
      final response = await _apiClient.login(mobile, code);
      
      // FastAdmin响应格式: {code: 1, msg: "登录成功", data: {token: "...", user: {...}}}
      final data = response.data['data'] as Map<String, dynamic>;
      final token = data['token'] as String;
      
      // 先设置令牌，确保后续请求能携带token
      _apiClient.setToken(token);
      await _saveToken(token);
      
      final userMap = data['user'] as Map<String, dynamic>;
      
      // 解析用户信息
      final user = User.fromJson(userMap);
      
      // 保存用户信息
      await _saveUser(user);
      _currentUser = user;
      
      return user;
    } catch (e) {
      throw Exception('登录失败: ${e.toString()}');
    }
  }
  
  /// 使用用户名密码登录
  /// 
  /// [account] 用户名或手机号
  /// [password] 密码
  /// 
  /// 返回登录的用户对象
  Future<User> loginWithPassword(String account, String password) async {
    await _ensureInitialized();
    
    if (account.isEmpty) {
      throw Exception('请输入用户名或手机号');
    }
    
    if (password.isEmpty) {
      throw Exception('请输入密码');
    }
    
    try {
      final response = await _apiClient.loginByPassword(account, password);
      
      final data = response.data['data'] as Map<String, dynamic>;
      final token = data['token'] as String;
      
      _apiClient.setToken(token);
      await _saveToken(token);
      
      final userMap = data['user'] as Map<String, dynamic>;
      final user = User.fromJson(userMap);
      
      await _saveUser(user);
      _currentUser = user;
      
      return user;
    } catch (e) {
      throw Exception('登录失败: ${e.toString()}');
    }
  }
  
  /// 刷新JWT令牌
  /// 
  /// 返回新的令牌字符串
  /// 
  /// 抛出异常：
  /// - 未登录
  /// - 令牌刷新失败
  /// - 网络错误
  Future<String> refreshToken() async {
    await _ensureInitialized();
    
    if (!isLoggedIn()) {
      throw Exception('未登录，无法刷新令牌');
    }
    
    try {
      final response = await _apiClient.refreshToken();
      
      // FastAdmin响应格式: {code: 1, msg: "刷新成功", data: {token: "..."}}
      final data = response.data['data'] as Map<String, dynamic>;
      final newToken = data['token'] as String;
      
      // 保存新令牌
      await _saveToken(newToken);
      _apiClient.setToken(newToken);
      
      return newToken;
    } catch (e) {
      // 刷新失败，清除本地数据
      await logout();
      throw Exception('令牌刷新失败，请重新登录: ${e.toString()}');
    }
  }
  
  /// 获取当前登录用户
  /// 
  /// 返回用户对象，如果未登录则返回null
  User? getCurrentUser() {
    return _currentUser;
  }
  
  /// 更新用户资料
  Future<User> updateProfile(Map<String, dynamic> data) async {
    await _ensureInitialized();
    
    if (!isLoggedIn()) {
      throw Exception('未登录');
    }
    
    try {
      final response = await _apiClient.updateProfile(data);
      final responseData = response.data['data'] as Map<String, dynamic>;
      final userMap = responseData['user'] as Map<String, dynamic>;
      final user = User.fromJson(userMap);
      
      await _saveUser(user);
      _currentUser = user;
      
      return user;
    } catch (e) {
      throw Exception('更新资料失败: ${e.toString()}');
    }
  }
  
  /// 从服务器刷新用户信息
  Future<User> refreshUserInfo() async {
    await _ensureInitialized();
    
    if (!isLoggedIn()) {
      throw Exception('未登录');
    }
    
    try {
      final response = await _apiClient.getUserInfo();
      final responseData = response.data['data'] as Map<String, dynamic>;
      final userMap = responseData['user'] as Map<String, dynamic>;
      final user = User.fromJson(userMap);
      
      await _saveUser(user);
      _currentUser = user;
      
      return user;
    } catch (e) {
      throw Exception('获取用户信息失败: ${e.toString()}');
    }
  }
  
  /// 登出
  /// 
  /// 调用后端登出接口使token失效，并清除本地数据
  Future<void> logout() async {
    await _ensureInitialized();
    
    // 先调后端登出接口使token失效
    try {
      if (_apiClient.getToken() != null) {
        await _apiClient.logout();
      }
    } catch (e) {
      // 后端登出失败不影响本地清除
    }
    
    // 清除API客户端令牌
    _apiClient.clearToken();
    
    // 清除本地数据
    await _clearLocalData();
    
    _currentUser = null;
  }
  
  /// 检查是否已登录
  /// 
  /// 返回true表示已登录，false表示未登录
  bool isLoggedIn() {
    return _currentUser != null && _apiClient.getToken() != null;
  }
  
  // ==================== 私有方法 ====================
  
  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
  
  /// 保存令牌到本地存储
  Future<void> _saveToken(String token) async {
    await _prefs.setString(_keyToken, token);
  }
  
  /// 保存用户信息到本地存储
  Future<void> _saveUser(User user) async {
    final userJson = json.encode(user.toJson());
    await _prefs.setString(_keyUser, userJson);
  }
  
  /// 清除本地存储的数据
  Future<void> _clearLocalData() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyUser);
  }
  
  /// 验证手机号格式
  /// 
  /// 手机号必须是11位数字
  bool _isValidMobile(String mobile) {
    if (mobile.length != 11) return false;
    return RegExp(r'^\d{11}$').hasMatch(mobile);
  }
  
  /// 验证验证码格式
  /// 
  /// 验证码必须是6位数字
  bool _isValidCode(String code) {
    if (code.length != 6) return false;
    return RegExp(r'^\d{6}$').hasMatch(code);
  }
}
