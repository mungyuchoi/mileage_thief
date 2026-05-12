import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_thief/model/giftcard_info_data.dart';
import 'package:mileage_thief/model/giftcard_period.dart';
import 'package:mileage_thief/services/giftcard_service.dart';

void main() {
  test('giftcard info cache codec preserves timestamp-backed data', () {
    final timestamp = Timestamp.fromDate(DateTime(2026, 5, 12, 9, 30));
    final data = GiftcardInfoData(
      lots: [
        {
          'id': 'lot_1',
          'giftcardId': 'lotte',
          'buyDate': timestamp,
          'buyUnit': 97000,
          'qty': 2,
        }
      ],
      sales: [
        {
          'id': 'sale_1',
          'lotId': 'lot_1',
          'sellDate': timestamp,
          'sellTotal': 196000,
        }
      ],
      cards: {
        'card_1': {'name': 'Test Card', 'credit': 1000, 'check': 1200}
      },
      giftcardNames: {'lotte': '롯데상품권'},
      branchNames: {'branch_1': '테스트 지점'},
      whereToBuyNames: {'store_1': '테스트 구매처'},
    );

    final payload = GiftcardService.debugEncodeInfoDataCachePayload(
      data,
      fetchedAt: DateTime(2026, 5, 12),
    );
    final decoded = GiftcardService.debugDecodeInfoDataCachePayload(
      payload,
      now: DateTime(2026, 5, 12, 1),
    );

    expect(decoded, isNotNull);
    expect(decoded!.lots.first['buyDate'], isA<Timestamp>());
    expect(
      (decoded.lots.first['buyDate'] as Timestamp).millisecondsSinceEpoch,
      timestamp.millisecondsSinceEpoch,
    );
    expect(decoded.sales.first['sellDate'], isA<Timestamp>());
    expect(decoded.giftcardNames['lotte'], '롯데상품권');
    expect(decoded.cards['card_1']?['credit'], 1000);
  });

  test('giftcard info cache rejects old or incompatible payloads', () {
    const data = GiftcardInfoData(
      lots: [],
      sales: [],
      cards: {},
      giftcardNames: {},
      branchNames: {},
      whereToBuyNames: {},
    );
    final oldPayload = GiftcardService.debugEncodeInfoDataCachePayload(
      data,
      fetchedAt: DateTime(2026, 5, 10),
    );

    expect(
      GiftcardService.debugDecodeInfoDataCachePayload(
        oldPayload,
        now: DateTime(2026, 5, 12),
      ),
      isNull,
    );
    expect(
      GiftcardService.debugDecodeInfoDataCachePayload(
        {'schemaVersion': 999, 'fetchedAtMillis': 0, 'data': {}},
      ),
      isNull,
    );
  });

  test('giftcard info cache key is scoped by user and period', () {
    final monthKey = GiftcardService.debugInfoCacheKey(
      uid: 'uid_a',
      periodType: DashboardPeriodType.month,
      selectedMonth: DateTime(2026, 5),
      selectedYear: 2026,
    );
    final otherUserKey = GiftcardService.debugInfoCacheKey(
      uid: 'uid_b',
      periodType: DashboardPeriodType.month,
      selectedMonth: DateTime(2026, 5),
      selectedYear: 2026,
    );
    final otherPeriodKey = GiftcardService.debugInfoCacheKey(
      uid: 'uid_a',
      periodType: DashboardPeriodType.year,
      selectedMonth: DateTime(2026, 5),
      selectedYear: 2026,
    );

    expect(monthKey, isNot(otherUserKey));
    expect(monthKey, isNot(otherPeriodKey));
  });
}
