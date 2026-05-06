import 'package:cloud_firestore/cloud_firestore.dart';

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) {
    return int.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  }
  return 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll('%', '').trim()) ?? 0;
  }
  return 0;
}

String _asString(dynamic value) => value?.toString().trim() ?? '';

Timestamp? _asTimestamp(dynamic value) => value is Timestamp ? value : null;

List<String> _asStringList(dynamic value) {
  if (value is Iterable) {
    return value
        .map((item) => _asString(item))
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

List<int> _asIntList(dynamic value) {
  if (value is Iterable) {
    return value.map((item) => _asInt(item)).where((item) => item > 0).toList();
  }
  return const <int>[];
}

class GiftcardDeal {
  final String id;
  final String sourceId;
  final String title;
  final String brandId;
  final String brandName;
  final String merchantId;
  final String merchantName;
  final int denominationKRW;
  final int faceValueKRW;
  final int priceKRW;
  final double discountRate;
  final int discountAmountKRW;
  final String buyUrl;
  final String status;
  final Timestamp? lastSeenAt;
  final Timestamp? lastChangedAt;
  final Timestamp? updatedAt;

  const GiftcardDeal({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.brandId,
    required this.brandName,
    required this.merchantId,
    required this.merchantName,
    required this.denominationKRW,
    required this.faceValueKRW,
    required this.priceKRW,
    required this.discountRate,
    required this.discountAmountKRW,
    required this.buyUrl,
    required this.status,
    this.lastSeenAt,
    this.lastChangedAt,
    this.updatedAt,
  });

  factory GiftcardDeal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return GiftcardDeal(
      id: doc.id,
      sourceId: _asString(data['sourceId']).isNotEmpty
          ? _asString(data['sourceId'])
          : doc.id,
      title: _asString(data['title']),
      brandId: _asString(data['brandId']),
      brandName: _asString(data['brandName']),
      merchantId: _asString(data['merchantId']),
      merchantName: _asString(data['merchantName']),
      denominationKRW: _asInt(data['denominationKRW']),
      faceValueKRW: _asInt(data['faceValueKRW']),
      priceKRW: _asInt(data['priceKRW']),
      discountRate: _asDouble(data['discountRate']),
      discountAmountKRW: _asInt(data['discountAmountKRW']),
      buyUrl: _asString(data['buyUrl']),
      status: _asString(data['status']).isEmpty
          ? 'unknown'
          : _asString(data['status']),
      lastSeenAt: _asTimestamp(data['lastSeenAt']),
      lastChangedAt: _asTimestamp(data['lastChangedAt']),
      updatedAt: _asTimestamp(data['updatedAt']),
    );
  }

  String get displayTitle {
    if (title.isNotEmpty) return title;
    final value = faceValueKRW > 0 ? faceValueKRW : denominationKRW;
    if (brandName.isNotEmpty && value > 0) {
      return '$brandName ${value ~/ 10000}만원권';
    }
    return brandName.isNotEmpty ? brandName : id;
  }

  bool get hasLivePrice => priceKRW > 0 && status != 'error';
}

class GiftcardDealSource {
  final String id;
  final String url;
  final String normalizedUrl;
  final String merchantId;
  final String merchantName;
  final String brandId;
  final String brandName;
  final int denominationKRW;
  final int faceValueKRW;
  final String displayName;
  final String memo;
  final bool enabled;
  final String lastCrawlStatus;
  final String lastCrawlError;
  final int lastPriceKRW;
  final double lastDiscountRate;
  final Timestamp? lastCrawledAt;
  final Timestamp? updatedAt;

  const GiftcardDealSource({
    required this.id,
    required this.url,
    required this.normalizedUrl,
    required this.merchantId,
    required this.merchantName,
    required this.brandId,
    required this.brandName,
    required this.denominationKRW,
    required this.faceValueKRW,
    required this.displayName,
    required this.memo,
    required this.enabled,
    required this.lastCrawlStatus,
    required this.lastCrawlError,
    required this.lastPriceKRW,
    required this.lastDiscountRate,
    this.lastCrawledAt,
    this.updatedAt,
  });

  factory GiftcardDealSource.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return GiftcardDealSource(
      id: doc.id,
      url: _asString(data['url']),
      normalizedUrl: _asString(data['normalizedUrl']),
      merchantId: _asString(data['merchantId']),
      merchantName: _asString(data['merchantName']),
      brandId: _asString(data['brandId']),
      brandName: _asString(data['brandName']),
      denominationKRW: _asInt(data['denominationKRW']),
      faceValueKRW: _asInt(data['faceValueKRW']),
      displayName: _asString(data['displayName']),
      memo: _asString(data['memo']),
      enabled: data['enabled'] != false,
      lastCrawlStatus: _asString(data['lastCrawlStatus']),
      lastCrawlError: _asString(data['lastCrawlError']),
      lastPriceKRW: _asInt(data['lastPriceKRW']),
      lastDiscountRate: _asDouble(data['lastDiscountRate']),
      lastCrawledAt: _asTimestamp(data['lastCrawledAt']),
      updatedAt: _asTimestamp(data['updatedAt']),
    );
  }

  String get title {
    if (displayName.isNotEmpty) return displayName;
    if (brandName.isNotEmpty && faceValueKRW > 0) {
      return '$brandName ${faceValueKRW ~/ 10000}만원권';
    }
    return url;
  }
}

class GiftcardDealSourceRequest {
  final String id;
  final String url;
  final String normalizedUrl;
  final String merchantId;
  final String merchantName;
  final String brandId;
  final String brandName;
  final int denominationKRW;
  final int faceValueKRW;
  final String status;
  final String requesterUid;
  final String reviewedByUid;
  final String sourceId;
  final String reviewNote;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? reviewedAt;

  const GiftcardDealSourceRequest({
    required this.id,
    required this.url,
    required this.normalizedUrl,
    required this.merchantId,
    required this.merchantName,
    required this.brandId,
    required this.brandName,
    required this.denominationKRW,
    required this.faceValueKRW,
    required this.status,
    required this.requesterUid,
    required this.reviewedByUid,
    required this.sourceId,
    required this.reviewNote,
    this.createdAt,
    this.updatedAt,
    this.reviewedAt,
  });

  factory GiftcardDealSourceRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return GiftcardDealSourceRequest(
      id: doc.id,
      url: _asString(data['url']),
      normalizedUrl: _asString(data['normalizedUrl']),
      merchantId: _asString(data['merchantId']),
      merchantName: _asString(data['merchantName']),
      brandId: _asString(data['brandId']),
      brandName: _asString(data['brandName']),
      denominationKRW: _asInt(data['denominationKRW']),
      faceValueKRW: _asInt(data['faceValueKRW']),
      status: _asString(data['status']).isEmpty
          ? 'pending'
          : _asString(data['status']),
      requesterUid: _asString(data['requesterUid']),
      reviewedByUid: _asString(data['reviewedByUid']),
      sourceId: _asString(data['sourceId']),
      reviewNote: _asString(data['reviewNote']),
      createdAt: _asTimestamp(data['createdAt']),
      updatedAt: _asTimestamp(data['updatedAt']),
      reviewedAt: _asTimestamp(data['reviewedAt']),
    );
  }

  int get amountKRW => faceValueKRW > 0 ? faceValueKRW : denominationKRW;

  bool get canApprove =>
      url.isNotEmpty &&
      merchantName.isNotEmpty &&
      brandName.isNotEmpty &&
      amountKRW > 0;

  String get title {
    if (brandName.isNotEmpty && amountKRW > 0) {
      return '$brandName ${amountKRW ~/ 10000}만원권';
    }
    if (brandName.isNotEmpty) return brandName;
    return url;
  }
}

class GiftcardDealAlert {
  final String id;
  final String name;
  final String scopeType;
  final List<String> dealIds;
  final List<String> brandIds;
  final List<String> merchantIds;
  final List<int> denominationsKRW;
  final double minDiscountRate;
  final int maxPriceKRW;
  final bool enabled;
  final String notifyMode;
  final String lastNotifiedDealId;
  final int lastNotifiedPriceKRW;
  final double lastNotifiedDiscountRate;
  final String dealTitle;
  final String merchantName;
  final String brandName;
  final Timestamp? lastNotifiedAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const GiftcardDealAlert({
    required this.id,
    required this.name,
    required this.scopeType,
    required this.dealIds,
    required this.brandIds,
    required this.merchantIds,
    required this.denominationsKRW,
    required this.minDiscountRate,
    required this.maxPriceKRW,
    required this.enabled,
    required this.notifyMode,
    required this.lastNotifiedDealId,
    required this.lastNotifiedPriceKRW,
    required this.lastNotifiedDiscountRate,
    required this.dealTitle,
    required this.merchantName,
    required this.brandName,
    this.lastNotifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory GiftcardDealAlert.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final name = _asString(data['name']);
    return GiftcardDealAlert(
      id: doc.id,
      name: name.isNotEmpty ? name : _asString(data['dealTitle']),
      scopeType: _asString(data['scopeType']).isEmpty
          ? 'deal'
          : _asString(data['scopeType']),
      dealIds: _asStringList(data['dealIds']),
      brandIds: _asStringList(data['brandIds']),
      merchantIds: _asStringList(data['merchantIds']),
      denominationsKRW: _asIntList(data['denominationsKRW']),
      minDiscountRate: _asDouble(data['minDiscountRate']),
      maxPriceKRW: _asInt(data['maxPriceKRW']),
      enabled: data['enabled'] != false,
      notifyMode: _asString(data['notifyMode']).isEmpty
          ? 'improved_only'
          : _asString(data['notifyMode']),
      lastNotifiedDealId: _asString(data['lastNotifiedDealId']),
      lastNotifiedPriceKRW: _asInt(data['lastNotifiedPriceKRW']),
      lastNotifiedDiscountRate: _asDouble(data['lastNotifiedDiscountRate']),
      dealTitle: _asString(data['dealTitle']),
      merchantName: _asString(data['merchantName']),
      brandName: _asString(data['brandName']),
      lastNotifiedAt: _asTimestamp(data['lastNotifiedAt']),
      createdAt: _asTimestamp(data['createdAt']),
      updatedAt: _asTimestamp(data['updatedAt']),
    );
  }
}
