import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/card_product_model.dart';
import '../models/community_label_model.dart';
import 'card_catalog_service.dart';

class CommunityLabelService {
  CommunityLabelService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<CommunityLabel>> search(String rawQuery) async {
    final query = rawQuery.trim();

    if (query.isEmpty) {
      return const <CommunityLabel>[];
    }

    final browseData = await browse();
    return filterBrowseItems(flattenBrowseData(browseData), query)
        .map((item) => item.label)
        .take(30)
        .toList(growable: false);
  }

  Future<CommunityLabelBrowseData> browse() async {
    final branchItemsFuture = _loadBranchItems();
    final giftcardItemsFuture = _loadGiftcardItems();
    final cardGroupsFuture = _loadCardGroups();
    final featureItems = _loadPointStayFeatureItems();
    final results = await Future.wait<Object>([
      branchItemsFuture,
      giftcardItemsFuture,
      cardGroupsFuture,
    ]);

    return CommunityLabelBrowseData(
      branchItems: results[0] as List<CommunityLabelBrowseItem>,
      giftcardItems: results[1] as List<CommunityLabelBrowseItem>,
      cardGroups: results[2] as List<CommunityLabelGroup>,
      featureItems: featureItems,
    );
  }

  static List<CommunityLabel> filterCandidates(
    Iterable<CommunityLabel> candidates,
    String rawQuery,
  ) {
    final query = _normalize(rawQuery);
    final unique = CommunityLabel.dedupe(candidates);
    if (query.isEmpty) return unique;

    final matched = unique.where((label) {
      final haystack = _normalize(
        '${label.displayName} ${label.subtitle} ${label.targetId} '
        '${label.type} ${label.key}',
      );
      return haystack.contains(query);
    }).toList();

    matched.sort((a, b) {
      final aName = _normalize(a.displayName);
      final bName = _normalize(b.displayName);
      final aStarts = aName.startsWith(query);
      final bStarts = bName.startsWith(query);
      if (aStarts != bStarts) return aStarts ? -1 : 1;

      final typeRank = _typeRank(a.type).compareTo(_typeRank(b.type));
      if (typeRank != 0) return typeRank;

      return a.displayName.compareTo(b.displayName);
    });

    return matched;
  }

  static List<CommunityLabelBrowseItem> filterBrowseItems(
    Iterable<CommunityLabelBrowseItem> candidates,
    String rawQuery,
  ) {
    final query = _normalize(rawQuery);
    final unique = _dedupeItems(candidates);
    if (query.isEmpty) return unique;

    final matched = unique.where((item) {
      final label = item.label;
      final haystack = _normalize(
        '${label.displayName} ${label.subtitle} ${label.targetId} '
        '${label.type} ${label.key} ${item.description} ${item.groupName}',
      );
      return haystack.contains(query);
    }).toList();

    matched.sort((a, b) {
      final aLabel = a.label;
      final bLabel = b.label;
      final aName = _normalize(aLabel.displayName);
      final bName = _normalize(bLabel.displayName);
      final aStarts = aName.startsWith(query);
      final bStarts = bName.startsWith(query);
      if (aStarts != bStarts) return aStarts ? -1 : 1;

      final typeRank = _typeRank(aLabel.type).compareTo(_typeRank(bLabel.type));
      if (typeRank != 0) return typeRank;

      return aLabel.displayName.compareTo(bLabel.displayName);
    });

    return matched;
  }

  static List<CommunityLabelBrowseItem> flattenBrowseData(
    CommunityLabelBrowseData data,
  ) {
    return [
      ...data.branchItems,
      ...data.giftcardItems,
      for (final group in data.cardGroups) ...group.items,
      ...data.featureItems,
    ];
  }

  static CommunityLabelBrowseItem branchItemFromData({
    required String branchId,
    required Map<String, dynamic> data,
  }) {
    final name = (data['name'] ?? data['title'] ?? branchId).toString();
    final address = (data['address'] ?? '').toString().trim();
    return CommunityLabelBrowseItem(
      label: CommunityLabel.branch(branchId: branchId, name: name),
      description: address,
    );
  }

  static CommunityLabelBrowseItem giftcardItemFromData({
    required String giftcardId,
    required Map<String, dynamic> data,
  }) {
    final sortOrder = (data['sortOrder'] as num?)?.toInt() ?? 9999;
    return CommunityLabelBrowseItem(
      label: CommunityLabel.giftcard(
        giftcardId: giftcardId,
        name: (data['name'] ?? giftcardId).toString(),
      ),
      description: '상품권 브랜드',
      sortOrder: sortOrder,
    );
  }

  static CommunityLabelBrowseItem cardItemFromProduct(
    CatalogCardProduct product,
  ) {
    return CommunityLabelBrowseItem(
      label: CommunityLabel.card(
        cardId: product.id,
        name: product.name,
        issuerName: product.issuerName,
      ),
      description: product.cardTypeLabel,
      groupId: product.issuerId ?? '',
      groupName: product.issuerName,
    );
  }

  static List<CommunityLabelGroup> groupCardItems({
    required Iterable<CommunityLabelBrowseItem> cardItems,
    required Iterable<CommunityLabelGroupInfo> issuers,
  }) {
    final visibleIssuers = issuers
        .where((issuer) => issuer.title.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => a.title.compareTo(b.title));
    final issuerById = {
      for (final issuer in visibleIssuers)
        if (issuer.id.trim().isNotEmpty) issuer.id.trim(): issuer,
    };
    final issuerByName = {
      for (final issuer in visibleIssuers) _normalize(issuer.title): issuer,
    };

    final grouped = <String, List<CommunityLabelBrowseItem>>{};
    final titles = <String, String>{};
    final order = <String, int>{};

    for (var i = 0; i < visibleIssuers.length; i++) {
      final issuer = visibleIssuers[i];
      final key = issuer.id.trim().isNotEmpty
          ? 'issuer:${issuer.id.trim()}'
          : 'issuer-name:${_normalize(issuer.title)}';
      grouped[key] = <CommunityLabelBrowseItem>[];
      titles[key] = issuer.title;
      order[key] = i;
    }

    const otherKey = 'other';
    for (final item in cardItems) {
      final issuerByItemId = issuerById[item.groupId.trim()];
      final issuerByItemName = issuerByName[_normalize(item.groupName)];
      final issuer = issuerByItemId ?? issuerByItemName;
      final key = issuer == null
          ? otherKey
          : issuer.id.trim().isNotEmpty
              ? 'issuer:${issuer.id.trim()}'
              : 'issuer-name:${_normalize(issuer.title)}';
      grouped.putIfAbsent(key, () => <CommunityLabelBrowseItem>[]);
      titles.putIfAbsent(key, () => issuer?.title ?? '기타 카드사');
      order.putIfAbsent(
        key,
        () => issuer == null ? 9999 : visibleIssuers.length,
      );
      grouped[key]!.add(item);
    }

    final groups =
        grouped.entries.where((entry) => entry.value.isNotEmpty).map((entry) {
      final items = entry.value
        ..sort((a, b) => a.label.displayName.compareTo(b.label.displayName));
      return CommunityLabelGroup(
        id: entry.key,
        title: titles[entry.key] ?? '기타 카드사',
        items: List<CommunityLabelBrowseItem>.unmodifiable(items),
        sortOrder: order[entry.key] ?? 9999,
      );
    }).toList()
          ..sort((a, b) {
            final orderCompare = a.sortOrder.compareTo(b.sortOrder);
            if (orderCompare != 0) return orderCompare;
            return a.title.compareTo(b.title);
          });

    return groups;
  }

  Future<List<CommunityLabelBrowseItem>> _loadBranchItems() async {
    final snap = await _firestore.collection('branches').get();
    final items = snap.docs
        .map(
          (doc) => branchItemFromData(
            branchId: doc.id,
            data: doc.data(),
          ),
        )
        .toList();
    items.sort(
      (a, b) => a.label.displayName.compareTo(b.label.displayName),
    );
    return items;
  }

  Future<List<CommunityLabelBrowseItem>> _loadGiftcardItems() async {
    final snap = await _firestore.collection('giftcards').get();
    final items = snap.docs
        .map(
          (doc) => giftcardItemFromData(
            giftcardId: doc.id,
            data: doc.data(),
          ),
        )
        .toList();
    items.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.label.displayName.compareTo(b.label.displayName);
    });
    return items;
  }

  Future<List<CommunityLabelGroup>> _loadCardGroups() async {
    final productsFuture = CardCatalogService.productsRef.limit(240).get();
    final issuersFuture = CardCatalogService.cardIssuersRef
        .where('isVisible', isEqualTo: true)
        .limit(80)
        .get();
    final productsSnap = await productsFuture;
    final issuersSnap = await issuersFuture;

    final cardItems = productsSnap.docs
        .map(CatalogCardProduct.fromFirestore)
        .map(cardItemFromProduct)
        .toList(growable: false);
    final issuers = issuersSnap.docs
        .map(CardIssuer.fromFirestore)
        .where((issuer) => issuer.isVisible)
        .map(
          (issuer) => CommunityLabelGroupInfo(
            id: issuer.id,
            title: issuer.nameKo,
          ),
        )
        .toList(growable: false);

    return groupCardItems(cardItems: cardItems, issuers: issuers);
  }

  List<CommunityLabelBrowseItem> _loadPointStayFeatureItems() {
    return CommunityLabel.pointStayFeatures().asMap().entries.map((entry) {
      final label = entry.value;
      return CommunityLabelBrowseItem(
        label: label,
        description: label.targetId == CommunityLabel.pointStayFeatureId
            ? '포인트 숙박 전체'
            : '호텔 프로그램',
        sortOrder: entry.key,
      );
    }).toList(growable: false);
  }

  static List<CommunityLabelBrowseItem> _dedupeItems(
    Iterable<CommunityLabelBrowseItem> items,
  ) {
    final seen = <String>{};
    final result = <CommunityLabelBrowseItem>[];
    for (final item in items) {
      if (!item.label.isValid) continue;
      if (!seen.add(item.label.key)) continue;
      result.add(item);
    }
    return result;
  }

  static int _typeRank(String type) {
    switch (type) {
      case 'branch':
        return 0;
      case 'giftcard':
        return 1;
      case 'card':
        return 2;
      case 'calculator':
        return 3;
      case 'feature':
        return 4;
      default:
        return 9;
    }
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }
}

class CommunityLabelBrowseData {
  final List<CommunityLabelBrowseItem> branchItems;
  final List<CommunityLabelBrowseItem> giftcardItems;
  final List<CommunityLabelGroup> cardGroups;
  final List<CommunityLabelBrowseItem> featureItems;

  const CommunityLabelBrowseData({
    required this.branchItems,
    required this.giftcardItems,
    required this.cardGroups,
    this.featureItems = const <CommunityLabelBrowseItem>[],
  });
}

class CommunityLabelBrowseItem {
  final CommunityLabel label;
  final String description;
  final String groupId;
  final String groupName;
  final int sortOrder;

  const CommunityLabelBrowseItem({
    required this.label,
    this.description = '',
    this.groupId = '',
    this.groupName = '',
    this.sortOrder = 9999,
  });
}

class CommunityLabelGroup {
  final String id;
  final String title;
  final List<CommunityLabelBrowseItem> items;
  final int sortOrder;

  const CommunityLabelGroup({
    required this.id,
    required this.title,
    required this.items,
    this.sortOrder = 9999,
  });
}

class CommunityLabelGroupInfo {
  final String id;
  final String title;

  const CommunityLabelGroupInfo({
    required this.id,
    required this.title,
  });
}
