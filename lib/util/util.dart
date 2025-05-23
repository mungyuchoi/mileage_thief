class Util {
  static getDepartureDate(String departureDate) {
    if (departureDate.length >= 8) {
      return departureDate.substring(0, 4) +
          "." +
          departureDate.substring(4, 6) +
          '.' +
          departureDate.substring(6, 8);
    }
    return departureDate; // 혹은 ''
  }

  static getDepartureDetailDate(String departureDate) {
    if (departureDate.length >= 10) {
      return "${departureDate.substring(8, 10)}:${departureDate.substring(10)}";
    }
    return ""; // 혹은 '정보 없음'
  }
  static mergeDepartureAirportCity(String city, String airport) {
    return "$city ($airport) 출발";
  }

  static mergeArrivalAirportCity(String city, String airport) {
    return "$city ($airport) 도착";
  }

  static getDepartureAircraft(String aircraft) {
    return "출국일정 ($aircraft)";
  }
  
  static getArrivalAircraft(String aircraft) {
    return "귀국일정 ($aircraft)";
  }

  static getRoundHeader(String? searchDate) {
    String date = "";
    if(searchDate == null || searchDate == "전체") {
      date = "6박(default)";
    } else {
      date = searchDate;
    }
    return '아시아나 | 왕복 | 전체 | ' + date;
  }

  static String convertToTime(String dateStr) {
    // 12자리(yyyyMMddHHmm) → HH:mm
    if (dateStr.length == 12) {
      String hour = dateStr.substring(8, 10);
      String minute = dateStr.substring(10, 12);
      return '$hour:$minute';
    }
    // 8자리(yyyyMMdd) → 시분 정보 없음
    if (dateStr.length == 8) {
      return '시간 정보 없음';
    }
    // 4자리(시분) → HH:mm
    if (dateStr.length == 4) {
      String hour = dateStr.substring(0, 2);
      String minute = dateStr.substring(2, 4);
      return '$hour:$minute';
    }
    // 그 외
    return '유효하지 않은 시간 형식입니다.';
  }


}