import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mileage_thief/widgets/giftcard_daily_ledger.dart';

void main() {
  testWidgets('daily ledger displays giftcard denomination for buy entries',
      (tester) async {
    final entry = GiftcardLedgerEntry(
      type: GiftcardLedgerEntryType.buy,
      id: 'lot_1',
      giftcardId: 'hyundai',
      giftcardName: '현대상품권',
      faceValue: 500000,
      dateTime: DateTime(2026, 6, 7, 8, 30),
      qty: 1,
      unitPrice: 485000,
      amount: 485000,
      profit: 0,
      discount: 3,
      branchName: null,
      cardName: '테스트카드',
      payType: '신용',
      whereToBuyName: '테스트구매처',
      memo: null,
      deletable: true,
      raw: const {'status': 'open'},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GiftcardDailyLedger(
            groups: [
              GiftcardLedgerDayGroup(
                day: DateTime(2026, 6, 7),
                entries: [entry],
                sumBuyAmount: 485000,
                sumSellAmount: 0,
                sumProfit: 0,
              ),
            ],
            wonFormat: NumberFormat('#,###'),
            dayFormat: DateFormat('yyyy-MM-dd'),
            onEdit: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('1장 · 현대상품권 50만원권'), findsOneWidget);
    expect(find.text('권종 50만원권'), findsOneWidget);
  });
}
