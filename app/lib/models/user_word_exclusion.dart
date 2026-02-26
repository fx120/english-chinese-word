class UserWordExclusion {
  final int id;
  final int wordId;
  final int vocabularyListId;
  final DateTime excludedAt;
  final String syncStatus;
  
  UserWordExclusion({
    required this.id,
    required this.wordId,
    required this.vocabularyListId,
    required this.excludedAt,
    this.syncStatus = 'pending',
  });
  
  factory UserWordExclusion.fromJson(Map<String, dynamic> json) {
    return UserWordExclusion(
      id: json['id'] as int,
      wordId: json['word_id'] as int,
      vocabularyListId: json['vocabulary_list_id'] as int,
      excludedAt: DateTime.fromMillisecondsSinceEpoch((json['excluded_at'] as int) * 1000),
      syncStatus: json['sync_status'] as String? ?? 'pending',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word_id': wordId,
      'vocabulary_list_id': vocabularyListId,
      'excluded_at': excludedAt.millisecondsSinceEpoch ~/ 1000,
      'sync_status': syncStatus,
    };
  }
}
