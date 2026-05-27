import 'package:cloud_firestore/cloud_firestore.dart';

class PointCategory {
  const PointCategory._();

  static const String airline = 'airline';
  static const String hotel = 'hotel';
  static const String card = 'card';

  static const List<String> values = [airline, hotel, card];

  static String label(String category) {
    switch (category) {
      case airline:
        return '항공';
      case hotel:
        return '호텔';
      case card:
        return '카드';
      default:
        return '포인트';
    }
  }
}

class PointBrand {
  const PointBrand({
    required this.id,
    required this.category,
    required this.name,
    required this.assetPath,
    required this.pointLabel,
    required this.sortOrder,
    this.fallbackAssetPath,
  });

  final String id;
  final String category;
  final String name;
  final String assetPath;
  final String pointLabel;
  final int sortOrder;
  final String? fallbackAssetPath;
}

class PointBrandCatalog {
  const PointBrandCatalog._();

  static const List<PointBrand> brands = [
    PointBrand(
      id: 'korean_air',
      category: PointCategory.airline,
      name: '대한항공',
      assetPath: 'asset/icon/points/korean_air.png',
      fallbackAssetPath: 'asset/img/app_dan.png',
      pointLabel: '마일',
      sortOrder: 10,
    ),
    PointBrand(
      id: 'asiana',
      category: PointCategory.airline,
      name: '아시아나',
      assetPath: 'asset/icon/points/asiana.png',
      fallbackAssetPath: 'asset/img/airline_oz.png',
      pointLabel: '마일',
      sortOrder: 20,
    ),
    PointBrand(
      id: 'jal',
      category: PointCategory.airline,
      name: 'JAL',
      assetPath: 'asset/icon/points/jal.png',
      fallbackAssetPath: 'asset/img/airline_jl.png',
      pointLabel: '마일',
      sortOrder: 30,
    ),
    PointBrand(
      id: 'ana',
      category: PointCategory.airline,
      name: 'ANA',
      assetPath: 'asset/icon/points/ana.png',
      fallbackAssetPath: 'asset/img/airline_nh.png',
      pointLabel: '마일',
      sortOrder: 40,
    ),
    PointBrand(
      id: 'cathay_pacific',
      category: PointCategory.airline,
      name: '캐세이퍼시픽',
      assetPath: 'asset/icon/points/cathay_pacific.png',
      fallbackAssetPath: 'asset/img/airline_cx.png',
      pointLabel: '마일',
      sortOrder: 50,
    ),
    PointBrand(
      id: 'china_airlines',
      category: PointCategory.airline,
      name: '중화항공',
      assetPath: 'asset/icon/points/china_airlines.png',
      fallbackAssetPath: 'asset/img/airline_ci.png',
      pointLabel: '마일',
      sortOrder: 60,
    ),
    PointBrand(
      id: 'jeju_air',
      category: PointCategory.airline,
      name: '제주항공',
      assetPath: 'asset/icon/points/jeju_air.png',
      fallbackAssetPath: 'asset/img/airline_7c.png',
      pointLabel: '마일',
      sortOrder: 70,
    ),
    PointBrand(
      id: 'air_busan',
      category: PointCategory.airline,
      name: '에어부산',
      assetPath: 'asset/icon/points/air_busan.png',
      fallbackAssetPath: 'asset/img/airline_bx.png',
      pointLabel: '마일',
      sortOrder: 80,
    ),
    PointBrand(
      id: 'jin_air',
      category: PointCategory.airline,
      name: '진에어',
      assetPath: 'asset/icon/points/jin_air.png',
      fallbackAssetPath: 'asset/img/airline_lj.png',
      pointLabel: '마일',
      sortOrder: 90,
    ),
    PointBrand(
      id: 'marriott',
      category: PointCategory.hotel,
      name: 'Marriott',
      assetPath: 'asset/icon/points/marriott.png',
      fallbackAssetPath: 'asset/icon/icon_marriott.svg',
      pointLabel: '포인트',
      sortOrder: 10,
    ),
    PointBrand(
      id: 'hilton',
      category: PointCategory.hotel,
      name: 'Hilton',
      assetPath: 'asset/icon/points/hilton.png',
      fallbackAssetPath: 'asset/icon/icon_hilton.svg',
      pointLabel: '포인트',
      sortOrder: 20,
    ),
    PointBrand(
      id: 'hyatt',
      category: PointCategory.hotel,
      name: 'Hyatt',
      assetPath: 'asset/icon/points/hyatt.png',
      fallbackAssetPath: 'asset/icon/icon_hyatt.svg',
      pointLabel: '포인트',
      sortOrder: 30,
    ),
    PointBrand(
      id: 'ihg',
      category: PointCategory.hotel,
      name: 'IHG',
      assetPath: 'asset/icon/points/ihg.png',
      fallbackAssetPath: 'asset/icon/icon_ihg.svg',
      pointLabel: '포인트',
      sortOrder: 40,
    ),
    PointBrand(
      id: 'accor',
      category: PointCategory.hotel,
      name: 'Accor',
      assetPath: 'asset/icon/points/accor.png',
      fallbackAssetPath: 'asset/icon/icon_accor.webp',
      pointLabel: '포인트',
      sortOrder: 50,
    ),
    PointBrand(
      id: 'samsung_card',
      category: PointCategory.card,
      name: '삼성카드',
      assetPath: 'asset/icon/points/samsung_card.png',
      fallbackAssetPath: 'asset/img/samsung.png',
      pointLabel: '포인트',
      sortOrder: 10,
    ),
    PointBrand(
      id: 'hyundai_card',
      category: PointCategory.card,
      name: '현대카드',
      assetPath: 'asset/icon/points/hyundai_card.png',
      fallbackAssetPath: 'asset/img/hyundai.png',
      pointLabel: '포인트',
      sortOrder: 20,
    ),
    PointBrand(
      id: 'shinhan_card',
      category: PointCategory.card,
      name: '신한카드',
      assetPath: 'asset/icon/points/shinhan_card.png',
      fallbackAssetPath: 'asset/icon/card.png',
      pointLabel: '포인트',
      sortOrder: 30,
    ),
    PointBrand(
      id: 'kb_card',
      category: PointCategory.card,
      name: 'KB국민카드',
      assetPath: 'asset/icon/points/kb_card.png',
      fallbackAssetPath: 'asset/icon/card.png',
      pointLabel: '포인트',
      sortOrder: 40,
    ),
    PointBrand(
      id: 'lotte_card',
      category: PointCategory.card,
      name: '롯데카드',
      assetPath: 'asset/icon/points/lotte_card.png',
      fallbackAssetPath: 'asset/img/lotte.png',
      pointLabel: '포인트',
      sortOrder: 50,
    ),
  ];

  static List<PointBrand> byCategory(String category) {
    final items = brands.where((brand) => brand.category == category).toList();
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List<PointBrand>.unmodifiable(items);
  }

  static PointBrand? find(String brandId) {
    for (final brand in brands) {
      if (brand.id == brandId) return brand;
    }
    return null;
  }
}

class UserPointBalance {
  const UserPointBalance({
    required this.brandId,
    required this.category,
    required this.brandName,
    required this.pointLabel,
    required this.assetPath,
    this.fallbackAssetPath,
    required this.balance,
    required this.isRepresentative,
    required this.sortOrder,
  });

  final String brandId;
  final String category;
  final String brandName;
  final String pointLabel;
  final String assetPath;
  final String? fallbackAssetPath;
  final int balance;
  final bool isRepresentative;
  final int sortOrder;

  factory UserPointBalance.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final catalogBrand = PointBrandCatalog.find(doc.id);
    final category = _asString(data['category'],
        fallback: catalogBrand?.category ?? PointCategory.airline);
    final brandName =
        _asString(data['brandName'], fallback: catalogBrand?.name ?? doc.id);
    final pointLabel = _asString(data['pointLabel'],
        fallback: catalogBrand?.pointLabel ?? 'P');
    final assetPath = catalogBrand?.assetPath ??
        _asString(data['assetPath'], fallback: 'asset/img/app_icon.png');
    final fallbackAssetPath = catalogBrand?.fallbackAssetPath ??
        _asNullableString(data['fallbackAssetPath']);
    return UserPointBalance(
      brandId: doc.id,
      category: category,
      brandName: brandName,
      pointLabel: pointLabel,
      assetPath: assetPath,
      fallbackAssetPath: fallbackAssetPath,
      balance: _asInt(data['balance']),
      isRepresentative: data['isRepresentative'] == true,
      sortOrder: _asInt(data['sortOrder'], fallback: catalogBrand?.sortOrder),
    );
  }

  factory UserPointBalance.fromBrand(
    PointBrand brand, {
    int balance = 0,
    bool isRepresentative = false,
  }) {
    return UserPointBalance(
      brandId: brand.id,
      category: brand.category,
      brandName: brand.name,
      pointLabel: brand.pointLabel,
      assetPath: brand.assetPath,
      fallbackAssetPath: brand.fallbackAssetPath,
      balance: balance,
      isRepresentative: isRepresentative,
      sortOrder: brand.sortOrder,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'brandId': brandId,
      'brandName': brandName,
      'pointLabel': pointLabel,
      'assetPath': assetPath,
      if (fallbackAssetPath != null && fallbackAssetPath!.isNotEmpty)
        'fallbackAssetPath': fallbackAssetPath,
      'balance': balance,
      'isRepresentative': isRepresentative,
      'sortOrder': sortOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserPointBalance copyWith({
    int? balance,
    bool? isRepresentative,
  }) {
    return UserPointBalance(
      brandId: brandId,
      category: category,
      brandName: brandName,
      pointLabel: pointLabel,
      assetPath: assetPath,
      fallbackAssetPath: fallbackAssetPath,
      balance: balance ?? this.balance,
      isRepresentative: isRepresentative ?? this.isRepresentative,
      sortOrder: sortOrder,
    );
  }
}

Map<String, UserPointBalance> representativePointBalances(
  List<UserPointBalance> balances,
) {
  final byCategory = <String, List<UserPointBalance>>{};
  for (final balance in balances) {
    byCategory.putIfAbsent(balance.category, () => []).add(balance);
  }

  final representatives = <String, UserPointBalance>{};
  for (final category in PointCategory.values) {
    final items = byCategory[category] ?? const <UserPointBalance>[];
    if (items.isEmpty) continue;

    final sorted = [...items]..sort((a, b) {
        final sort = a.sortOrder.compareTo(b.sortOrder);
        if (sort != 0) return sort;
        return a.brandName.compareTo(b.brandName);
      });

    UserPointBalance? selected;
    for (final item in sorted) {
      if (item.isRepresentative) {
        selected = item;
        break;
      }
    }
    if (selected == null) {
      for (final item in sorted) {
        if (item.balance > 0) {
          selected = item;
          break;
        }
      }
    }
    if (selected != null) {
      representatives[category] = selected;
    }
  }
  return representatives;
}

String _asString(dynamic value, {String? fallback}) {
  if (value == null) return fallback ?? '';
  final text = value.toString().trim();
  if (text.isEmpty) return fallback ?? '';
  return text;
}

String? _asNullableString(dynamic value, {String? fallback}) {
  final text = _asString(value, fallback: fallback);
  return text.isEmpty ? null : text;
}

int _asInt(dynamic value, {int? fallback}) {
  if (value == null) return fallback ?? 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().replaceAll(RegExp(r'[^0-9-]'), '')) ??
      (fallback ?? 0);
}
