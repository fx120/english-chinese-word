class Word {
  final int id;
  final int? serverId;
  final String word;
  final String? phonetic;
  final String? partOfSpeech;
  final String definition;
  final String? example;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  Word({
    required this.id,
    this.serverId,
    required this.word,
    this.phonetic,
    this.partOfSpeech,
    required this.definition,
    this.example,
    required this.createdAt,
    this.updatedAt,
  });
  
  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as int,
      serverId: json['server_id'] as int?,
      word: json['word'] as String,
      phonetic: json['phonetic'] as String?,
      partOfSpeech: json['part_of_speech'] as String?,
      definition: json['definition'] as String,
      example: json['example'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['created_at'] as int) * 1000)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((json['updated_at'] as int) * 1000)
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'word': word,
      'phonetic': phonetic,
      'part_of_speech': partOfSpeech,
      'definition': definition,
      'example': example,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'updated_at': updatedAt != null ? updatedAt!.millisecondsSinceEpoch ~/ 1000 : null,
    };
  }
}
