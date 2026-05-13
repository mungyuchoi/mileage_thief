import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_thief/models/giftcard_settlement_calculator.dart';

void main() {
  test('summarize calculates totals across multiple line items', () {
    final summary = GiftcardSettlementCalculator.summarize(
      lines: const [
        GiftcardSettlementLineInput(
          giftcardId: 'lotte',
          giftcardName: '롯데상품권',
          faceValue: 100000,
          qty: 3,
          sellUnit: 97000,
        ),
        GiftcardSettlementLineInput(
          giftcardId: 'shinsegae',
          giftcardName: '신세계상품권',
          faceValue: 50000,
          qty: 4,
          sellUnit: 48500,
        ),
      ],
    );

    expect(summary.expectedTotal, 485000);
    expect(summary.totalQuantity, 7);
    expect(summary.subtotalByGiftcard['롯데상품권'], 291000);
    expect(summary.subtotalByGiftcard['신세계상품권'], 194000);
  });

  test('sellRateFromUnit calculates a sell rate from unit price', () {
    final rate = GiftcardSettlementCalculator.sellRateFromUnit(
      faceValue: 100000,
      sellUnit: 96700,
    );

    expect(rate, closeTo(3.3, 0.0001));
  });

  test('sellUnitFromRate calculates unit price from sell rate', () {
    final unit = GiftcardSettlementCalculator.sellUnitFromRate(
      faceValue: 50000,
      sellRate: 3.25,
    );

    expect(unit, 48375);
  });

  test('summarize calculates actual deposit difference', () {
    final summary = GiftcardSettlementCalculator.summarize(
      lines: const [
        GiftcardSettlementLineInput(
          giftcardId: 'lotte',
          giftcardName: '롯데상품권',
          faceValue: 100000,
          qty: 5,
          sellUnit: 97000,
        ),
      ],
      actualDepositTotal: 484000,
    );

    expect(summary.expectedTotal, 485000);
    expect(summary.difference, -1000);
  });
}
