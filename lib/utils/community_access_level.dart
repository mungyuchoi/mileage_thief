class CommunityAccessLevel {
  const CommunityAccessLevel({
    required this.gradeKey,
    required this.gradeName,
    required this.level,
    required this.rank,
  });

  static const int adminRank = 1000;
  static const int businessStartRank = 6;

  final String gradeKey;
  final String gradeName;
  final int level;
  final int rank;

  String get label => '$gradeName 레벨$level';

  Map<String, dynamic> toRestrictionMap() {
    return {
      'enabled': true,
      'minRank': rank,
      'minGrade': gradeKey,
      'minLevel': level,
      'label': label,
    };
  }

  static Map<String, dynamic> unrestrictedMap() {
    return {
      'enabled': false,
      'minRank': 0,
      'label': '전체 공개',
    };
  }

  static const List<CommunityAccessLevel> allLevels = [
    CommunityAccessLevel(
      gradeKey: 'economy',
      gradeName: '이코노미',
      level: 1,
      rank: 1,
    ),
    CommunityAccessLevel(
      gradeKey: 'economy',
      gradeName: '이코노미',
      level: 2,
      rank: 2,
    ),
    CommunityAccessLevel(
      gradeKey: 'economy',
      gradeName: '이코노미',
      level: 3,
      rank: 3,
    ),
    CommunityAccessLevel(
      gradeKey: 'economy',
      gradeName: '이코노미',
      level: 4,
      rank: 4,
    ),
    CommunityAccessLevel(
      gradeKey: 'economy',
      gradeName: '이코노미',
      level: 5,
      rank: 5,
    ),
    CommunityAccessLevel(
      gradeKey: 'business',
      gradeName: '비즈니스',
      level: 1,
      rank: 6,
    ),
    CommunityAccessLevel(
      gradeKey: 'business',
      gradeName: '비즈니스',
      level: 2,
      rank: 7,
    ),
    CommunityAccessLevel(
      gradeKey: 'business',
      gradeName: '비즈니스',
      level: 3,
      rank: 8,
    ),
    CommunityAccessLevel(
      gradeKey: 'business',
      gradeName: '비즈니스',
      level: 4,
      rank: 9,
    ),
    CommunityAccessLevel(
      gradeKey: 'business',
      gradeName: '비즈니스',
      level: 5,
      rank: 10,
    ),
    CommunityAccessLevel(
      gradeKey: 'first',
      gradeName: '퍼스트',
      level: 1,
      rank: 11,
    ),
    CommunityAccessLevel(
      gradeKey: 'first',
      gradeName: '퍼스트',
      level: 2,
      rank: 12,
    ),
  ];

  static bool canSetRestriction(Map<String, dynamic>? userProfile) {
    return userRank(userProfile) >= businessStartRank;
  }

  static int userRank(Map<String, dynamic>? userProfile) {
    if (userProfile == null) return 0;
    if (_hasAdminRole(userProfile['roles'])) return adminRank;

    final displayGrade = (userProfile['displayGrade'] ?? '').toString();
    final displayRank = _rankFromText(displayGrade);
    if (displayRank > 0) return displayRank;

    final grade = (userProfile['grade'] ?? '').toString();
    final level = _levelFromValue(userProfile['gradeLevel']);
    if (level == null) return 0;

    return _rankFromGradeAndLevel(grade, level);
  }

  static List<CommunityAccessLevel> selectableLevels(
    Map<String, dynamic>? userProfile,
  ) {
    final rank = userRank(userProfile);
    if (rank >= adminRank) return allLevels;
    return allLevels.where((level) => level.rank <= rank).toList();
  }

  static CommunityAccessLevel? fromRank(int? rank) {
    if (rank == null || rank <= 0) return null;
    for (final level in allLevels) {
      if (level.rank == rank) return level;
    }
    return null;
  }

  static CommunityAccessLevel? fromRestriction(dynamic value) {
    if (value is! Map) return null;

    final enabled = value['enabled'];
    final rank = _levelFromValue(value['minRank'] ?? value['rank']);
    if (enabled == false || rank == null || rank <= 0) return null;

    return fromRank(rank) ??
        CommunityAccessLevel(
          gradeKey: (value['minGrade'] ?? 'custom').toString(),
          gradeName: _gradeNameFromKey((value['minGrade'] ?? '').toString()),
          level: _levelFromValue(value['minLevel']) ?? 1,
          rank: rank,
        );
  }

  static CommunityAccessLevel? restrictionFromPost(
    Map<String, dynamic> post,
  ) {
    final restriction = fromRestriction(post['readRestriction']);
    if (restriction != null) return restriction;
    return fromRank(_levelFromValue(post['requiredReadRank']));
  }

  static String? denialMessageForPost(
    Map<String, dynamic> post,
    Map<String, dynamic>? userProfile,
  ) {
    final restriction = restrictionFromPost(post);
    if (restriction == null) return null;
    if (userRank(userProfile) >= restriction.rank) return null;
    return '이 글은 ${restriction.label}부터 볼 수 있습니다.';
  }

  static bool _hasAdminRole(dynamic roles) {
    if (roles is List) {
      return roles.any((role) {
        final value = role.toString().trim();
        return value == 'admin' || value == 'owner';
      });
    }
    if (roles is Map) {
      return roles['admin'] == true || roles['owner'] == true;
    }
    if (roles is String) {
      final value = roles.trim();
      return value == 'admin' || value == 'owner';
    }
    return false;
  }

  static int _rankFromText(String value) {
    final match = RegExp(
      r'(이코노미|비즈니스|퍼스트|economy|business|first)\s*(?:Lv\.?|레벨)?\s*\.?\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return 0;

    final grade = match.group(1) ?? '';
    final level = int.tryParse(match.group(2) ?? '');
    if (level == null) return 0;
    return _rankFromGradeAndLevel(grade, level);
  }

  static int _rankFromGradeAndLevel(String grade, int level) {
    final normalized = grade.trim().toLowerCase();
    if (normalized == '이코노미' || normalized == 'economy') {
      return level.clamp(1, 5);
    }
    if (normalized == '비즈니스' || normalized == 'business') {
      return 5 + level.clamp(1, 5);
    }
    if (normalized == '퍼스트' || normalized == 'first') {
      return 10 + level.clamp(1, 2);
    }
    return 0;
  }

  static int? _levelFromValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _gradeNameFromKey(String key) {
    switch (key.trim().toLowerCase()) {
      case 'economy':
        return '이코노미';
      case 'business':
        return '비즈니스';
      case 'first':
        return '퍼스트';
      default:
        return '이코노미';
    }
  }
}
