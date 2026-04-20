/// 사용자 프로필
class Profile {
  final String id;
  final String? nickname;
  final String? avatarUrl;
  final String? region;
  final String? gender;
  final int? birthYear;
  final String? phone;
  final String? kakaoId;
  final String sharingDefault;
  final bool agreedTerms;
  final bool agreedPrivacy;
  final bool agreedMarketing;
  final DateTime? agreedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    this.nickname,
    this.avatarUrl,
    this.region,
    this.gender,
    this.birthYear,
    this.phone,
    this.kakaoId,
    this.sharingDefault = 'all',
    this.agreedTerms = false,
    this.agreedPrivacy = false,
    this.agreedMarketing = false,
    this.agreedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Profile copyWith({
    String? nickname,
    String? avatarUrl,
    String? region,
    String? gender,
    int? birthYear,
    String? phone,
    String? kakaoId,
    String? sharingDefault,
    bool? agreedTerms,
    bool? agreedPrivacy,
    bool? agreedMarketing,
    DateTime? agreedAt,
  }) {
    return Profile(
      id: id,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      region: region ?? this.region,
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      phone: phone ?? this.phone,
      kakaoId: kakaoId ?? this.kakaoId,
      sharingDefault: sharingDefault ?? this.sharingDefault,
      agreedTerms: agreedTerms ?? this.agreedTerms,
      agreedPrivacy: agreedPrivacy ?? this.agreedPrivacy,
      agreedMarketing: agreedMarketing ?? this.agreedMarketing,
      agreedAt: agreedAt ?? this.agreedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        nickname: m['nickname'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        region: m['region'] as String?,
        gender: m['gender'] as String?,
        birthYear: (m['birth_year'] as num?)?.toInt(),
        phone: m['phone'] as String?,
        kakaoId: m['kakao_id'] as String?,
        sharingDefault: m['sharing_default'] as String? ?? 'all',
        agreedTerms: (m['agreed_terms'] as bool?) ?? false,
        agreedPrivacy: (m['agreed_privacy'] as bool?) ?? false,
        agreedMarketing: (m['agreed_marketing'] as bool?) ?? false,
        agreedAt: m['agreed_at'] != null
            ? DateTime.tryParse(m['agreed_at'] as String)
            : null,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nickname': nickname,
        'avatar_url': avatarUrl,
        'region': region,
        'gender': gender,
        'birth_year': birthYear,
        'phone': phone,
        'kakao_id': kakaoId,
        'sharing_default': sharingDefault,
        'agreed_terms': agreedTerms,
        'agreed_privacy': agreedPrivacy,
        'agreed_marketing': agreedMarketing,
        'agreed_at': agreedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
