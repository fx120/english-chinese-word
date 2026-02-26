/// SQLite数据库表结构定义
/// 
/// 本文件定义了前端本地数据库的所有表结构，包括：
/// - vocabulary_list: 词表表
/// - word: 单词表
/// - vocabulary_list_word: 词表单词关联表
/// - user_word_progress: 用户单词学习进度表
/// - user_word_exclusion: 用户单词排除表
/// - user_statistics: 用户学习统计表
/// - daily_learning_record: 每日学习记录表
/// 
/// 所有表都包含sync_status字段以支持离线同步功能
library;

class DatabaseSchema {
  /// 数据库版本号
  static const int DATABASE_VERSION = 1;
  
  /// 数据库名称
  static const String DATABASE_NAME = 'vocabulary_learning.db';
  
  /// 创建词表表
  /// 
  /// 存储用户下载的官方词表和自定义词表
  /// server_id: 服务器端ID，用于同步
  /// sync_status: 同步状态 (synced, pending, conflict)
  static const String CREATE_VOCABULARY_LIST_TABLE = '''
    CREATE TABLE vocabulary_list (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER,
      name TEXT NOT NULL,
      description TEXT,
      category TEXT,
      difficulty_level INTEGER DEFAULT 1,
      word_count INTEGER DEFAULT 0,
      is_official INTEGER DEFAULT 1,
      is_custom INTEGER DEFAULT 0,
      created_at INTEGER,
      updated_at INTEGER,
      sync_status TEXT DEFAULT 'synced'
    )
  ''';
  
  /// 创建单词表
  /// 
  /// 存储全局共享的单词数据
  /// 单词在本地数据库中只存储一份，通过关联表引用
  static const String CREATE_WORD_TABLE = '''
    CREATE TABLE word (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER,
      word TEXT NOT NULL,
      phonetic TEXT,
      part_of_speech TEXT,
      definition TEXT NOT NULL,
      example TEXT,
      created_at INTEGER,
      updated_at INTEGER
    )
  ''';
  
  /// 创建词表单词关联表
  /// 
  /// 建立词表和单词的多对多关系
  /// 一个单词可以属于多个词表
  static const String CREATE_VOCABULARY_LIST_WORD_TABLE = '''
    CREATE TABLE vocabulary_list_word (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      vocabulary_list_id INTEGER NOT NULL,
      word_id INTEGER NOT NULL,
      sort_order INTEGER DEFAULT 0,
      created_at INTEGER,
      UNIQUE(vocabulary_list_id, word_id),
      FOREIGN KEY (vocabulary_list_id) REFERENCES vocabulary_list(id) ON DELETE CASCADE,
      FOREIGN KEY (word_id) REFERENCES word(id) ON DELETE CASCADE
    )
  ''';
  
  /// 创建用户单词学习进度表
  /// 
  /// 记录用户对每个单词的学习状态和复习计划
  /// status: 学习状态 (not_learned, mastered, need_review)
  /// memory_level: 记忆级别 (0-5)，对应记忆曲线节点
  /// sync_status: 同步状态 (pending, synced, conflict)
  static const String CREATE_USER_WORD_PROGRESS_TABLE = '''
    CREATE TABLE user_word_progress (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word_id INTEGER NOT NULL,
      vocabulary_list_id INTEGER NOT NULL,
      status TEXT DEFAULT 'not_learned',
      learned_at INTEGER,
      last_review_at INTEGER,
      next_review_at INTEGER,
      review_count INTEGER DEFAULT 0,
      error_count INTEGER DEFAULT 0,
      memory_level INTEGER DEFAULT 0,
      sync_status TEXT DEFAULT 'pending',
      UNIQUE(word_id, vocabulary_list_id),
      FOREIGN KEY (word_id) REFERENCES word(id) ON DELETE CASCADE,
      FOREIGN KEY (vocabulary_list_id) REFERENCES vocabulary_list(id) ON DELETE CASCADE
    )
  ''';
  
  /// 创建用户单词排除表
  /// 
  /// 记录用户在特定词表中隐藏的单词（软删除）
  /// 实现用户级别的单词删除，不影响全局数据
  static const String CREATE_USER_WORD_EXCLUSION_TABLE = '''
    CREATE TABLE user_word_exclusion (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word_id INTEGER NOT NULL,
      vocabulary_list_id INTEGER NOT NULL,
      excluded_at INTEGER,
      sync_status TEXT DEFAULT 'pending',
      UNIQUE(word_id, vocabulary_list_id),
      FOREIGN KEY (word_id) REFERENCES word(id) ON DELETE CASCADE,
      FOREIGN KEY (vocabulary_list_id) REFERENCES vocabulary_list(id) ON DELETE CASCADE
    )
  ''';
  
  /// 创建用户学习统计表
  /// 
  /// 存储用户的总体学习统计数据
  /// 只有一条记录，记录当前用户的统计信息
  static const String CREATE_USER_STATISTICS_TABLE = '''
    CREATE TABLE user_statistics (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      total_days INTEGER DEFAULT 0,
      continuous_days INTEGER DEFAULT 0,
      total_words_learned INTEGER DEFAULT 0,
      total_words_mastered INTEGER DEFAULT 0,
      last_learn_date TEXT,
      updated_at INTEGER
    )
  ''';
  
  /// 创建每日学习记录表
  /// 
  /// 记录每天的学习情况，用于统计和连续学习天数计算
  /// learn_date: 学习日期 (YYYY-MM-DD格式)
  static const String CREATE_DAILY_LEARNING_RECORD_TABLE = '''
    CREATE TABLE daily_learning_record (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      learn_date TEXT NOT NULL UNIQUE,
      new_words_count INTEGER DEFAULT 0,
      review_words_count INTEGER DEFAULT 0,
      created_at INTEGER
    )
  ''';
  
  /// 创建索引以优化查询性能
  static const List<String> CREATE_INDEXES = [
    // 词表索引
    'CREATE INDEX idx_vocabulary_list_category ON vocabulary_list(category)',
    'CREATE INDEX idx_vocabulary_list_is_official ON vocabulary_list(is_official)',
    'CREATE INDEX idx_vocabulary_list_sync_status ON vocabulary_list(sync_status)',
    
    // 单词索引
    'CREATE INDEX idx_word_word ON word(word)',
    'CREATE INDEX idx_word_server_id ON word(server_id)',
    
    // 词表单词关联索引
    'CREATE INDEX idx_vlw_vocabulary_list_id ON vocabulary_list_word(vocabulary_list_id)',
    'CREATE INDEX idx_vlw_word_id ON vocabulary_list_word(word_id)',
    'CREATE INDEX idx_vlw_sort_order ON vocabulary_list_word(sort_order)',
    
    // 学习进度索引
    'CREATE INDEX idx_uwp_word_id ON user_word_progress(word_id)',
    'CREATE INDEX idx_uwp_vocabulary_list_id ON user_word_progress(vocabulary_list_id)',
    'CREATE INDEX idx_uwp_status ON user_word_progress(status)',
    'CREATE INDEX idx_uwp_next_review_at ON user_word_progress(next_review_at)',
    'CREATE INDEX idx_uwp_sync_status ON user_word_progress(sync_status)',
    
    // 排除单词索引
    'CREATE INDEX idx_uwe_word_id ON user_word_exclusion(word_id)',
    'CREATE INDEX idx_uwe_vocabulary_list_id ON user_word_exclusion(vocabulary_list_id)',
    'CREATE INDEX idx_uwe_sync_status ON user_word_exclusion(sync_status)',
    
    // 每日学习记录索引
    'CREATE INDEX idx_dlr_learn_date ON daily_learning_record(learn_date)',
  ];
  
  /// 获取所有建表语句
  static List<String> getAllCreateTableStatements() {
    return [
      CREATE_VOCABULARY_LIST_TABLE,
      CREATE_WORD_TABLE,
      CREATE_VOCABULARY_LIST_WORD_TABLE,
      CREATE_USER_WORD_PROGRESS_TABLE,
      CREATE_USER_WORD_EXCLUSION_TABLE,
      CREATE_USER_STATISTICS_TABLE,
      CREATE_DAILY_LEARNING_RECORD_TABLE,
    ];
  }
  
  /// 获取所有索引创建语句
  static List<String> getAllCreateIndexStatements() {
    return CREATE_INDEXES;
  }
  
  /// 数据库升级脚本
  /// 
  /// 当数据库版本升级时执行的迁移脚本
  /// [oldVersion] 旧版本号
  /// [newVersion] 新版本号
  static List<String> getMigrationScripts(int oldVersion, int newVersion) {
    List<String> scripts = [];
    
    // 示例：从版本1升级到版本2
    // if (oldVersion < 2 && newVersion >= 2) {
    //   scripts.add('ALTER TABLE vocabulary_list ADD COLUMN new_field TEXT');
    // }
    
    return scripts;
  }
}
