class DailyRecord {
  final String date;
  final int newWordsCount;
  final int reviewWordsCount;
  final DateTime createdAt;
  
  DailyRecord({
    required this.date,
    this.newWordsCount = 0,
    this.reviewWordsCount = 0,
    required this.createdAt,
  });
  
  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    return DailyRecord(
      date: json['date'] as String,
      newWordsCount: json['new_words_count'] as int? ?? 0,
      reviewWordsCount: json['review_words_count'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch((json['created_at'] as int) * 1000),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'new_words_count': newWordsCount,
      'review_words_count': reviewWordsCount,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
    };
  }
}
