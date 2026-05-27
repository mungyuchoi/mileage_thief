import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_thief/models/user_point_model.dart';

void main() {
  test('representativePointBalances prefers explicit representatives', () {
    final balances = [
      UserPointBalance.fromBrand(
        PointBrandCatalog.find('korean_air')!,
        balance: 1000,
      ),
      UserPointBalance.fromBrand(
        PointBrandCatalog.find('asiana')!,
        balance: 2000,
        isRepresentative: true,
      ),
    ];

    final representatives = representativePointBalances(balances);

    expect(representatives[PointCategory.airline]?.brandId, 'asiana');
  });

  test('representativePointBalances falls back to first positive balance', () {
    final balances = [
      UserPointBalance.fromBrand(PointBrandCatalog.find('marriott')!),
      UserPointBalance.fromBrand(
        PointBrandCatalog.find('hilton')!,
        balance: 5000,
      ),
    ];

    final representatives = representativePointBalances(balances);

    expect(representatives[PointCategory.hotel]?.brandId, 'hilton');
  });
}
