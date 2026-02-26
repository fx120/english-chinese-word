import '../services/api_client.dart';
import '../database/local_database.dart';
import '../models/user_word_progress.dart';
import '../models/user_word_exclusion.dart';
import '../models/user_statistics.dart';
import '../algorithms/sync_conflict_resolver.dart';

/// 同步状态枚举
enum SyncStatusType {
  idle,        // 空闲
  syncing,     // 同步中
  success,     // 同步成功
  failed,      // 同步失败
}

/// 同步状态类
class SyncStatus {
  final SyncStatusType type;
  final DateTime? lastSyncTime;
  final int pendingChanges;
  final String? errorMessage;
  
  SyncStatus({
    required this.type,
    this.lastSyncTime,
    this.pendingChanges = 0,
    this.errorMessage,
  });
}

/// 同步冲突类
class SyncConflict {
  final String type;  // 'progress' or 'statistics'
  final dynamic localData;
  final dynamic remoteData;
  final dynamic resolvedData;
  
  SyncConflict({
    required this.type,
    required this.localData,
    required this.remoteData,
    required this.resolvedData,
  });
}

/// 同步管理器
/// 
/// 实现需求14: 数据同步（预留）
/// - 提供手动同步功能
/// - 将本地学习数据上传到Backend
/// - 从Backend下载云端数据
/// - 合并本地和云端数据
/// - 冲突时优先保留学习进度更高的数据
class SyncManager {
  final ApiClient _apiClient;
  final LocalDatabase _localDatabase;
  
  SyncStatus _syncStatus = SyncStatus(type: SyncStatusType.idle);
  DateTime? _lastSyncTime;
  
  SyncManager({
    required ApiClient apiClient,
    required LocalDatabase localDatabase,
  })  : _apiClient = apiClient,
        _localDatabase = localDatabase;
  
  /// 同步所有数据
  /// 
  /// 按顺序同步：
  /// 1. 学习进度
  /// 2. 排除单词
  /// 3. 统计数据
  /// 
  /// 返回是否同步成功
  Future<bool> syncAll() async {
    try {
      // 更新同步状态为同步中
      _syncStatus = SyncStatus(
        type: SyncStatusType.syncing,
        lastSyncTime: _lastSyncTime,
      );
      
      // 同步学习进度
      await syncProgress();
      
      // 同步排除单词
      await syncExclusions();
      
      // 同步统计数据
      await syncStatistics();
      
      // 更新最后同步时间
      _lastSyncTime = DateTime.now();
      
      // 更新同步状态为成功
      _syncStatus = SyncStatus(
        type: SyncStatusType.success,
        lastSyncTime: _lastSyncTime,
        pendingChanges: 0,
      );
      
      return true;
    } catch (e) {
      // 更新同步状态为失败
      _syncStatus = SyncStatus(
        type: SyncStatusType.failed,
        lastSyncTime: _lastSyncTime,
        errorMessage: e.toString(),
      );
      
      return false;
    }
  }
  
  /// 同步学习进度
  /// 
  /// 实现需求14.2: 将本地学习数据上传到Backend
  /// 实现需求14.3: 从Backend下载云端学习数据
  /// 实现需求14.4: 合并本地和云端数据
  /// 实现需求14.5: 冲突时优先保留学习进度更高的数据
  Future<void> syncProgress() async {
    try {
      // 1. 获取所有待同步的本地学习进度（sync_status = 'pending'）
      final db = await _localDatabase.database;
      final localProgressMaps = await db.query(
        'user_word_progress',
        where: 'sync_status = ?',
        whereArgs: ['pending'],
      );
      
      if (localProgressMaps.isEmpty) {
        return; // 没有待同步的数据
      }
      
      // 转换为UserWordProgress对象
      final localProgressList = localProgressMaps
          .map((map) => UserWordProgress.fromJson(map))
          .toList();
      
      // 2. 准备上传数据
      final uploadData = localProgressList.map((progress) {
        return {
          'word_id': progress.wordId,
          'vocabulary_list_id': progress.vocabularyListId,
          'status': _statusToString(progress.status),
          'learned_at': progress.learnedAt != null ? (progress.learnedAt!.millisecondsSinceEpoch ~/ 1000) : null,
          'last_review_at': progress.lastReviewAt != null ? (progress.lastReviewAt!.millisecondsSinceEpoch ~/ 1000) : null,
          'next_review_at': progress.nextReviewAt != null ? (progress.nextReviewAt!.millisecondsSinceEpoch ~/ 1000) : null,
          'review_count': progress.reviewCount,
          'error_count': progress.errorCount,
          'memory_level': progress.memoryLevel,
        };
      }).toList();
      
      // 3. 上传到服务器并获取响应
      final response = await _apiClient.syncProgress(uploadData);
      final responseData = response.data['data'];
      
      // 4. 处理服务器返回的冲突数据
      final conflicts = responseData['conflicts'] as List<dynamic>? ?? [];
      
      for (var conflictData in conflicts) {
        final wordId = conflictData['word_id'] as int;
        final listId = conflictData['vocabulary_list_id'] as int;
        final remoteData = conflictData['remote_data'] as Map<String, dynamic>;
        
        // 获取本地数据
        final localProgress = await _localDatabase.getProgress(wordId, listId);
        if (localProgress == null) continue;
        
        // 解析远程数据
        final remoteProgress = UserWordProgress(
          id: localProgress.id,
          wordId: wordId,
          vocabularyListId: listId,
          status: _statusFromString(remoteData['status'] as String),
          learnedAt: remoteData['learned_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch((remoteData['learned_at'] as int) * 1000)
              : null,
          lastReviewAt: remoteData['last_review_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch((remoteData['last_review_at'] as int) * 1000)
              : null,
          nextReviewAt: remoteData['next_review_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch((remoteData['next_review_at'] as int) * 1000)
              : null,
          reviewCount: remoteData['review_count'] as int? ?? 0,
          errorCount: remoteData['error_count'] as int? ?? 0,
          memoryLevel: remoteData['memory_level'] as int? ?? 0,
          syncStatus: 'synced',
        );
        
        // 使用冲突解决算法
        final resolvedProgress = SyncConflictResolver.resolveProgressConflict(
          localProgress,
          remoteProgress,
        );
        
        // 保存解决后的数据
        await _localDatabase.insertOrUpdateProgress(resolvedProgress);
      }
      
      // 5. 更新所有已同步数据的状态为'synced'
      for (var progress in localProgressList) {
        await db.update(
          'user_word_progress',
          {'sync_status': 'synced'},
          where: 'word_id = ? AND vocabulary_list_id = ?',
          whereArgs: [progress.wordId, progress.vocabularyListId],
        );
      }
    } catch (e) {
      // 同步失败，保持pending状态，下次继续尝试
      rethrow;
    }
  }
  
  /// 同步排除单词
  /// 
  /// 实现需求14.2: 将本地排除数据上传到Backend
  Future<void> syncExclusions() async {
    try {
      // 1. 获取所有待同步的排除单词（sync_status = 'pending'）
      final db = await _localDatabase.database;
      final exclusionMaps = await db.query(
        'user_word_exclusion',
        where: 'sync_status = ?',
        whereArgs: ['pending'],
      );
      
      if (exclusionMaps.isEmpty) {
        return; // 没有待同步的数据
      }
      
      // 转换为UserWordExclusion对象
      final exclusionList = exclusionMaps
          .map((map) => UserWordExclusion.fromJson(map))
          .toList();
      
      // 2. 准备上传数据
      final uploadData = exclusionList.map((exclusion) {
        return {
          'word_id': exclusion.wordId,
          'vocabulary_list_id': exclusion.vocabularyListId,
          'excluded_at': exclusion.excludedAt.millisecondsSinceEpoch ~/ 1000,
        };
      }).toList();
      
      // 3. 上传到服务器
      await _apiClient.syncExclusions(uploadData);
      
      // 4. 更新所有已同步数据的状态为'synced'
      for (var exclusion in exclusionList) {
        await db.update(
          'user_word_exclusion',
          {'sync_status': 'synced'},
          where: 'word_id = ? AND vocabulary_list_id = ?',
          whereArgs: [exclusion.wordId, exclusion.vocabularyListId],
        );
      }
    } catch (e) {
      // 同步失败，保持pending状态，下次继续尝试
      rethrow;
    }
  }
  
  /// 同步统计数据
  /// 
  /// 实现需求14.2: 将本地统计数据上传到Backend
  /// 实现需求14.3: 从Backend下载云端统计数据
  /// 实现需求14.4: 合并本地和云端数据（取最大值）
  Future<void> syncStatistics() async {
    try {
      // 1. 获取本地统计数据
      final localStats = await _localDatabase.getStatistics();
      if (localStats == null) {
        return; // 没有本地统计数据
      }
      
      // 2. 从服务器获取云端统计数据
      final response = await _apiClient.getStatistics();
      final remoteData = response.data['data'] as Map<String, dynamic>;
      
      // 3. 解析远程统计数据
      final remoteStats = UserStatistics(
        totalDays: remoteData['total_days'] as int? ?? 0,
        continuousDays: remoteData['continuous_days'] as int? ?? 0,
        totalWordsLearned: remoteData['total_words_learned'] as int? ?? 0,
        totalWordsMastered: remoteData['total_words_mastered'] as int? ?? 0,
        lastLearnDate: remoteData['last_learn_date'] != null
            ? DateTime.parse(remoteData['last_learn_date'] as String)
            : null,
        updatedAt: DateTime.now(),
      );
      
      // 4. 使用冲突解决算法合并统计数据
      final mergedStats = SyncConflictResolver.mergeStatistics(
        localStats,
        remoteStats,
      );
      
      // 5. 保存合并后的统计数据
      await _localDatabase.updateStatistics(mergedStats);
    } catch (e) {
      // 同步失败
      rethrow;
    }
  }
  
  /// 获取同步状态
  /// 
  /// 实现需求14.6: 显示最后同步时间
  /// 返回当前同步状态
  SyncStatus getSyncStatus() {
    return _syncStatus;
  }
  
  /// 解决同步冲突
  /// 
  /// 此方法用于手动解决冲突（如果需要用户干预）
  /// 目前自动使用SyncConflictResolver解决冲突
  /// 
  /// [conflicts] 冲突列表
  Future<void> resolveConflicts(List<SyncConflict> conflicts) async {
    for (var conflict in conflicts) {
      if (conflict.type == 'progress') {
        // 保存解决后的学习进度
        final progress = conflict.resolvedData as UserWordProgress;
        await _localDatabase.insertOrUpdateProgress(progress);
      } else if (conflict.type == 'statistics') {
        // 保存解决后的统计数据
        final stats = conflict.resolvedData as UserStatistics;
        await _localDatabase.updateStatistics(stats);
      }
    }
  }
  
  // ==================== 辅助方法 ====================
  
  /// 将LearningStatus转换为字符串
  String _statusToString(LearningStatus status) {
    switch (status) {
      case LearningStatus.mastered:
        return 'mastered';
      case LearningStatus.needReview:
        return 'need_review';
      case LearningStatus.notLearned:
        return 'not_learned';
    }
  }
  
  /// 将字符串转换为LearningStatus
  LearningStatus _statusFromString(String status) {
    switch (status) {
      case 'mastered':
        return LearningStatus.mastered;
      case 'need_review':
        return LearningStatus.needReview;
      default:
        return LearningStatus.notLearned;
    }
  }
}
