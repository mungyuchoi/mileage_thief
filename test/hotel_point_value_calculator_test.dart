import 'package:flutter_test/flutter_test.dart';
import 'package:mileage_thief/models/hotel_award_model.dart';

void main() {
  test('calculates KRW and USD point value from cash and points', () {
    expect(
      HotelPointValueCalculator.krwPerPoint(
        cashTotalKrw: 650000,
        pointsTotal: 50000,
      ),
      13.0,
    );
    expect(
      HotelPointValueCalculator.centsPerPoint(
        cashTotalUsd: 450,
        cashTotalKrw: null,
        pointsTotal: 60000,
      ),
      0.75,
    );
  });

  test('applies every fifth night free for Marriott and Hilton', () {
    expect(
      HotelPointValueCalculator.effectivePointsTotal(
        program: HotelAwardProgram.marriott,
        pointsPerNight: 30000,
        nights: 5,
      ),
      120000,
    );
    expect(
      HotelPointValueCalculator.effectivePointsTotal(
        program: HotelAwardProgram.hilton,
        pointsPerNight: 60000,
        nights: 10,
      ),
      480000,
    );
  });

  test('maps Firestore-like award snapshot data with calculated value', () {
    final snapshot = HotelAwardSnapshot.fromMap('sample', {
      'propertyId': 'hotel_1',
      'programId': 'hyatt',
      'hotelName': 'Park Hyatt Seoul',
      'checkInDate': '2026-06-18',
      'checkOutDate': '2026-06-20',
      'nights': 2,
      'pointsTotal': 50000,
      'cashTotalKrw': 900000,
      'fetchedAt': '2026-05-19T00:00:00Z',
    });

    expect(snapshot.program, HotelAwardProgram.hyatt);
    expect(snapshot.checkInKey, '2026-06-18');
    expect(snapshot.pointsPerNight, 25000);
    expect(snapshot.krwPerPoint, 18.0);
    expect(snapshot.centsPerPoint, 1.33);
  });
}
