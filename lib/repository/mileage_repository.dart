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
        mileage.businessSeat = mileage.businessSeat.replaceAll(RegExp('\\D'), "");
        mileage.firstSeat = mileage.firstSeat.replaceAll(RegExp('\\D'), "");
        mileages.add(mileage);
      }
    }
    print('Mileage Count: ${mileages.length}');
    return mileages;
  }
}