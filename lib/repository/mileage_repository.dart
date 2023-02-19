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
        .once(DatabaseEventType.value);
    for (var snap in event.snapshot.children) {
      if (snap.value != null) {
        Map<dynamic, dynamic> map = snap.value as Map<dynamic, dynamic>;
        Mileage mileage = Mileage.fromJson(map);
        mileages.add(mileage);
      }
    }
    print('Mileage Count: ' + mileages.length.toString());
    return mileages;
  }
}
