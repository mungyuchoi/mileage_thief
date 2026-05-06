import 'package:cloud_firestore/cloud_firestore.dart';

class CatalogCardProduct {
  final String id;
  final String name;
  final String issuerName;
  final String? issuerId;
  final String cardType;
  final String status;
  final String sourceType;
  final String? rewardProgram;
  final Map<String, dynamic> annualFee;
  final Map<String, dynamic> previousMonthSpend;
  final List<dynamic> primaryBenefits;
  final List<dynamic> exclusions;
  final List<String> benefitCategoryIds;
  final List<String> mileagePrograms;
  final Map<String, dynamic> travelFlags;
  final Map<String, dynamic> loungeSummary;
  final Map<String, dynamic> eventSummary;
  final Map<String, dynamic> sourceRefs;
  final String detailSummary;
  final Map<String, dynamic> images;
  final Map<String, dynamic> quality;
  final int version;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final String? createdByUid;
  final String? updatedByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> raw;

  const CatalogCardProduct({
    required this.id,
    required this.name,
    required this.issuerName,
    required this.cardType,
    required this.status,
    required this.sourceType,
    required this.annualFee,
    required this.previousMonthSpend,
    required this.primaryBenefits,
    required this.exclusions,
    required this.benefitCategoryIds,
    required this.mileagePrograms,
    required this.travelFlags,
    required this.loungeSummary,
    required this.eventSummary,
    required this.sourceRefs,
    required this.detailSummary,
    required this.images,
    required this.quality,
    required this.version,
    required this.likesCount,
    required this.commentsCount,
    required this.viewsCount,
    required this.raw,
    this.issuerId,
    this.rewardProgram,
    this.createdByUid,
    this.updatedByUid,
    this.createdAt,
    this.updatedAt,
  });

  factory CatalogCardProduct.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CatalogCardProduct.fromMap(doc.id, data);
  }

  factory CatalogCardProduct.fromMap(String id, Map<String, dynamic> data) {
    return CatalogCardProduct(
      id: id,
      name: _string(data['name'], fallback: '카드명 미입력'),
      issuerName: _string(data['issuerName'], fallback: '카드사 미입력'),
      issuerId: _nullableString(data['issuerId']),
      cardType: _string(data['cardType'], fallback: 'unknown'),
      status: _string(data['status'], fallback: 'active'),
      sourceType: _string(data['sourceType'], fallback: 'userCreated'),
      rewardProgram: _nullableString(data['rewardProgram']),
      annualFee: _map(data['annualFee']),
      previousMonthSpend: _map(data['previousMonthSpend']),
      primaryBenefits: _list(data['primaryBenefits']),
      exclusions: _list(data['exclusions']),
      benefitCategoryIds: _stringList(data['benefitCategoryIds']),
      mileagePrograms: _stringList(data['mileagePrograms']),
      travelFlags: _map(data['travelFlags']),
      loungeSummary: _map(data['loungeSummary']),
      eventSummary: _map(data['eventSummary']),
      sourceRefs: _map(data['sourceRefs']),
      detailSummary: _string(data['detailSummary']),
      images: _map(data['images']),
      quality: _map(data['quality']),
      version: _int(data['version'], fallback: 0),
      likesCount: _int(data['likesCount']),
      commentsCount: _int(data['commentsCount']),
      viewsCount: _int(data['viewsCount']),
      createdByUid: _nullableString(data['createdByUid']),
      updatedByUid: _nullableString(data['updatedByUid']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      raw: data,
    );
  }

  String get cardTypeLabel {
    switch (cardType) {
      case 'credit':
        return '신용';
      case 'check':
        return '체크';
      case 'hybrid':
        return '하이브리드';
      default:
        return '기타';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return '사용 가능';
      case 'discontinued':
        return '단종';
      case 'hidden':
        return '숨김';
      case 'pending':
        return '정보 확인중';
      default:
        return status;
    }
  }

  String get annualFeeSummary => _string(annualFee['summary']).isNotEmpty
      ? _string(annualFee['summary'])
      : '-';

  String get previousMonthSpendSummary {
    final summary = _string(previousMonthSpend['summary']);
    if (summary.isNotEmpty) return summary;
    final amount = previousMonthSpend['amountKRW'];
    if (amount is num && amount > 0) return '${amount.toInt()}원';
    return '-';
  }

  String? get mainStoragePath {
    final main = images['main'];
    if (main is Map) {
      return _nullableString(main['storagePath']);
    }
    return null;
  }

  String? get mainDownloadUrl {
    final main = images['main'];
    if (main is Map) {
      return _nullableString(main['downloadUrl']);
    }
    return null;
  }

  String get searchableText {
    final benefits = primaryBenefits.map(displayValue).join(' ');
    final categories = benefitCategoryIds.join(' ');
    final programs = mileagePrograms.join(' ');
    return '$name $issuerName $rewardProgram $benefits $categories $programs'
        .toLowerCase();
  }

  bool get isMileageCard {
    final haystack = [
      rewardProgram,
      ...mileagePrograms,
      ...benefitCategoryIds,
      detailSummary,
      ...primaryBenefits.map(displayValue),
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains('mile') ||
        haystack.contains('마일') ||
        haystack.contains('skypass') ||
        haystack.contains('스카이패스') ||
        haystack.contains('아시아나');
  }

  bool get isTravelCard {
    final haystack = [
      ...benefitCategoryIds,
      ...travelFlags.entries.map((entry) => '${entry.key} ${entry.value}'),
      detailSummary,
      ...primaryBenefits.map(displayValue),
    ].join(' ').toLowerCase();
    return travelFlags.values.any((value) => value == true) ||
        haystack.contains('travel') ||
        haystack.contains('트래블') ||
        haystack.contains('여행') ||
        haystack.contains('해외') ||
        haystack.contains('라운지');
  }

  String get loungeSummaryText {
    final direct = _string(loungeSummary['summary']);
    if (direct.isNotEmpty) return direct;
    final annual = loungeSummary['annualVisits'];
    if (annual is num && annual > 0) return '공항라운지 연 ${annual.toInt()}회';
    final values =
        loungeSummary.values.map(displayValue).where((v) => v.isNotEmpty);
    return values.isEmpty ? '' : values.take(2).join(' · ');
  }

  String get eventSummaryText {
    final direct = _string(eventSummary['summary']);
    if (direct.isNotEmpty) return direct;
    final cashback = eventSummary['cashbackKRW'];
    if (cashback is num && cashback > 0) {
      return '최대 ${cashback.toInt()}원 혜택';
    }
    final values =
        eventSummary.values.map(displayValue).where((v) => v.isNotEmpty);
    return values.isEmpty ? '' : values.take(2).join(' · ');
  }
}

class CardIssuer {
  final String id;
  final String nameKo;
  final String? nameEng;
  final String? logoUrl;
  final String? color;
  final bool eventEnabled;
  final bool isVisible;
  final Map<String, dynamic> raw;

  const CardIssuer({
    required this.id,
    required this.nameKo,
    required this.eventEnabled,
    required this.isVisible,
    required this.raw,
    this.nameEng,
    this.logoUrl,
    this.color,
  });

  factory CardIssuer.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CardIssuer(
      id: doc.id,
      nameKo: _string(data['nameKo'], fallback: doc.id),
      nameEng: _nullableString(data['nameEng']),
      logoUrl: _nullableString(data['logoUrl']),
      color: _nullableString(data['color']),
      eventEnabled: data['eventEnabled'] == true,
      isVisible: data['isVisible'] != false,
      raw: data,
    );
  }
}

class CardEvent {
  final String id;
  final String title;
  final String issuerName;
  final String type;
  final String? subject;
  final List<String> cardIds;
  final int benefitAmountKRW;
  final String? benefitText;
  final String? applyUrl;
  final String? sourceUrl;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isVisible;
  final bool isLive;
  final Map<String, dynamic> raw;

  const CardEvent({
    required this.id,
    required this.title,
    required this.issuerName,
    required this.type,
    required this.cardIds,
    required this.benefitAmountKRW,
    required this.isVisible,
    required this.isLive,
    required this.raw,
    this.subject,
    this.benefitText,
    this.applyUrl,
    this.sourceUrl,
    this.startsAt,
    this.endsAt,
  });

  factory CardEvent.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CardEvent.fromMap(doc.id, data);
  }

  factory CardEvent.fromMap(String id, Map<String, dynamic> data) {
    return CardEvent(
      id: id,
      title: _string(data['title'], fallback: '카드 이벤트'),
      issuerName:
          _string(data['issuerName'] ?? data['corpName'], fallback: '카드사'),
      type: _string(data['type'], fallback: 'event'),
      subject: _nullableString(data['subject']),
      cardIds: _stringList(data['cardIds']),
      benefitAmountKRW: _int(data['benefitAmountKRW'] ?? data['cashbackKRW']),
      benefitText: _nullableString(data['benefitText'] ?? data['summary']),
      applyUrl: _nullableString(data['applyUrl'] ?? data['eventUrl']),
      sourceUrl: _nullableString(data['sourceUrl']),
      startsAt: _date(data['startsAt'] ?? data['startAt']),
      endsAt: _date(data['endsAt'] ?? data['endAt']),
      isVisible: data['isVisible'] != false,
      isLive: data['isLive'] != false,
      raw: data,
    );
  }

  bool get isExpired {
    final end = endsAt;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  String get displayBenefit {
    if (benefitText != null && benefitText!.trim().isNotEmpty) {
      return benefitText!.trim();
    }
    if (benefitAmountKRW > 0) return '최대 $benefitAmountKRW원 혜택';
    return subject ?? '진행중인 혜택';
  }
}

class CardRanking {
  final String id;
  final String title;
  final String basis;
  final String periodLabel;
  final List<String> cardIds;
  final DateTime? calculatedAt;
  final Map<String, dynamic> raw;

  const CardRanking({
    required this.id,
    required this.title,
    required this.basis,
    required this.periodLabel,
    required this.cardIds,
    required this.raw,
    this.calculatedAt,
  });

  factory CardRanking.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CardRanking(
      id: doc.id,
      title: _string(data['title'], fallback: doc.id),
      basis: _string(data['basis'], fallback: '마일캐치 데이터'),
      periodLabel: _string(data['periodLabel'], fallback: '실시간'),
      cardIds: _stringList(data['cardIds']),
      calculatedAt: _date(data['calculatedAt']),
      raw: data,
    );
  }
}

class CardPreferenceProfile {
  final String preferredAirline;
  final int monthlySpendKRW;
  final Map<String, int> spendCategories;
  final bool usesOverseas;
  final bool wantsLounge;
  final bool usesGiftcard;
  final List<String> benefitCategoryIds;
  final int maxAnnualFeeKRW;
  final int maxPreviousMonthSpendKRW;
  final int mileValueKRW;

  const CardPreferenceProfile({
    required this.preferredAirline,
    required this.monthlySpendKRW,
    required this.spendCategories,
    required this.usesOverseas,
    required this.wantsLounge,
    required this.usesGiftcard,
    required this.benefitCategoryIds,
    required this.maxAnnualFeeKRW,
    required this.maxPreviousMonthSpendKRW,
    this.mileValueKRW = 15,
  });

  factory CardPreferenceProfile.defaults() {
    return const CardPreferenceProfile(
      preferredAirline: '대한항공',
      monthlySpendKRW: 1000000,
      spendCategories: {
        'general': 500000,
        'overseas': 100000,
        'onlineShopping': 150000,
        'mart': 100000,
        'telecomSubscription': 100000,
        'travel': 50000,
        'giftcard': 0,
      },
      usesOverseas: true,
      wantsLounge: true,
      usesGiftcard: true,
      benefitCategoryIds: ['mileage', 'travel', 'lounge'],
      maxAnnualFeeKRW: 150000,
      maxPreviousMonthSpendKRW: 500000,
      mileValueKRW: 15,
    );
  }

  factory CardPreferenceProfile.fromMap(Map<String, dynamic> data) {
    final monthlySpend = _int(data['monthlySpendKRW'], fallback: 1000000);
    final spendCategories = _intMap(data['spendCategories']);
    return CardPreferenceProfile(
      preferredAirline: _string(data['preferredAirline'], fallback: '대한항공'),
      monthlySpendKRW: monthlySpend,
      spendCategories: spendCategories.isEmpty
          ? _defaultSpendCategories(monthlySpend)
          : spendCategories,
      usesOverseas: data['usesOverseas'] != false,
      wantsLounge: data['wantsLounge'] != false,
      usesGiftcard: data['usesGiftcard'] != false,
      benefitCategoryIds: _stringList(data['benefitCategoryIds']).isEmpty
          ? const ['mileage', 'travel', 'lounge']
          : _stringList(data['benefitCategoryIds']),
      maxAnnualFeeKRW: _int(data['maxAnnualFeeKRW'], fallback: 150000),
      maxPreviousMonthSpendKRW:
          _int(data['maxPreviousMonthSpendKRW'], fallback: 500000),
      mileValueKRW: _int(data['mileValueKRW'], fallback: 15),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'preferredAirline': preferredAirline,
      'monthlySpendKRW': monthlySpendKRW,
      'spendCategories': spendCategories,
      'usesOverseas': usesOverseas,
      'wantsLounge': wantsLounge,
      'usesGiftcard': usesGiftcard,
      'benefitCategoryIds': benefitCategoryIds,
      'maxAnnualFeeKRW': maxAnnualFeeKRW,
      'maxPreviousMonthSpendKRW': maxPreviousMonthSpendKRW,
      'mileValueKRW': mileValueKRW,
    };
  }
}

class CardMatchResult {
  final String cardId;
  final int score;
  final int overallScore;
  final int sangtechScore;
  final int mileageScore;
  final int travelScore;
  final int communityScore;
  final int estimatedMonthlyMiles;
  final int estimatedAnnualValueKRW;
  final int? annualFeeKRW;
  final int? estimatedAnnualNetValueKRW;
  final int? breakEvenMonthlySpendKRW;
  final List<String> reasons;
  final CatalogCardProduct? product;
  final Map<String, dynamic> raw;

  const CardMatchResult({
    required this.cardId,
    required this.score,
    int? overallScore,
    this.sangtechScore = 0,
    this.mileageScore = 0,
    this.travelScore = 0,
    this.communityScore = 0,
    required this.estimatedMonthlyMiles,
    required this.estimatedAnnualValueKRW,
    this.annualFeeKRW,
    this.estimatedAnnualNetValueKRW,
    this.breakEvenMonthlySpendKRW,
    required this.reasons,
    required this.raw,
    this.product,
  }) : overallScore = overallScore ?? score;

  factory CardMatchResult.fromMap(Map<String, dynamic> data) {
    final productData = data['product'];
    CatalogCardProduct? product;
    if (productData is Map) {
      product = CatalogCardProduct.fromMap(
        _string(data['cardId']),
        Map<String, dynamic>.from(productData),
      );
    }
    return CardMatchResult(
      cardId: _string(data['cardId']),
      score: _int(data['score']),
      overallScore: _int(data['overallScore'] ?? data['score']),
      sangtechScore: _int(data['sangtechScore']),
      mileageScore: _int(data['mileageScore']),
      travelScore: _int(data['travelScore']),
      communityScore: _int(data['communityScore']),
      estimatedMonthlyMiles: _int(data['estimatedMonthlyMiles']),
      estimatedAnnualValueKRW: _int(data['estimatedAnnualValueKRW']),
      annualFeeKRW: _nullableInt(data['annualFeeKRW']),
      estimatedAnnualNetValueKRW:
          _nullableInt(data['estimatedAnnualNetValueKRW']),
      breakEvenMonthlySpendKRW: _nullableInt(data['breakEvenMonthlySpendKRW']),
      reasons: _stringList(data['reasons']),
      product: product,
      raw: data,
    );
  }
}

class CardRecommendationSection {
  final String key;
  final String title;
  final String subtitle;
  final List<CardMatchResult> matches;
  final Map<String, dynamic> raw;

  const CardRecommendationSection({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.matches,
    required this.raw,
  });

  factory CardRecommendationSection.fromMap(Map<String, dynamic> data) {
    return CardRecommendationSection(
      key: _string(data['key'], fallback: 'overall'),
      title: _string(data['title'], fallback: '추천 카드'),
      subtitle: _string(data['subtitle'], fallback: '마일캐치 추천 결과입니다.'),
      matches: ((data['matches'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => CardMatchResult.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false),
      raw: data,
    );
  }
}

class CardRecommendationDashboard {
  final CardPreferenceProfile profile;
  final List<CardRecommendationSection> sections;
  final List<CardMatchResult> comparisonRows;
  final List<CardMatchResult> matches;
  final Map<String, dynamic> raw;

  const CardRecommendationDashboard({
    required this.profile,
    required this.sections,
    required this.comparisonRows,
    required this.matches,
    required this.raw,
  });

  factory CardRecommendationDashboard.fromMap(
    Map<String, dynamic> data, {
    CardPreferenceProfile? fallbackProfile,
  }) {
    final profileData = data['profile'];
    final profile = profileData is Map
        ? CardPreferenceProfile.fromMap(Map<String, dynamic>.from(profileData))
        : fallbackProfile ?? CardPreferenceProfile.defaults();
    final matches = ((data['matches'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => CardMatchResult.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
    var sections = ((data['sections'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => CardRecommendationSection.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .where((section) => section.matches.isNotEmpty)
        .toList(growable: false);
    if (sections.isEmpty && matches.isNotEmpty) {
      sections = [
        CardRecommendationSection(
          key: 'overall',
          title: '내 소비 기준 TOP',
          subtitle: '마일리지, 상테크, 여행 조건을 함께 반영했습니다.',
          matches: matches,
          raw: const <String, dynamic>{'fallback': true},
        ),
      ];
    }
    final comparisonRows = ((data['comparisonRows'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => CardMatchResult.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
    return CardRecommendationDashboard(
      profile: profile,
      sections: sections,
      comparisonRows: comparisonRows.isEmpty ? matches : comparisonRows,
      matches: matches,
      raw: data,
    );
  }

  factory CardRecommendationDashboard.fromMatches({
    required CardPreferenceProfile profile,
    required List<CardRecommendationSection> sections,
    required List<CardMatchResult> comparisonRows,
  }) {
    final matches =
        sections.isEmpty ? const <CardMatchResult>[] : sections.first.matches;
    return CardRecommendationDashboard(
      profile: profile,
      sections: sections,
      comparisonRows: comparisonRows,
      matches: matches,
      raw: const <String, dynamic>{'source': 'local'},
    );
  }
}

class CardRelatedPost {
  final String id;
  final String dateString;
  final String boardId;
  final String boardName;
  final String title;
  final int likesCount;
  final int commentCount;
  final int viewsCount;
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  const CardRelatedPost({
    required this.id,
    required this.dateString,
    required this.boardId,
    required this.boardName,
    required this.title,
    required this.likesCount,
    required this.commentCount,
    required this.viewsCount,
    required this.raw,
    this.createdAt,
  });

  factory CardRelatedPost.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final parent = doc.reference.parent.parent;
    return CardRelatedPost(
      id: _string(data['postId'], fallback: doc.id),
      dateString: parent?.id ?? _string(data['dateString']),
      boardId: _string(data['boardId'], fallback: 'deal'),
      boardName: _string(data['boardName'], fallback: '적립/카드 혜택'),
      title: _string(data['title'], fallback: '카드 이야기'),
      likesCount: _int(data['likesCount']),
      commentCount: _int(data['commentCount']),
      viewsCount: _int(data['viewsCount']),
      createdAt: _date(data['createdAt']),
      raw: data,
    );
  }
}

class CardProductRevision {
  final String id;
  final String action;
  final String status;
  final String? actorUid;
  final int versionFrom;
  final int versionTo;
  final String? rollbackOfRevisionId;
  final List<CardRevisionChange> changes;
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  const CardProductRevision({
    required this.id,
    required this.action,
    required this.status,
    required this.versionFrom,
    required this.versionTo,
    required this.changes,
    required this.raw,
    this.actorUid,
    this.rollbackOfRevisionId,
    this.createdAt,
  });

  factory CardProductRevision.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final changes = _list(data['changeSet'])
        .whereType<Map>()
        .map((item) => CardRevisionChange.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList();
    return CardProductRevision(
      id: doc.id,
      action: _string(data['action'], fallback: 'edit'),
      status: _string(data['status'], fallback: 'applied'),
      actorUid: _nullableString(data['actorUid']),
      versionFrom: _int(data['versionFrom']),
      versionTo: _int(data['versionTo']),
      rollbackOfRevisionId: _nullableString(data['rollbackOfRevisionId']),
      changes: changes,
      createdAt: _date(data['createdAt']),
      raw: data,
    );
  }

  String get actionLabel {
    switch (action) {
      case 'create':
        return '추가';
      case 'rollback':
        return '롤백';
      default:
        return '수정';
    }
  }
}

class CardDetailSection {
  final String id;
  final String title;
  final String body;
  final String html;
  final String type;
  final int sortOrder;
  final Map<String, dynamic> raw;

  const CardDetailSection({
    required this.id,
    required this.title,
    required this.body,
    required this.html,
    required this.type,
    required this.sortOrder,
    required this.raw,
  });

  factory CardDetailSection.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CardDetailSection(
      id: doc.id,
      title: _string(data['title'], fallback: doc.id),
      body: _string(data['body']),
      html: _string(data['html']),
      type: _string(data['type'], fallback: 'detail'),
      sortOrder: _int(data['sortOrder']),
      raw: data,
    );
  }

  String get displayBody => body.isNotEmpty ? body : html;
}

class CardRevisionChange {
  final String path;
  final dynamic oldValue;
  final dynamic newValue;

  const CardRevisionChange({
    required this.path,
    this.oldValue,
    this.newValue,
  });

  factory CardRevisionChange.fromMap(Map<String, dynamic> data) {
    return CardRevisionChange(
      path: _string(data['path']),
      oldValue: data['oldValue'],
      newValue: data['newValue'],
    );
  }
}

class CardProductComment {
  final String id;
  final String cardId;
  final String? parentCommentId;
  final String body;
  final String authorUid;
  final String displayName;
  final String? photoURL;
  final String displayGrade;
  final bool isAdmin;
  final bool isDeleted;
  final int replyCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> raw;

  const CardProductComment({
    required this.id,
    required this.cardId,
    required this.body,
    required this.authorUid,
    required this.displayName,
    required this.displayGrade,
    required this.isAdmin,
    required this.isDeleted,
    required this.replyCount,
    required this.raw,
    this.parentCommentId,
    this.photoURL,
    this.createdAt,
    this.updatedAt,
  });

  factory CardProductComment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final author = _map(data['author']);
    return CardProductComment(
      id: doc.id,
      cardId: _string(data['cardId']),
      parentCommentId: _nullableString(data['parentCommentId']),
      body: _string(data['body']),
      authorUid: _string(author['uid']),
      displayName: _string(author['displayName'], fallback: '익명'),
      photoURL: _nullableString(author['photoURL']),
      displayGrade: _string(author['displayGrade'], fallback: '이코노미 Lv.1'),
      isAdmin: author['isAdmin'] == true,
      isDeleted: data['isDeleted'] == true,
      replyCount: _int(data['replyCount']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      raw: data,
    );
  }

  bool get isReply => parentCommentId != null;
}

String displayValue(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is num || value is bool) return value.toString();
  if (value is Map) {
    final title = _string(value['title']);
    final label = _string(value['label']);
    final name = _string(value['name']);
    final summary = _string(value['summary']);
    return [title, label, name, summary].firstWhere(
      (item) => item.isNotEmpty,
      orElse: () => value.entries
          .map((entry) => '${entry.key}: ${displayValue(entry.value)}')
          .join(', '),
    );
  }
  if (value is Iterable) {
    return value.map(displayValue).where((item) => item.isNotEmpty).join(', ');
  }
  return value.toString();
}

String _string(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(dynamic value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), ''));
    return parsed;
  }
  return null;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, int> _intMap(dynamic value) {
  if (value is! Map) return const <String, int>{};
  return Map<String, int>.fromEntries(
    value.entries
        .map((entry) => MapEntry(entry.key.toString(), _int(entry.value)))
        .where((entry) => entry.key.trim().isNotEmpty && entry.value >= 0),
  );
}

Map<String, int> _defaultSpendCategories(int monthlySpend) {
  final safeMonthlySpend = monthlySpend <= 0 ? 1000000 : monthlySpend;
  int portion(double ratio) => (safeMonthlySpend * ratio).round();
  return {
    'general': portion(0.50),
    'overseas': portion(0.10),
    'onlineShopping': portion(0.15),
    'mart': portion(0.10),
    'telecomSubscription': portion(0.10),
    'travel': portion(0.05),
    'giftcard': 0,
  };
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
}

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final text = _string(value);
  if (text.isEmpty) return const <String>[];
  return text
      .split(RegExp(r'[,/|]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
