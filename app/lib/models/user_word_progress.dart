enum LearningStatus {
  notLearned,
  mastered,
  needReview,
}

class UserWordProgress {
  final int id;
  final int wordId;
  final int vocabularyListId;
  final LearningStatus status;
  final DateTime? learnedAt;
  final DateTime? lastReviewAt;
  final DateTime? nextReviewAt;
  final int reviewCount;
  final int errorCount;
  final int memoryLevel;
  final String syncStatus;
  
  UserWordProgress({
    required this.id,
    required this.wordId,
    required this.vocabularyListId,
    this.status = LearningStatus.notLearned,
    this.learnedAt,
    this.lastReviewAt,
    this.nextReviewAt,
    this.reviewCount = 0,
    this.errorCount = 0,
    this.memoryLevel = 0,
    this.syncStatus = 'pending',
  });
  
  factory UserWordProgress.fromJson(Map<String, dynamic> json) {
    return UserWordProgress(
      id: json['id'] as int,
      wordId: json['word_id'] as int,
      vocabularyListId: json['vocabulary_list_id'] as int,
      status: _statusFromString(json['status'] as String),
      learnedAt: json['learned_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((json['learned_at'] as int) * 1000)
          : null,
      lastReviewAt: json['last_review_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((json['last_review_at'] as int) * 1000)
          : null,
      nextReviewAt: json['next_review_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((json['next_review_at'] as int) * 1000)
          : null,
      reviewCount: json['review_count'] as int? ?? 0,
      errorCount: json['error_count'] as int? ?? 0,
      memoryLevel: json['memory_level'] as int? ?? 0,
      syncStatus: json['sync_status'] as String? ?? 'pending',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word_id': wordId,
      'vocabulary_list_id': vocabularyListId,
      'status': _statusToString(status),
      'learned_at': learnedAt != null ? learnedAt!.millisecondsSinceEpoch ~/ 1000 : null,
      'last_review_at': lastReviewAt != null ? lastReviewAt!.millisecondsSinceEpoch ~/ 1000 : null,
      'next_review_at': nextReviewAt != null ? nextReviewAt!.millisecondsSinceEpoch ~/ 1000 : null,
      'review_count': reviewCount,
      'error_count': errorCount,
      'memory_level': memoryLevel,
      'sync_status': syncStatus,
    };
  }
  
  static LearningStatus _statusFromString(String status) {
    switch (status) {
      case 'mastered':
        return LearningStatus.mastered;
      case 'need_review':
        return LearningStatus.needReview;
      default:
        return LearningStatus.notLearned;
    }
  }
  
  static String _statusToString(LearningStatus status) {
    switch (status) {
      case LearningStatus.mastered:
        return 'mastered';
      case LearningStatus.needReview:
        return 'need_review';
      case LearningStatus.notLearned:
        return 'not_learned';
    }
  }
}
