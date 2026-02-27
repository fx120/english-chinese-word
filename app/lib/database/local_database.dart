import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/vocabulary_list.dart';
import '../models/word.dart';
import '../models/user_word_progress.dart';
import '../models/user_statistics.dart';
import '../models/daily_record.dart';
import '../models/user_word_exclusion.dart';

class LocalDatabase {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'vocabulary_app.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS learning_plan (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          vocabulary_list_id INTEGER NOT NULL UNIQUE,
          daily_new_words INTEGER DEFAULT 20,
          daily_review_words INTEGER DEFAULT 50,
          created_at INTEGER,
          updated_at INTEGER,
          FOREIGN KEY (vocabulary_list_id) REFERENCES vocabulary_list(id) ON DELETE CASCADE
        )
      ''');
    }
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // 创建所有表结构
    await db.execute('''
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
    ''');
    
    await db.execute('''
      CREATE TABLE word (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        word TEXT NOT NULL UNIQUE,
        phonetic TEXT,
        part_of_speech TEXT,
        definition TEXT NOT NULL,
        example TEXT,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');
    
    await db.execute('''
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
    ''');
    
    await db.execute('''
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
    ''');
    
    await db.execute('''
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
    ''');
    
    await db.execute('''
      CREATE TABLE user_statistics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_days INTEGER DEFAULT 0,
        continuous_days INTEGER DEFAULT 0,
        total_words_learned INTEGER DEFAULT 0,
        total_words_mastered INTEGER DEFAULT 0,
        last_learn_date TEXT,
        updated_at INTEGER
      )
    ''');
    
    await db.execute('''
      CREATE TABLE daily_learning_record (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        new_words_count INTEGER DEFAULT 0,
        review_words_count INTEGER DEFAULT 0,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE learning_plan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vocabulary_list_id INTEGER NOT NULL UNIQUE,
        daily_new_words INTEGER DEFAULT 20,
        daily_review_words INTEGER DEFAULT 50,
        created_at INTEGER,
        updated_at INTEGER,
        FOREIGN KEY (vocabulary_list_id) REFERENCES vocabulary_list(id) ON DELETE CASCADE
      )
    ''');
  }
  
  Future<void> initialize() async {
    await database;
  }

  /// 重置数据库引用，下次访问时会重新创建
  void resetDatabase() {
    _database = null;
  }
  
  // ==================== 词表CRUD操作 ====================
  
  /// 插入词表
  Future<int> insertVocabularyList(VocabularyList list) async {
    final db = await database;
    final data = list.toJson();
    if (data['id'] == 0) {
      data.remove('id');
    }
    return await db.insert('vocabulary_list', data);
  }
  
  /// 根据ID获取词表
  Future<VocabularyList?> getVocabularyList(int id) async {
    final db = await database;
    final maps = await db.query('vocabulary_list', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return VocabularyList.fromJson(maps.first);
  }
  
  /// 获取所有词表
  Future<List<VocabularyList>> getAllVocabularyLists() async {
    final db = await database;
    final maps = await db.query('vocabulary_list', orderBy: 'created_at DESC');
    return maps.map((map) => VocabularyList.fromJson(map)).toList();
  }
  
  /// 根据分类获取词表
  Future<List<VocabularyList>> getVocabularyListsByCategory(String category) async {
    final db = await database;
    final maps = await db.query('vocabulary_list', 
        where: 'category = ?', 
        whereArgs: [category],
        orderBy: 'created_at DESC');
    return maps.map((map) => VocabularyList.fromJson(map)).toList();
  }
  
  /// 更新词表
  Future<int> updateVocabularyList(VocabularyList list) async {
    final db = await database;
    return await db.update('vocabulary_list', list.toJson(), 
        where: 'id = ?', whereArgs: [list.id]);
  }
  
  /// 删除词表
  Future<int> deleteVocabularyList(int id) async {
    final db = await database;
    return await db.delete('vocabulary_list', where: 'id = ?', whereArgs: [id]);
  }
  
  /// 更新词表单词数量
  Future<void> updateVocabularyListWordCount(int listId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM vocabulary_list_word WHERE vocabulary_list_id = ?', [listId]));
    await db.update('vocabulary_list', {'word_count': count ?? 0}, 
        where: 'id = ?', whereArgs: [listId]);
  }
  
  // ==================== 单词CRUD操作 ====================
  
  /// 插入单词（如果已存在则忽略）
  Future<int> insertWord(Word word) async {
    final db = await database;
    return await db.insert('word', word.toJson(), 
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  
  /// 插入或更新单词
  Future<int> insertOrUpdateWord(Word word) async {
    final db = await database;
    return await db.insert('word', word.toJson(), 
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  /// 根据ID获取单词
  Future<Word?> getWord(int id) async {
    final db = await database;
    final maps = await db.query('word', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Word.fromJson(maps.first);
  }
  
  /// 根据单词文本获取单词
  Future<Word?> getWordByText(String wordText) async {
    final db = await database;
    final maps = await db.query('word', where: 'word = ?', whereArgs: [wordText]);
    if (maps.isEmpty) return null;
    return Word.fromJson(maps.first);
  }
  
  /// 获取词表的所有单词（排除已标记排除的单词）
  Future<List<Word>> getWordsByListId(int listId, {bool includeExcluded = false}) async {
    final db = await database;
    
    if (includeExcluded) {
      final maps = await db.rawQuery('''
        SELECT w.* FROM word w
        INNER JOIN vocabulary_list_word vlw ON w.id = vlw.word_id
        WHERE vlw.vocabulary_list_id = ?
        ORDER BY vlw.sort_order
      ''', [listId]);
      return maps.map((map) => Word.fromJson(map)).toList();
    } else {
      final maps = await db.rawQuery('''
        SELECT w.* FROM word w
        INNER JOIN vocabulary_list_word vlw ON w.id = vlw.word_id
        LEFT JOIN user_word_exclusion uwe ON w.id = uwe.word_id 
            AND uwe.vocabulary_list_id = vlw.vocabulary_list_id
        WHERE vlw.vocabulary_list_id = ? AND uwe.id IS NULL
        ORDER BY vlw.sort_order
      ''', [listId]);
      return maps.map((map) => Word.fromJson(map)).toList();
    }
  }
  
  /// 更新单词
  Future<int> updateWord(Word word) async {
    final db = await database;
    return await db.update('word', word.toJson(), 
        where: 'id = ?', whereArgs: [word.id]);
  }
  
  /// 删除单词（物理删除，谨慎使用）
  Future<int> deleteWord(int id) async {
    final db = await database;
    return await db.delete('word', where: 'id = ?', whereArgs: [id]);
  }
  
  /// 添加单词到词表
  Future<int> addWordToList(int wordId, int listId, {int sortOrder = 0}) async {
    final db = await database;
    final result = await db.insert('vocabulary_list_word', {
      'vocabulary_list_id': listId,
      'word_id': wordId,
      'sort_order': sortOrder,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    
    // 更新词表单词数量
    await updateVocabularyListWordCount(listId);
    
    return result;
  }
  
  /// 从词表移除单词关联
  Future<int> removeWordFromList(int wordId, int listId) async {
    final db = await database;
    final result = await db.delete('vocabulary_list_word', 
        where: 'word_id = ? AND vocabulary_list_id = ?', 
        whereArgs: [wordId, listId]);
    
    // 更新词表单词数量
    await updateVocabularyListWordCount(listId);
    
    return result;
  }
  
  /// 批量插入单词到词表
  Future<void> batchInsertWordsToList(List<Word> words, int listId) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < words.length; i++) {
        final word = words[i];
        
        // 插入单词（如果已存在则忽略）
        final wordJson = word.toJson();
        wordJson.remove('id'); // 让SQLite自动分配ID
        await txn.insert('word', wordJson, 
            conflictAlgorithm: ConflictAlgorithm.ignore);
        
        // 获取单词ID
        final wordMaps = await txn.query('word', 
            columns: ['id', 'example'], 
            where: 'word = ?', 
            whereArgs: [word.word]);
        
        if (wordMaps.isNotEmpty) {
          final wordId = wordMaps.first['id'] as int;
          final existingExample = wordMaps.first['example'] as String?;
          
          // 补充或更新字段（线上库的音标更准确，直接覆盖）
          final updates = <String, dynamic>{};
          if (word.phonetic != null && word.phonetic!.isNotEmpty) {
            updates['phonetic'] = word.phonetic;
          }
          if ((existingExample == null || existingExample.isEmpty) && 
              word.example != null && word.example!.isNotEmpty) {
            updates['example'] = word.example;
          }
          if (updates.isNotEmpty) {
            await txn.update('word', updates, where: 'id = ?', whereArgs: [wordId]);
          }
          
          // 添加到词表
          await txn.insert('vocabulary_list_word', {
            'vocabulary_list_id': listId,
            'word_id': wordId,
            'sort_order': i,
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
    
    // 更新词表单词数量
    await updateVocabularyListWordCount(listId);
  }
  
  /// 获取词表中的随机单词（用于生成选择题干扰项）
  /// 
  /// [listId] 词表ID
  /// [excludeWordId] 排除的单词ID（正确答案）
  /// [count] 需要的数量
  Future<List<Word>> getRandomWordsForQuiz(int listId, int excludeWordId, int count) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT w.* FROM word w
      INNER JOIN vocabulary_list_word vlw ON w.id = vlw.word_id
      WHERE vlw.vocabulary_list_id = ? AND w.id != ?
      ORDER BY RANDOM()
      LIMIT ?
    ''', [listId, excludeWordId, count]);
    return maps.map((map) => Word.fromJson(map)).toList();
  }

  /// 获取相似单词作为干扰项（优先选长度相近的词）
  /// 
  /// 策略：先取长度相近的候选词（±2），再从中随机选
  /// 如果候选不够，用完全随机的补足
  Future<List<Word>> getSimilarWordsForQuiz(int listId, int excludeWordId, String targetWord, int count) async {
    final db = await database;
    final len = targetWord.length;
    // 先查长度相近的单词（±2个字母）
    final similarMaps = await db.rawQuery('''
      SELECT w.* FROM word w
      INNER JOIN vocabulary_list_word vlw ON w.id = vlw.word_id
      WHERE vlw.vocabulary_list_id = ? AND w.id != ?
        AND LENGTH(w.word) BETWEEN ? AND ?
      ORDER BY RANDOM()
      LIMIT ?
    ''', [listId, excludeWordId, len - 2, len + 2, count * 3]);
    
    final candidates = similarMaps.map((map) => Word.fromJson(map)).toList();
    
    if (candidates.length >= count) {
      // 按相似度排序：共同字母越多越优先
      candidates.sort((a, b) {
        final simA = _wordSimilarity(targetWord, a.word);
        final simB = _wordSimilarity(targetWord, b.word);
        return simB.compareTo(simA);
      });
      return candidates.take(count).toList();
    }
    
    // 候选不够，用随机的补足
    final existingIds = candidates.map((w) => w.id).toSet();
    final extraMaps = await db.rawQuery('''
      SELECT w.* FROM word w
      INNER JOIN vocabulary_list_word vlw ON w.id = vlw.word_id
      WHERE vlw.vocabulary_list_id = ? AND w.id != ?
      ORDER BY RANDOM()
      LIMIT ?
    ''', [listId, excludeWordId, count * 2]);
    
    for (final map in extraMaps) {
      if (candidates.length >= count) break;
      final word = Word.fromJson(map);
      if (!existingIds.contains(word.id)) {
        candidates.add(word);
        existingIds.add(word.id);
      }
    }
    
    return candidates.take(count).toList();
  }

  /// 计算两个单词的相似度（共同字母比例 + 首字母相同加分）
  double _wordSimilarity(String a, String b) {
    final setA = a.toLowerCase().split('').toSet();
    final setB = b.toLowerCase().split('').toSet();
    final common = setA.intersection(setB).length;
    final total = setA.union(setB).length;
    double score = total > 0 ? common / total : 0;
    // 首字母相同加分（更容易混淆）
    if (a.isNotEmpty && b.isNotEmpty && a[0].toLowerCase() == b[0].toLowerCase()) {
      score += 0.3;
    }
    // 长度差越小越好
    final lenDiff = (a.length - b.length).abs();
    if (lenDiff == 0) score += 0.2;
    else if (lenDiff == 1) score += 0.1;
    return score;
  }

  // ==================== 学习进度CRUD操作 ====================
  
  /// 插入或更新学习进度
  Future<int> insertOrUpdateProgress(UserWordProgress progress) async {
    final db = await database;
    final data = progress.toJson();
    // id 为 0 时是新记录，移除 id 让 SQLite 自增分配
    // 否则 ConflictAlgorithm.replace 会因 PRIMARY KEY 冲突覆盖其他记录
    if (data['id'] == 0) {
      data.remove('id');
    }
    return await db.insert('user_word_progress', data, 
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  /// 获取单词在特定词表的学习进度
  Future<UserWordProgress?> getProgress(int wordId, int listId) async {
    final db = await database;
    final maps = await db.query('user_word_progress', 
        where: 'word_id = ? AND vocabulary_list_id = ?', 
        whereArgs: [wordId, listId]);
    if (maps.isEmpty) return null;
    return UserWordProgress.fromJson(maps.first);
  }
  
  /// 获取词表的所有学习进度
  Future<List<UserWordProgress>> getProgressByListId(int listId) async {
    final db = await database;
    final maps = await db.query('user_word_progress', 
        where: 'vocabulary_list_id = ?', 
        whereArgs: [listId]);
    return maps.map((map) => UserWordProgress.fromJson(map)).toList();
  }
  
  /// 获取待复习的单词进度
  Future<List<UserWordProgress>> getDueReviews(int listId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final maps = await db.query('user_word_progress', 
        where: 'vocabulary_list_id = ? AND status = ? AND next_review_at <= ?', 
        whereArgs: [listId, 'need_review', now],
        orderBy: 'next_review_at ASC');
    return maps.map((map) => UserWordProgress.fromJson(map)).toList();
  }
  
  /// 获取错题（错误次数>0的单词）
  Future<List<UserWordProgress>> getWrongWords(int listId) async {
    final db = await database;
    final maps = await db.query('user_word_progress', 
        where: 'vocabulary_list_id = ? AND error_count > 0', 
        whereArgs: [listId],
        orderBy: 'error_count DESC');
    return maps.map((map) => UserWordProgress.fromJson(map)).toList();
  }
  
  /// 获取未学习的单词ID列表
  Future<List<int>> getUnlearnedWordIds(int listId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT w.id FROM word w
      INNER JOIN vocabulary_list_word vlw ON w.id = vlw.word_id
      LEFT JOIN user_word_progress uwp ON w.id = uwp.word_id 
          AND uwp.vocabulary_list_id = vlw.vocabulary_list_id
      LEFT JOIN user_word_exclusion uwe ON w.id = uwe.word_id 
          AND uwe.vocabulary_list_id = vlw.vocabulary_list_id
      WHERE vlw.vocabulary_list_id = ? 
          AND (uwp.id IS NULL OR uwp.status = 'not_learned')
          AND uwe.id IS NULL
    ''', [listId]);
    return maps.map((map) => map['id'] as int).toList();
  }
  
  /// 删除学习进度
  Future<int> deleteProgress(int wordId, int listId) async {
    final db = await database;
    return await db.delete('user_word_progress', 
        where: 'word_id = ? AND vocabulary_list_id = ?', 
        whereArgs: [wordId, listId]);
  }
  
  // ==================== 排除单词CRUD操作 ====================
  
  /// 添加排除单词
  Future<int> insertExclusion(UserWordExclusion exclusion) async {
    final db = await database;
    return await db.insert('user_word_exclusion', exclusion.toJson(), 
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  /// 移除排除标记（恢复单词）
  Future<int> deleteExclusion(int wordId, int listId) async {
    final db = await database;
    return await db.delete('user_word_exclusion', 
        where: 'word_id = ? AND vocabulary_list_id = ?', 
        whereArgs: [wordId, listId]);
  }
  
  /// 获取词表的所有排除单词ID
  Future<List<int>> getExcludedWordIds(int listId) async {
    final db = await database;
    final maps = await db.query('user_word_exclusion', 
        columns: ['word_id'],
        where: 'vocabulary_list_id = ?', 
        whereArgs: [listId]);
    return maps.map((map) => map['word_id'] as int).toList();
  }
  
  /// 获取词表的所有排除单词
  Future<List<UserWordExclusion>> getExclusionsByListId(int listId) async {
    final db = await database;
    final maps = await db.query('user_word_exclusion', 
        where: 'vocabulary_list_id = ?', 
        whereArgs: [listId]);
    return maps.map((map) => UserWordExclusion.fromJson(map)).toList();
  }
  
  /// 检查单词是否被排除
  Future<bool> isWordExcluded(int wordId, int listId) async {
    final db = await database;
    final maps = await db.query('user_word_exclusion', 
        where: 'word_id = ? AND vocabulary_list_id = ?', 
        whereArgs: [wordId, listId]);
    return maps.isNotEmpty;
  }
  
  // ==================== 统计数据CRUD操作 ====================
  
  /// 更新统计数据
  Future<int> updateStatistics(UserStatistics stats) async {
    final db = await database;
    return await db.insert('user_statistics', stats.toJson(), 
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  /// 获取统计数据
  Future<UserStatistics?> getStatistics() async {
    final db = await database;
    final maps = await db.query('user_statistics', limit: 1);
    if (maps.isEmpty) return null;
    return UserStatistics.fromJson(maps.first);
  }
  
  /// 删除统计数据
  Future<int> deleteStatistics() async {
    final db = await database;
    return await db.delete('user_statistics');
  }
  
  // ==================== 每日学习记录CRUD操作 ====================
  
  /// 插入每日学习记录
  Future<int> insertDailyRecord(DailyRecord record) async {
    final db = await database;
    return await db.insert('daily_learning_record', record.toJson(), 
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  /// 获取指定日期的学习记录
  Future<DailyRecord?> getDailyRecord(String date) async {
    final db = await database;
    final maps = await db.query('daily_learning_record', 
        where: 'date = ?', 
        whereArgs: [date]);
    if (maps.isEmpty) return null;
    return DailyRecord.fromJson(maps.first);
  }
  
  /// 获取最近N天的学习记录
  Future<List<DailyRecord>> getDailyRecords(int days) async {
    final db = await database;
    final maps = await db.query('daily_learning_record', 
        orderBy: 'date DESC', 
        limit: days);
    return maps.map((map) => DailyRecord.fromJson(map)).toList();
  }
  
  /// 获取所有学习记录
  Future<List<DailyRecord>> getAllDailyRecords() async {
    final db = await database;
    final maps = await db.query('daily_learning_record', 
        orderBy: 'date DESC');
    return maps.map((map) => DailyRecord.fromJson(map)).toList();
  }
  
  /// 更新每日学习记录
  Future<int> updateDailyRecord(DailyRecord record) async {
    final db = await database;
    return await db.update('daily_learning_record', record.toJson(), 
        where: 'date = ?', 
        whereArgs: [record.date]);
  }
  
  /// 删除每日学习记录
  Future<int> deleteDailyRecord(String date) async {
    final db = await database;
    return await db.delete('daily_learning_record', 
        where: 'date = ?', 
        whereArgs: [date]);
  }

  // ==================== 学习计划CRUD操作 ====================

  /// 获取词表的学习计划
  Future<Map<String, int>?> getLearningPlan(int listId) async {
    final db = await database;
    final maps = await db.query('learning_plan',
        where: 'vocabulary_list_id = ?', whereArgs: [listId]);
    if (maps.isEmpty) return null;
    return {
      'daily_new_words': maps.first['daily_new_words'] as int,
      'daily_review_words': maps.first['daily_review_words'] as int,
    };
  }

  /// 保存学习计划
  Future<void> saveLearningPlan(int listId, int dailyNewWords, int dailyReviewWords) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.insert('learning_plan', {
      'vocabulary_list_id': listId,
      'daily_new_words': dailyNewWords,
      'daily_review_words': dailyReviewWords,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 获取今天已学习的新单词数量（某词表）
  Future<int> getTodayLearnedCount(int listId) async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final startTs = startOfDay.millisecondsSinceEpoch ~/ 1000;
    final endTs = startTs + 86400;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM user_word_progress
      WHERE vocabulary_list_id = ? AND learned_at >= ? AND learned_at < ?
    ''', [listId, startTs, endTs]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取今天已复习的单词数量（某词表）
  Future<int> getTodayReviewedCount(int listId) async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final startTs = startOfDay.millisecondsSinceEpoch ~/ 1000;
    final endTs = startTs + 86400;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM user_word_progress
      WHERE vocabulary_list_id = ? AND last_review_at >= ? AND last_review_at < ?
        AND review_count > 1
    ''', [listId, startTs, endTs]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取词表的学习进度百分比（已学/总数）
  Future<double> getVocabularyListProgress(int listId) async {
    final db = await database;
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM vocabulary_list_word WHERE vocabulary_list_id = ?',
      [listId],
    );
    final total = Sqflite.firstIntValue(totalResult) ?? 0;
    if (total == 0) return 0.0;

    final learnedResult = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM user_word_progress
      WHERE vocabulary_list_id = ? AND status != 'not_learned'
    ''', [listId]);
    final learned = Sqflite.firstIntValue(learnedResult) ?? 0;
    return (learned / total * 100).clamp(0.0, 100.0);
  }
}
