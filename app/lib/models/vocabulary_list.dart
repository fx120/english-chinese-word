class VocabularyList {
  final int id;
  final int? serverId;
  final String name;
  final String? description;
  final String? category;
  final int difficultyLevel;
  final int wordCount;
  final bool isOfficial;
  final bool isCustom;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String syncStatus;
  
  VocabularyList({
    required this.id,
    this.serverId,
    required this.name,
    this.description,
    this.category,
    this.difficultyLevel = 1,
    this.wordCount = 0,
    this.isOfficial = false,
    this.isCustom = false,
    required this.createdAt,
    this.updatedAt,
    this.syncStatus = 'synced',
  });
  
  factory VocabularyList.fromJson(Map<String, dynamic> json) {
    return VocabularyList(
      id: json['id'] as int,
      serverId: json['server_id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      difficultyLevel: json['difficulty_level'] as int? ?? 1,
      wordCount: json['word_count'] as int? ?? 0,
      isOfficial: (json['is_official'] as int?) == 1,
      isCustom: (json['is_custom'] as int?) == 1,
      createdAt: json['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['created_at'] as int) * 1000)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((json['updated_at'] as int) * 1000)
          : null,
      syncStatus: json['sync_status'] as String? ?? 'synced',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'name': name,
      'description': description,
      'category': category,
      'difficulty_level': difficultyLevel,
      'word_count': wordCount,
      'is_official': isOfficial ? 1 : 0,
      'is_custom': isCustom ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'updated_at': updatedAt != null ? updatedAt!.millisecondsSinceEpoch ~/ 1000 : null,
      'sync_status': syncStatus,
    };
  }
}
