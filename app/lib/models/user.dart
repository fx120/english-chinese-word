class User {
  final int id;
  final String mobile;
  final String? nickname;
  final String? avatar;
  final String? email;
  final int gender; // 0=未知, 1=男, 2=女
  final String? birthday;
  final String? bio;
  final DateTime createdAt;
  
  User({
    required this.id,
    required this.mobile,
    this.nickname,
    this.avatar,
    this.email,
    this.gender = 0,
    this.birthday,
    this.bio,
    required this.createdAt,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      mobile: json['mobile'] as String,
      nickname: json['nickname'] as String?,
      avatar: json['avatar'] as String?,
      email: json['email'] as String?,
      gender: json['gender'] as int? ?? 0,
      birthday: json['birthday'] as String?,
      bio: json['bio'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['created_at'] as int) * 1000)
          : DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mobile': mobile,
      'nickname': nickname,
      'avatar': avatar,
      'email': email,
      'gender': gender,
      'birthday': birthday,
      'bio': bio,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  String get genderText {
    switch (gender) {
      case 1: return '男';
      case 2: return '女';
      default: return '未设置';
    }
  }

  User copyWith({
    String? nickname,
    String? avatar,
    String? email,
    int? gender,
    String? birthday,
    String? bio,
  }) {
    return User(
      id: id,
      mobile: mobile,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      bio: bio ?? this.bio,
      createdAt: createdAt,
    );
  }
}
