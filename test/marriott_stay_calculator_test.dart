import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_thief/models/marriott_stay_calculator.dart';

void main() {
  test('calculates the sample paid Marriott stay from the reference workbook',
      () {
    final result = MarriottStayCalculator.calculate(
      MarriottStayCalculationInput(
        checkIn: DateTime(2020, 6),
        checkOut: DateTime(2020, 6),
        roomRate: 99000,
        taxAmount: 9900,
        serviceCharge: 0,
        exchangeRateKrwPerUsd: 1200,
        eliteMultiplier: 1.5,
        welcomePoints: 500,
        promoPoints: 2000,
        pointValueKrw: 10,
      ),
    );

    expect(result.nights, 1);
    expect(result.totalAmount, 108900);
    expect(result.earnedPoints, 3738);
    expect(result.returnRate, 34.3);
  });

  test('calculates nights with same-day minimum of one night', () {
    expect(
      MarriottStayCalculator.calculateNights(
        DateTime(2026, 5, 19),
        DateTime(2026, 5, 19),
      ),
      1,
    );
    expect(
      MarriottStayCalculator.calculateNights(
        DateTime(2026, 5, 19),
        DateTime(2026, 5, 22),
      ),
      3,
    );
  });

  test('returns zero recovery rate when total amount is zero', () {
    expect(
      MarriottStayCalculator.calculateReturnRate(
        earnedPoints: 10000,
        pointValueKrw: 10,
        totalAmount: 0,
      ),
      0,
    );
  });
}
