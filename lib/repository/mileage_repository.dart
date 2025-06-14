import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mileage_thief/model/search_detail_model.dart';
import 'package:firebase_database/firebase_database.dart';
import '../model/search_model.dart';
import '../model/search_detail_model_v2.dart';

class MileageRepository {
  static Future<List<Mileage>> getMileages(SearchModel searchModel) async {
    List<Mileage> mileages = [];
    String departureAirport = searchModel.departureAirport.toString();
    departureAirport =
        departureAirport.substring(departureAirport.indexOf('-') + 1);
    String arrivalAirport = searchModel.arrivalAirport.toString();
    arrivalAirport = arrivalAirport.substring(arrivalAirport.indexOf('-') + 1);
    var event = await FirebaseDatabase.instance
        .ref('ASIANA')
        .child('$departureAirport-$arrivalAirport')
        .orderByChild('departureDate')
        .once(DatabaseEventType.value);
    for (var snap in event.snapshot.children) {
      if (snap.value != null) {
        Map<dynamic, dynamic> map = snap.value as Map<dynamic, dynamic>;
        Mileage mileage = Mileage.fromJson(map);
        String departureDate =
            DateFormat('yyyyMMddHHmm').format(DateTime.now());
        if (int.parse(departureDate) > int.parse(mileage.departureDate)) {
          continue;
        }
        departureDate = DateFormat('yyyyMMddHHmm').format(DateTime.now().add(const Duration(days: 361)));
        if (int.parse(departureDate) < int.parse(mileage.departureDate)){
          continue;
        }
        String startDateTime = "${searchModel.startYear}${searchModel.startMonth}000000";
        String endDateTime = "${searchModel.endYear}${searchModel.endMonth}312359";
        if (int.parse(startDateTime) > int.parse(mileage.departureDate)) {
          continue;
        }
        if (int.parse(endDateTime) < int.parse(mileage.departureDate)) {
          continue;
        }
        mileage.economySeat = mileage.economySeat.replaceAll(RegExp('\\D'), "");
        mileage.businessSeat =
            mileage.businessSeat.replaceAll(RegExp('\\D'), "");
        mileage.firstSeat = mileage.firstSeat.replaceAll(RegExp('\\D'), "");

        switch (searchModel.seatClass) {
          case "이코노미":
            if (mileage.economySeat != "0") {
              mileage.economySeat = "N석";
              mileages.add(mileage);
            }
            break;
          case "비즈니스":
            if (mileage.businessSeat != "0") {
              mileage.businessSeat = "+1석";
              mileages.add(mileage);
            }
            break;
          default: //"이코노미+비즈니스"
            if (mileage.economySeat != "0") {
              mileage.economySeat = "N석";
            }
            if (mileage.businessSeat != "0") {
              mileage.businessSeat = "+1석";
            }
            mileages.add(mileage);
            break;
        }
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
        .ref('ASIANA')
        .child('$departureAirport-$arrivalAirport')
        .orderByChild('departureDate')
        .once(DatabaseEventType.value);
    for (var snap in event.snapshot.children) {
      if (snap.value != null) {
        Map<dynamic, dynamic> map = snap.value as Map<dynamic, dynamic>;
        Mileage mileage = Mileage.fromJson(map);
        String departureDate =
        DateFormat('yyyyMMddHHmm').format(DateTime.now());
        if (int.parse(departureDate) > int.parse(mileage.departureDate)) {
          continue;
        }
        departureDate = DateFormat('yyyyMMddHHmm').format(DateTime.now().add(const Duration(days: 361)));
        if (int.parse(departureDate) < int.parse(mileage.departureDate)){
          continue;
        }
        String startDateTime = "${searchModel.startYear}${searchModel.startMonth}000000";
        String endDateTime = "${searchModel.endYear}${searchModel.endMonth}312359";
        if (int.parse(startDateTime) > int.parse(mileage.departureDate)) {
          continue;
        }
        if (int.parse(endDateTime) < int.parse(mileage.departureDate)) {
          continue;
        }
        mileage.economySeat = mileage.economySeat.replaceAll(RegExp('\\D'), "");
        mileage.businessSeat =
            mileage.businessSeat.replaceAll(RegExp('\\D'), "");
        mileage.firstSeat = mileage.firstSeat.replaceAll(RegExp('\\D'), "");
        switch (searchModel.seatClass) {
          case "이코노미":
            if (mileage.economySeat != "0") {
              mileage.economySeat = "N석";
              departureMileages.add(mileage);
            }
            break;
          case "비즈니스":
            if (mileage.businessSeat != "0") {
              mileage.businessSeat = "+1석";
              departureMileages.add(mileage);
            }
            break;
          default: //"이코노미+비즈니스"
            if (mileage.economySeat != "0") {
              mileage.economySeat = "N석";
            }
            if (mileage.businessSeat != "0") {
              mileage.businessSeat = "+1석";
            }
            departureMileages.add(mileage);
            break;
        }
      }
    }
    print('Mileage Count: ${departureMileages.length}');
    event = await FirebaseDatabase.instance
        .ref('ASIANA')
        .child('$arrivalAirport-$departureAirport')
        .orderByChild('departureDate')
        .once(DatabaseEventType.value);
    for (var snap in event.snapshot.children) {
      if (snap.value != null) {
        Map<dynamic, dynamic> map = snap.value as Map<dynamic, dynamic>;
        Mileage mileage = Mileage.fromJson(map);
        mileage.economySeat = mileage.economySeat.replaceAll(RegExp('\\D'), "");
        mileage.businessSeat =
            mileage.businessSeat.replaceAll(RegExp('\\D'), "");
        mileage.firstSeat = mileage.firstSeat.replaceAll(RegExp('\\D'), "");
        switch (searchModel.seatClass) {
          case "이코노미":
            if (mileage.economySeat != "0") {
              mileage.economySeat = "N석";
              arrivalMileages.add(mileage);
            }
            break;
          case "비즈니스":
            if (mileage.businessSeat != "0") {
              mileage.businessSeat = "+1석";
              arrivalMileages.add(mileage);
            }
            break;
          default: //"이코노미+비즈니스"
            if (mileage.economySeat != "0") {
              mileage.economySeat = "N석";
            }
            if (mileage.businessSeat != "0") {
              mileage.businessSeat = "+1석";
            }
            arrivalMileages.add(mileage);
            break;
        }
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
      var arrivalDateTime = DateTime(year, month, day);

      for (var departureElement in departureMileages) {
        year = int.parse(departureElement.departureDate.substring(0, 4)) ?? 0;
        month = int.parse(departureElement.departureDate.substring(4, 6)) ?? 0;
        day = int.parse(departureElement.departureDate.substring(6, 8)) ?? 0;
        var departureDateTime = DateTime(year, month, day);
        Duration difference = arrivalDateTime.difference(departureDateTime);
        String days = '0';
        if (searchModel.searchDate == "전체") {
          days = '0';
        } else {
          days = searchModel.searchDate
                  ?.substring(0, searchModel.searchDate?.indexOf('박'))
                  .trim() ??
              '0';
        }
        int numberOfDays = int.tryParse(days) ?? 6;
        if (numberOfDays == 0) numberOfDays = 6;
        if (difference.inDays == numberOfDays + 1) {
          roundMileages.add(RoundMileage(
              departureMileage: departureElement,
              arrivalMileage: arrivalElement));
        }
      }
    }
    return roundMileages;
  }

  static Future<List<Mileage>> getDanMileages(SearchModel searchModel) async {
    List<Mileage> mileages = [];
    String departureAirport = searchModel.departureAirport.toString();
    departureAirport =
        departureAirport.substring(departureAirport.indexOf('-') + 1);
    String arrivalAirport = searchModel.arrivalAirport.toString();
    arrivalAirport = arrivalAirport.substring(arrivalAirport.indexOf('-') + 1);
    var event = await FirebaseDatabase.instance
        .ref('DAN')
        .child('$departureAirport-$arrivalAirport')
        .orderByChild('departureDate')
        .once(DatabaseEventType.value);
    for (var snap in event.snapshot.children) {
      if (snap.value != null) {
        Map<dynamic, dynamic> map = snap.value as Map<dynamic, dynamic>;
        Mileage mileage = Mileage.fromJson(map);
        String departureDate =
        DateFormat('yyyyMMddHHmm').format(DateTime.now());
        if (int.parse(departureDate) > int.parse(mileage.departureDate)) {
          continue;
        }
        departureDate = DateFormat('yyyyMMddHHmm')
            .format(DateTime.now().add(const Duration(days: 361)));
        if (int.parse(departureDate) < int.parse(mileage.departureDate)) {
          continue;
        }
        String startDateTime = "${searchModel.startYear}${searchModel.startMonth}000000";
        String endDateTime = "${searchModel.endYear}${searchModel.endMonth}312359";
        if (int.parse(startDateTime) > int.parse(mileage.departureDate)) {
          continue;
        }
        if (int.parse(endDateTime) < int.parse(mileage.departureDate)) {
          continue;
        }

        mileage.economySeat = mileage.economySeat.replaceAll(RegExp('\\D'), "");
        mileage.businessSeat =
            mileage.businessSeat.replaceAll(RegExp('\\D'), "");
        mileage.firstSeat = mileage.firstSeat.replaceAll(RegExp('\\D'), "");

        switch (searchModel.seatClass) {
          case "이코노미":
            if (mileage.economySeat != "0") {
              mileage.economySeat = "N석";
              mileages.add(mileage);
            }
            break;
          case "비즈니스":
            if (mileage.businessSeat != "0") {
              mileage.businessSeat = "+1석";
              mileages.add(mileage);
            }
            break;
          case "퍼스트":
            if (mileage.firstSeat != "0") {
              mileage.firstSeat = "+1석";
              mileages.add(mileage);
            }
            break;
          case "이코노미+비즈니스": //"이코노미+비즈니스"
            if (mileage.economySeat == "0" && mileage.businessSeat == "0") {
              break;
            }
            if (mileage.economySeat != "0") {
              mileage.economySeat = "N석";
            }
            if (mileage.businessSeat != "0") {
              mileage.businessSeat = "+1석";
            }
            mileages.add(mileage);
            break;
        }
      }
    }
    print('Mileage Count: ${mileages.length}');
    return mileages;
  }

  static Future<List<RoundMileage>> getRoundDanMileages(
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
        .ref('DAN')
        .child('$departureAirport-$arrivalAirport')
        .orderByChild('departureDate')
        .once(DatabaseEventType.value);
    for (var snap in event.snapshot.children) {
      if (snap.value != null) {
        Map<dynamic, dynamic> map = snap.value as Map<dynamic, dynamic>;
        Mileage mileage = Mileage.fromJson(map);
        String departureDate =
        DateFormat('yyyyMMddHHmm').format(DateTime.now());
        if (int.parse(departureDate) > int.parse(mileage.departureDate)) {
          continue;
        }
        departureDate = DateFormat('yyyyMMddHHmm').format(DateTime.now().add(const Duration(days: 361)));
        if (int.parse(departureDate) < int.parse(mileage.departureDate)){
          continue;
        }
        String startDateTime = "${searchModel.startYear}${searchModel.startMonth}000000";
        String endDateTime = "${searchModel.endYear}${searchModel.endMonth}312359";
        if (int.parse(startDateTime) > int.parse(mileage.departureDate)) {
          continue;
        }
        if (int.parse(endDateTime) < int.parse(mileage.departureDate)) {
          continue;
        }
        mileage.economySeat = mileage.economySeat.replaceAll(RegExp('\\D'), "");
        mileage.businessSeat =
            mileage.businessSeat.replaceAll(RegExp('\\D'), "");
        mileage.firstSeat = mileage.firstSeat.replaceAll(RegExp('\\D'), "");
        switch (searchModel.seatClass) {
          case "이코노미":
            if (mileage.economySeat != "0") {
              mileage.economySeat = "N석";
              departureMileages.add(mileage);
            }
            break;
          case "비즈니스":
            if (mileage.businessSeat != "0") {
              mileage.businessSeat = "+1석";
              departureMileages.add(mileage);
            }
            break;
          case "퍼스트":
            if (mileage.firstSeat != "0") {
              mileage.firstSeat = "+1석";
              departureMileages.add(mileage);
            }
            break;
          case "이코노미+비즈니스": //"이코노미+비즈니스"
            if (mileage.economySeat == "0" && mileage.businessSeat == "0") {
              break;
            }
            if (mileage.economySeat != "0") {
              mileage.economySeat = "N석";
            }
            if (mileage.businessSeat != "0") {
              mileage.businessSeat = "+1석";
            }
            departureMileages.add(mileage);
            break;
        }
      }
    }
    print('Mileage Count: ${departureMileages.length}');
    event = await FirebaseDatabase.instance
        .ref('DAN')
        .child('$arrivalAirport-$departureAirport')
        .orderByChild('departureDate')
        .once(DatabaseEventType.value);
    for (var snap in event.snapshot.children) {
      if (snap.value != null) {
        Map<dynamic, dynamic> map = snap.value as Map<dynamic, dynamic>;
        Mileage mileage = Mileage.fromJson(map);
        mileage.economySeat = mileage.economySeat.replaceAll(RegExp('\\D'), "");
        mileage.businessSeat =
            mileage.businessSeat.replaceAll(RegExp('\\D'), "");
        mileage.firstSeat = mileage.firstSeat.replaceAll(RegExp('\\D'), "");
        switch (searchModel.seatClass) {
          case "이코노미":
            if (mileage.economySeat != "0") {
              mileage.economySeat = "N석";
              arrivalMileages.add(mileage);
            }
            break;
          case "비즈니스":
            if (mileage.businessSeat != "0") {
              mileage.businessSeat = "+1석";
              arrivalMileages.add(mileage);
            }
            break;
          case "퍼스트":
            if (mileage.firstSeat != "0") {
              mileage.firstSeat = "+1석";
              arrivalMileages.add(mileage);
            }
            break;
          case "이코노미+비즈니스": //"이코노미+비즈니스"
            if (mileage.economySeat == "0" && mileage.businessSeat == "0") {
              break;
            }
            if (mileage.economySeat != "0") {
              mileage.economySeat = "N석";
            }
            if (mileage.businessSeat != "0") {
              mileage.businessSeat = "+1석";
            }
            arrivalMileages.add(mileage);
            break;
        }
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
      var arrivalDateTime = DateTime(year, month, day);

      for (var departureElement in departureMileages) {
        year = int.parse(departureElement.departureDate.substring(0, 4)) ?? 0;
        month = int.parse(departureElement.departureDate.substring(4, 6)) ?? 0;
        day = int.parse(departureElement.departureDate.substring(6, 8)) ?? 0;
        var departureDateTime = DateTime(year, month, day);
        Duration difference = arrivalDateTime.difference(departureDateTime);
        String days = '0';
        if (searchModel.searchDate == "전체") {
          days = '0';
        } else {
          days = searchModel.searchDate
              ?.substring(0, searchModel.searchDate?.indexOf('박'))
              .trim() ??
              '0';
        }
        int numberOfDays = int.tryParse(days) ?? 6;
        if (numberOfDays == 0) numberOfDays = 6;
        if (difference.inDays == numberOfDays + 1) {
          roundMileages.add(RoundMileage(
              departureMileage: departureElement,
              arrivalMileage: arrivalElement));
        }
      }
    }
    return roundMileages;
  }

  static Future<List<MileageV2>> getDanMileagesV2(SearchModel searchModel) async {
    print('[getDanMileagesV2] 시작');
    List<MileageV2> mileages = [];

    // 출발/도착 공항 코드 추출
    String departureAirport = searchModel.departureAirport.toString();
    departureAirport = departureAirport.substring(departureAirport.indexOf('-') + 1);
    String arrivalAirport = searchModel.arrivalAirport.toString();
    arrivalAirport = arrivalAirport.substring(arrivalAirport.indexOf('-') + 1);

    String routeDoc = '$departureAirport-$arrivalAirport';
    print('[getDanMileagesV2] routeDoc: $routeDoc');

    final firestore = FirebaseFirestore.instance;
    Map<String, dynamic>? meta;
    // flightInfo/meta 정보 미리 가져오기
    try {
      final metaSnap = await firestore.collection('dan').doc(routeDoc).collection('flightInfo').doc('meta').get();
      if (metaSnap.exists) {
        meta = metaSnap.data();
        print('[getDanMileagesV2] meta 정보 있음: $meta');
      } else {
        print('[getDanMileagesV2] meta 정보 없음');
      }
    } catch (e) {
      print('[getDanMileagesV2] meta 조회 에러: $e');
    }

    // latest/meta에서 최신 컬렉션 id 읽기
    String? latestCollectionId;
    try {
      final latestSnap = await firestore.collection('dan').doc(routeDoc).collection('latest').doc('meta').get();
      if (latestSnap.exists) {
        latestCollectionId = latestSnap.data()?['id'];
        print('[getDanMileagesV2] latestCollectionId: $latestCollectionId');
      } else {
        print('[getDanMileagesV2] latest/meta 도큐먼트 없음');
      }
    } catch (e) {
      print('[getDanMileagesV2] latest/meta 조회 에러: $e');
    }

    if (latestCollectionId != null) {
      // 검색 기간 범위 계산
      int startDate = int.parse('${searchModel.startYear ?? '2025'}${(searchModel.startMonth ?? '1').padLeft(2, '0')}');
      int endDate = int.parse('${searchModel.endYear ?? '2025'}${(searchModel.endMonth ?? '1').padLeft(2, '0')}');
      final docs = await firestore.collection('dan').doc(routeDoc).collection(latestCollectionId).get();
      print('[getDanMileagesV2] $latestCollectionId 내 도큐먼트 개수: ${docs.docs.length}');
      for (final doc in docs.docs) {
        final data = doc.data();
        // print('[getDanMileagesV2] doc data: $data');
        // departureDate(yyyyMMdd)에서 yyyyMM 추출 후 기간 필터링
        String depDate = data['departureDate']?.toString() ?? '';
        if (depDate.length >= 6) {
          int depMonth = int.parse(depDate.substring(0, 6));
          if (depMonth >= startDate && depMonth <= endDate) {
            // 좌석 존재 여부만 판단 (amount가 String/int 모두 안전하게 처리)
            int economyAmount = int.tryParse(data['economy']?['amount']?.toString() ?? '0') ?? 0;
            int businessAmount = int.tryParse(data['business']?['amount']?.toString() ?? '0') ?? 0;
            int firstAmount = int.tryParse(data['first']?['amount']?.toString() ?? '0') ?? 0;
            bool hasEconomy = economyAmount > 0;
            bool hasBusiness = businessAmount > 0;
            bool hasFirst = firstAmount > 0;
            if (hasEconomy || hasBusiness || hasFirst) {
              mileages.add(MileageV2.fromJson(data, meta));
            }
          }
        }
      }
    }
    print('[getDanMileagesV2] 최종 결과 개수: ${mileages.length}');
    mileages.sort((a, b) => a.departureDate.compareTo(b.departureDate));
    return mileages;
  }
}
