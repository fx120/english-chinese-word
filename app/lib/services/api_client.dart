import 'package:dio/dio.dart';

/// API客户端类，用于与FastAdmin后端通信
/// 
/// FastAdmin API格式: /api/{controller}/{method}
/// 例如: /api/auth/login
class ApiClient {
  // FastAdmin API 基础配置
  static const String BASE_URL = 'https://www.jpwenku.com';
  
  late Dio _dio;
  String? _token;
  
  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: BASE_URL,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // 请求拦截器 - 添加token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // FastAdmin使用 token header（不是 Authorization: Bearer）
        if (_token != null) {
          options.headers['token'] = _token;
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // 响应拦截器 - 处理FastAdmin响应格式
        // FastAdmin响应格式: {code: 1, msg: "success", data: {...}}
        // code=1表示成功，code=0表示失败
        if (response.data is Map) {
          final code = response.data['code'];
          final msg = response.data['msg'];
          
          if (code != null && code == 0) {
            // code=0 表示业务失败
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
                error: msg ?? '请求失败',
              ),
            );
          }
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        // 错误处理拦截器
        if (error.response != null) {
          final statusCode = error.response!.statusCode;
          
          // 401未授权 - 尝试刷新令牌
          if (statusCode == 401 && _token != null) {
            try {
              // 尝试刷新令牌
              final response = await _refreshTokenRequest();
              if (response.data['code'] == 1) {
                final newToken = response.data['data']['token'];
                setToken(newToken);
                
                // 重试原始请求
                final options = error.requestOptions;
                options.headers['token'] = newToken;
                final retryResponse = await _dio.fetch(options);
                return handler.resolve(retryResponse);
              }
            } catch (e) {
              // 刷新令牌失败，返回原始错误
              return handler.next(error);
            }
          }
          
          // 其他HTTP错误
          String errorMessage = '请求失败';
          if (statusCode == 400) {
            errorMessage = '请求参数错误';
          } else if (statusCode == 403) {
            errorMessage = '没有访问权限';
          } else if (statusCode == 404) {
            errorMessage = '请求的资源不存在';
          } else if (statusCode == 500) {
            errorMessage = '服务器内部错误';
          } else if (statusCode == 503) {
            errorMessage = '服务器繁忙，请稍后重试';
          }
          
          return handler.next(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: errorMessage,
            ),
          );
        }
        
        // 网络错误
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout) {
          return handler.next(
            DioException(
              requestOptions: error.requestOptions,
              type: error.type,
              error: '网络连接超时，请检查网络设置',
            ),
          );
        }
        
        if (error.type == DioExceptionType.connectionError) {
          return handler.next(
            DioException(
              requestOptions: error.requestOptions,
              type: error.type,
              error: '网络连接失败，请检查网络设置',
            ),
          );
        }
        
        return handler.next(error);
      },
    ));
  }
  
  /// 刷新令牌的内部请求（不触发拦截器递归）
  Future<Response> _refreshTokenRequest() async {
    return await _dio.post('/api/auth/refresh');
  }
  
  /// 设置JWT令牌
  void setToken(String token) {
    _token = token;
  }
  
  /// 清除JWT令牌
  void clearToken() {
    _token = null;
  }
  
  /// 获取当前令牌
  String? getToken() {
    return _token;
  }
  
  // ==================== 通用请求方法 ====================
  
  /// 通用GET请求 (适配FastAdmin路由格式)
  /// FastAdmin路由格式: /api/{controller}/{action}
  /// 
  /// [controller] 控制器名称（如: auth, vocabulary, word, userdata）
  /// [action] 方法名称（如: sendCode, login, getList）
  /// [params] 查询参数
  Future<Response> get(String controller, String action, {Map<String, dynamic>? params}) async {
    return await _dio.get('/api/$controller/$action', queryParameters: params);
  }
  
  /// 通用POST请求 (适配FastAdmin路由格式)
  /// 
  /// [controller] 控制器名称
  /// [action] 方法名称
  /// [data] 请求体数据
  Future<Response> post(String controller, String action, {Map<String, dynamic>? data}) async {
    return await _dio.post('/api/$controller/$action', data: data);
  }
  
  // ==================== 认证接口 ====================
  
  /// 发送验证码
  /// POST /api/auth.php?action=sendCode
  /// 
  /// [mobile] 手机号
  /// 返回: {code: 0, msg: "验证码已发送", data: {expired_at: 1234567890}}
  Future<Response> sendCode(String mobile) async {
    return await post('auth', 'sendCode', data: {'mobile': mobile});
  }
  
  /// 验证码登录
  /// POST /api/auth/login
  Future<Response> login(String mobile, String code) async {
    return await post('auth', 'login', data: {'mobile': mobile, 'code': code});
  }
  
  /// 用户名密码登录
  /// POST /api/auth/loginByPassword
  Future<Response> loginByPassword(String account, String password) async {
    return await post('auth', 'loginByPassword', data: {'account': account, 'password': password});
  }

  /// 登出
  /// POST /api/auth/logout
  Future<Response> logout() async {
    return await post('auth', 'logout');
  }
  
  /// 刷新令牌
  /// POST /api/auth.php?action=refresh
  /// 
  /// 返回: {code: 0, msg: "刷新成功", data: {token: "..."}}
  Future<Response> refreshToken() async {
    return await post('auth', 'refresh');
  }
  
  /// 更新用户资料
  /// POST /api/auth/updateProfile
  Future<Response> updateProfile(Map<String, dynamic> data) async {
    return await post('auth', 'updateProfile', data: data);
  }
  
  /// 获取当前用户信息
  /// GET /api/auth/getUserInfo
  Future<Response> getUserInfo() async {
    return await get('auth', 'getUserInfo');
  }
  
  // ==================== 词表接口 ====================
  
  /// 获取词表列表
  /// GET /api/vocabulary.php?action=getList
  /// 
  /// [category] 分类筛选（可选）
  /// [page] 页码（可选）
  /// [limit] 每页数量（可选）
  /// 返回: {code: 0, msg: "success", data: {total: 100, page: 1, limit: 20, items: [...]}}
  Future<Response> getVocabularyLists({String? category, int? page, int? limit}) async {
    return await get('vocabulary', 'getList', params: {
      if (category != null) 'category': category,
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    });
  }
  
  /// 获取词表详情
  /// GET /api/vocabulary.php?action=getDetail&id={id}
  /// 
  /// [id] 词表ID
  /// 返回: {code: 0, msg: "success", data: {id: 1, name: "...", words: [...]}}
  Future<Response> getVocabularyListDetail(int id) async {
    return await get('vocabulary', 'getDetail', params: {'id': id});
  }
  
  /// 下载词表
  /// POST /api/vocabulary.php?action=download&id={id}
  /// 
  /// [id] 词表ID
  /// 返回: {code: 0, msg: "下载成功", data: {vocabulary_list: {...}, words: [...]}}
  Future<Response> downloadVocabularyList(int id) async {
    return await post('vocabulary', 'download', data: {'id': id});
  }
  
  /// 创建自定义词表
  /// POST /api/vocabulary.php?action=create
  /// 
  /// [data] 词表数据，包含name, description, category, words等字段
  /// 返回: {code: 0, msg: "创建成功", data: {id: 100, name: "...", word_count: 1}}
  Future<Response> createVocabularyList(Map<String, dynamic> data) async {
    return await post('vocabulary', 'create', data: data);
  }
  
  // ==================== 单词接口 ====================
  
  /// 批量添加单词到词表
  /// POST /api/word.php?action=addToList&list_id={id}
  /// 
  /// [listId] 词表ID
  /// [words] 单词列表
  /// 返回: {code: 0, msg: "添加成功", data: {added_count: 1, word_ids: [...]}}
  Future<Response> addWordsToList(int listId, List<Map<String, dynamic>> words) async {
    return await post('word', 'addToList', data: {
      'list_id': listId,
      'words': words,
    });
  }
  
  /// 更新单词信息
  /// POST /api/word.php?action=update&id={id}
  /// 
  /// [id] 单词ID
  /// [data] 更新的字段（phonetic, definition, example等）
  /// 返回: {code: 0, msg: "更新成功", data: {...}}
  Future<Response> updateWord(int id, Map<String, dynamic> data) async {
    return await post('word', 'update', data: {'id': id, ...data});
  }
  
  // ==================== 同步接口 ====================
  
  /// 同步学习进度
  /// POST /api/userdata.php?action=syncProgress
  /// 
  /// [data] 学习进度数据列表
  /// 返回: {code: 0, msg: "同步成功", data: {synced_count: 1, conflicts: []}}
  Future<Response> syncProgress(List<Map<String, dynamic>> data) async {
    return await post('userdata', 'syncProgress', data: {'progress_data': data});
  }
  
  /// 同步排除单词
  /// POST /api/userdata.php?action=syncExclusions
  /// 
  /// [data] 排除单词数据列表
  /// 返回: {code: 0, msg: "同步成功", data: {synced_count: 1}}
  Future<Response> syncExclusions(List<Map<String, dynamic>> data) async {
    return await post('userdata', 'syncExclusions', data: {'exclusions': data});
  }
  
  /// 获取学习统计
  /// GET /api/userdata.php?action=getStatistics
  /// 
  /// 返回: {code: 0, msg: "success", data: {total_days: 30, continuous_days: 7, ...}}
  Future<Response> getStatistics() async {
    return await get('userdata', 'getStatistics');
  }
  
  // ==================== 搜索接口 ====================
  
  /// 搜索单词（云端词典，无需登录）
  /// GET /api/vocabulary/searchWord
  Future<Response> searchWord(String keyword, {int page = 1, int limit = 20}) async {
    return await get('vocabulary', 'searchWord', params: {
      'keyword': keyword,
      'page': page,
      'limit': limit,
    });
  }
}
