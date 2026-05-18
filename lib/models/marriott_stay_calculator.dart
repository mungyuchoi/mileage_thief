class MarriottStayCalculationInput {
  final DateTime checkIn;
  final DateTime checkOut;
  final int roomRate;
  final int taxAmount;
  final int serviceCharge;
  final double exchangeRateKrwPerUsd;
  final double eliteMultiplier;
  final int welcomePoints;
  final int promoPoints;
  final double pointValueKrw;
  final int? earnedPointsOverride;

  const MarriottStayCalculationInput({
    required this.checkIn,
    required this.checkOut,
    required this.roomRate,
    required this.taxAmount,
    required this.serviceCharge,
    required this.exchangeRateKrwPerUsd,
    required this.eliteMultiplier,
    required this.welcomePoints,
    required this.promoPoints,
    required this.pointValueKrw,
    this.earnedPointsOverride,
  });
}

class MarriottStayCalculationResult {
  final int nights;
  final int totalAmount;
  final int earnedPoints;
  final double returnRate;

  const MarriottStayCalculationResult({
    required this.nights,
    required this.totalAmount,
    required this.earnedPoints,
    required this.returnRate,
  });
}

class MarriottStayCalculator {
  const MarriottStayCalculator._();

  static MarriottStayCalculationResult calculate(
    MarriottStayCalculationInput input,
  ) {
    final totalAmount = calculateTotalAmount(
      roomRate: input.roomRate,
      taxAmount: input.taxAmount,
      serviceCharge: input.serviceCharge,
    );
    final earnedPoints = input.earnedPointsOverride ??
        calculateEarnedPoints(
          roomRate: input.roomRate,
          exchangeRateKrwPerUsd: input.exchangeRateKrwPerUsd,
          eliteMultiplier: input.eliteMultiplier,
          welcomePoints: input.welcomePoints,
          promoPoints: input.promoPoints,
        );

    return MarriottStayCalculationResult(
      nights: calculateNights(input.checkIn, input.checkOut),
      totalAmount: totalAmount,
      earnedPoints: earnedPoints,
      returnRate: calculateReturnRate(
        earnedPoints: earnedPoints,
        pointValueKrw: input.pointValueKrw,
        totalAmount: totalAmount,
      ),
    );
  }

  static int calculateNights(DateTime checkIn, DateTime checkOut) {
    final start = DateTime(checkIn.year, checkIn.month, checkIn.day);
    final end = DateTime(checkOut.year, checkOut.month, checkOut.day);
    final days = end.difference(start).inDays;
    return days <= 0 ? 1 : days;
  }

  static int calculateTotalAmount({
    required int roomRate,
    required int taxAmount,
    required int serviceCharge,
  }) {
    return roomRate + taxAmount + serviceCharge;
  }

  static int calculateEarnedPoints({
    required int roomRate,
    required double exchangeRateKrwPerUsd,
    required double eliteMultiplier,
    required int welcomePoints,
    required int promoPoints,
  }) {
    final basePoints = exchangeRateKrwPerUsd <= 0
        ? 0
        : ((roomRate / exchangeRateKrwPerUsd) * eliteMultiplier * 10).round();
    return basePoints + welcomePoints + promoPoints;
  }

  static double calculateReturnRate({
    required int earnedPoints,
    required double pointValueKrw,
    required int totalAmount,
  }) {
    if (totalAmount <= 0 || earnedPoints <= 0 || pointValueKrw <= 0) {
      return 0;
    }
    return _roundToOne(100 * earnedPoints * pointValueKrw / totalAmount);
  }

  static double _roundToOne(num value) => (value * 10).round() / 10;
}
