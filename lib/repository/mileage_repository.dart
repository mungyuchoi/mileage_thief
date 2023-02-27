import 'package:mileage_thief/model/search_detail_model.dart';
import 'package:firebase_database/firebase_database.dart';
import '../model/search_model.dart';

class MileageRepository {
  static Future<List<Mileage>> getMileages(SearchModel searchModel) async {
    List<Mileage> mileages = [];
    String departureAirport = searchModel.departureAirport.toString();
    departureAirport =
        departureAirport.substring(departureAirport.indexOf('-') + 1);
    String arrivalAirport = searchModel.arrivalAirport.toString();
    arrivalAirport = arrivalAirport.substring(arrivalAirport.indexOf('-') + 1);
    var event = await FirebaseDatabase.instance
        .ref('$departureAirport-$arrivalAirport')
        .orderByChild('departureDate')
        .once(DatabaseEventType.value);
    for (var snap in event.snapshot.children) {
      if (snap.value != null) {
        Map<dynamic, dynamic> map = snap.value as Map<dynamic, dynamic>;
        Mileage mileage = Mileage.fromJson(map);
        // String departureDate = mileage.departureDate;
        // departureDate = departureDate.substring(0, 4) +
        //     "." +
        //     departureDate.substring(4, 6) +
        //     '.' +
        //     departureDate.substring(6, 8);
        // mileage.departureDate = departureDate;
        mileage.economySeat = mileage.economySeat.replaceAll(RegExp('\\D'), "");
        mileage.businessSeat =
            mileage.businessSeat.replaceAll(RegExp('\\D'), "");
        mileage.firstSeat = mileage.firstSeat.replaceAll(RegExp('\\D'), "");
        mileages.add(mileage);
      }
    }
    print('Mileage Count: ${mileages.length}');
    return mileages;
  }

  static Future<List<RoundMileage>> getRoundMileages(
      SearchModel searchModel) async {
    List<Mileage> departureMileages = [];
    List<Mileage> arrivalMileages = [];
    List<RoundMileage> roundMileages = [];
    String departureAirport = searchModel.departureAirport.toString();
    departureAirport =
        departureAirport.substring(departureAirport.indexOf('-') + 1);
    String arrivalAirport = searchModel.arrivalAirport.toString();
    arrivalAirport = arrivalAirport.substring(arrivalAirport.indexOf('-') + 1);
    var event = await FirebaseDatabase.instance
        .ref('$departureAirport-$arrivalAirport')
        .orderByChild('departureDate')
        .once(DatabaseEventType.value);
    for (var snap in event.snapshot.children) {
      if (snap.value != null) {
        Map<dynamic, dynamic> map = snap.value as Map<dynamic, dynamic>;
        Mileage mileage = Mileage.fromJson(map);
        // String departureDate = mileage.departureDate;
        // departureDate = departureDate.substring(0, 4) +
        //     "." +
        //     departureDate.substring(4, 6) +
        //     '.' +
        //     departureDate.substring(6, 8);
        // mileage.departureDate = departureDate;
        mileage.economySeat = mileage.economySeat.replaceAll(RegExp('\\D'), "");
        mileage.businessSeat =
            mileage.businessSeat.replaceAll(RegExp('\\D'), "");
        mileage.firstSeat = mileage.firstSeat.replaceAll(RegExp('\\D'), "");
        departureMileages.add(mileage);
      }
    }
    print('Mileage Count: ${departureMileages.length}');
    event = await FirebaseDatabase.instance
        .ref('$arrivalAirport-$departureAirport')
        .orderByChild('departureDate')
        .once(DatabaseEventType.value);
    for (var snap in event.snapshot.children) {
      if (snap.value != null) {
        Map<dynamic, dynamic> map = snap.value as Map<dynamic, dynamic>;
        Mileage mileage = Mileage.fromJson(map);
        // String departureDate = mileage.departureDate;
        // departureDate = departureDate.substring(0, 4) +
        //     "." +ㅊ
        //     departureDate.substring(4, 6) +
        //     '.' +
        //     departureDate.substring(6, 8);
        // mileage.departureDate = departureDate;
        mileage.economySeat = mileage.economySeat.replaceAll(RegExp('\\D'), "");
        mileage.businessSeat =
            mileage.businessSeat.replaceAll(RegExp('\\D'), "");
        mileage.firstSeat = mileage.firstSeat.replaceAll(RegExp('\\D'), "");
        arrivalMileages.add(mileage);
      }
    }
    print('Mileage Count: ${arrivalMileages.length}');

    // arrivalMileages.departureDate > Datetime으로 변환
    // departureMileages.departureDate > Datetime으로 변환
    // 이중 포문을 통해 1 - 2가 SearchViewModel.searchDate의 박 앞에만 파싱 + 1인경우만 담음
    for (var arrivalElement in arrivalMileages) {
      int year = int.parse(arrivalElement.departureDate.substring(0, 4)) ?? 0;
      int month = int.parse(arrivalElement.departureDate.substring(4, 6)) ?? 0;
      int day = int.parse(arrivalElement.departureDate.substring(6, 8)) ?? 0;
      var departureDateTime = DateTime(year, month, day);

      for (var departureElement in departureMileages) {
        year = int.parse(departureElement.departureDate.substring(0, 4)) ?? 0;
        month = int.parse(departureElement.departureDate.substring(4, 6)) ?? 0;
        day = int.parse(departureElement.departureDate.substring(6, 8)) ?? 0;
        var arrivalDateTime = DateTime(year, month, day);
        Duration difference = arrivalDateTime.difference(departureDateTime);
        String days = searchModel.searchDate
                ?.substring(0, searchModel.searchDate?.indexOf('박'))
                .trim() ??
            '0';
        int numberOfDays = int.tryParse(days) ?? 6;
        if (numberOfDays == 0) numberOfDays = 6;
        if (difference.inDays.abs() == numberOfDays + 1) {
          roundMileages.add(RoundMileage(
              departureMileage: departureElement,
              arrivalMileage: arrivalElement));
        }
      }
    }
    return roundMileages;
  }
}
