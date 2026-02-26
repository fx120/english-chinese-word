class UserStatistics {
  final int totalDays;
  final int continuousDays;
  final int totalWordsLearned;
  final int totalWordsMastered;
  final DateTime? lastLearnDate;
  final DateTime updatedAt;
  
  UserStatistics({
    this.totalDays = 0,
    this.continuousDays = 0,
    this.totalWordsLearned = 0,
    this.totalWordsMastered = 0,
    this.lastLearnDate,
    required this.updatedAt,
  });
  
  factory UserStatistics.fromJson(Map<String, dynamic> json) {
    return UserStatistics(
      totalDays: json['total_days'] as int? ?? 0,
      continuousDays: json['continuous_days'] as int? ?? 0,
      totalWordsLearned: json['total_words_learned'] as int? ?? 0,
      totalWordsMastered: json['total_words_mastered'] as int? ?? 0,
      lastLearnDate: json['last_learn_date'] != null 
          ? DateTime.parse(json['last_learn_date'] as String)
          : null,
      updatedAt: DateTime.fromMillisecondsSinceEpoch((json['updated_at'] as int) * 1000),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'total_days': totalDays,
      'continuous_days': continuousDays,
      'total_words_learned': totalWordsLearned,
      'total_words_mastered': totalWordsMastered,
      'last_learn_date': lastLearnDate?.toIso8601String().split('T')[0],
      'updated_at': updatedAt.millisecondsSinceEpoch ~/ 1000,
    };
  }
}
