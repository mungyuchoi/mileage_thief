import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_point_model.dart';

class UserPointService {
  UserPointService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _balancesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('pointBalances');
  }

  Stream<List<UserPointBalance>> watchBalances(String uid) {
    return _balancesRef(uid).snapshots().map((snapshot) {
      final balances = snapshot.docs
          .map(UserPointBalance.fromFirestore)
          .toList(growable: false);
      return _sortBalances(balances);
    });
  }

  Future<List<UserPointBalance>> loadBalances(String uid) async {
    final snapshot = await _balancesRef(uid).get();
    final balances = snapshot.docs
        .map(UserPointBalance.fromFirestore)
        .toList(growable: false);
    return _sortBalances(balances);
  }

  Future<void> saveBalance({
    required String uid,
    required UserPointBalance balance,
  }) {
    return _balancesRef(uid).doc(balance.brandId).set(
          balance.toFirestore(),
          SetOptions(merge: true),
        );
  }

  Future<void> saveAllCatalogBalances({
    required String uid,
    required Map<String, int> balancesByBrandId,
    required Map<String, String?> representativesByCategory,
  }) async {
    final batch = _firestore.batch();

    for (final category in PointCategory.values) {
      final brands = PointBrandCatalog.byCategory(category);
      final representativeBrandId = representativesByCategory[category] ??
          _firstPositiveBrandId(brands, balancesByBrandId);

      for (final brand in brands) {
        final balance = UserPointBalance.fromBrand(
          brand,
          balance: balancesByBrandId[brand.id] ?? 0,
          isRepresentative: brand.id == representativeBrandId,
        );
        batch.set(
          _balancesRef(uid).doc(brand.id),
          balance.toFirestore(),
          SetOptions(merge: true),
        );
      }
    }

    await batch.commit();
  }

  Future<void> saveCategoryBalances({
    required String uid,
    required String category,
    required Map<String, int> balancesByBrandId,
    String? representativeBrandId,
  }) async {
    final brands = PointBrandCatalog.byCategory(category);
    final selectedBrandId = representativeBrandId ??
        _firstPositiveBrandId(brands, balancesByBrandId);
    final batch = _firestore.batch();

    for (final brand in brands) {
      final balance = UserPointBalance.fromBrand(
        brand,
        balance: balancesByBrandId[brand.id] ?? 0,
        isRepresentative: brand.id == selectedBrandId,
      );
      batch.set(
        _balancesRef(uid).doc(brand.id),
        balance.toFirestore(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> setRepresentative({
    required String uid,
    required String category,
    required String brandId,
  }) async {
    final snapshot =
        await _balancesRef(uid).where('category', isEqualTo: category).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.set(
        doc.reference,
        {
          'isRepresentative': doc.id == brandId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    final brand = PointBrandCatalog.find(brandId);
    if (brand != null) {
      batch.set(
        _balancesRef(uid).doc(brand.id),
        UserPointBalance.fromBrand(brand, isRepresentative: true).toFirestore(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static List<UserPointBalance> _sortBalances(List<UserPointBalance> balances) {
    final sorted = [...balances];
    sorted.sort((a, b) {
      final category = PointCategory.values
          .indexOf(a.category)
          .compareTo(PointCategory.values.indexOf(b.category));
      if (category != 0) return category;
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.brandName.compareTo(b.brandName);
    });
    return List<UserPointBalance>.unmodifiable(sorted);
  }

  static String? _firstPositiveBrandId(
    List<PointBrand> brands,
    Map<String, int> balancesByBrandId,
  ) {
    for (final brand in brands) {
      if ((balancesByBrandId[brand.id] ?? 0) > 0) return brand.id;
    }
    return null;
  }
}
