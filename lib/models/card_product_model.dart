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
  final String detailSummary;
  final Map<String, dynamic> images;
  final Map<String, dynamic> quality;
  final int version;
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
    required this.detailSummary,
    required this.images,
    required this.quality,
    required this.version,
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
    return CatalogCardProduct(
      id: doc.id,
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
      detailSummary: _string(data['detailSummary']),
      images: _map(data['images']),
      quality: _map(data['quality']),
      version: _int(data['version'], fallback: 0),
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
    return '$name $issuerName $rewardProgram $benefits'.toLowerCase();
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

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
