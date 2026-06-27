class GiftcardSettlementLineInput {
  final String? lotId;
  final String giftcardId;
  final String giftcardName;
  final int faceValue;
  final int qty;
  final int sellUnit;
  final String memo;

  const GiftcardSettlementLineInput({
    this.lotId,
    required this.giftcardId,
    required this.giftcardName,
    required this.faceValue,
    required this.qty,
    required this.sellUnit,
    this.memo = '',
  });

  double get sellRate => GiftcardSettlementCalculator.sellRateFromUnit(
        faceValue: faceValue,
        sellUnit: sellUnit,
      );

  int get lineTotal => GiftcardSettlementCalculator.lineTotal(
        qty: qty,
        sellUnit: sellUnit,
      );
}

class GiftcardSettlementSummary {
  final int expectedTotal;
  final int totalQuantity;
  final int difference;
  final Map<String, int> subtotalByGiftcard;

  const GiftcardSettlementSummary({
    required this.expectedTotal,
    required this.totalQuantity,
    required this.difference,
    required this.subtotalByGiftcard,
  });
}

class GiftcardSettlementCalculator {
  const GiftcardSettlementCalculator._();

  static int lineTotal({
    required int qty,
    required int sellUnit,
  }) {
    if (qty <= 0 || sellUnit <= 0) return 0;
    return qty * sellUnit;
  }

  static double sellRateFromUnit({
    required int faceValue,
    required int sellUnit,
  }) {
    if (faceValue <= 0 || sellUnit <= 0) return 0;
    return 100 * (1 - sellUnit / faceValue);
  }

  static int sellUnitFromRate({
    required int faceValue,
    required double sellRate,
  }) {
    if (faceValue <= 0) return 0;
    return (faceValue * (1 - sellRate / 100)).round();
  }

  static int difference({
    required int actualDepositTotal,
    required int expectedTotal,
  }) {
    return actualDepositTotal - expectedTotal;
  }

  static GiftcardSettlementSummary summarize({
    required List<GiftcardSettlementLineInput> lines,
    int? actualDepositTotal,
  }) {
    int expectedTotal = 0;
    int totalQuantity = 0;
    final subtotalByGiftcard = <String, int>{};

    for (final line in lines) {
      final lineTotal = GiftcardSettlementCalculator.lineTotal(
        qty: line.qty,
        sellUnit: line.sellUnit,
      );
      expectedTotal += lineTotal;
      totalQuantity += line.qty > 0 ? line.qty : 0;
      final key =
          line.giftcardName.isEmpty ? line.giftcardId : line.giftcardName;
      subtotalByGiftcard[key] = (subtotalByGiftcard[key] ?? 0) + lineTotal;
    }

    return GiftcardSettlementSummary(
      expectedTotal: expectedTotal,
      totalQuantity: totalQuantity,
      difference: actualDepositTotal == null
          ? 0
          : GiftcardSettlementCalculator.difference(
              actualDepositTotal: actualDepositTotal,
              expectedTotal: expectedTotal,
            ),
      subtotalByGiftcard: Map<String, int>.unmodifiable(subtotalByGiftcard),
    );
  }
}
