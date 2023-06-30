
class Util {
  static getDepartureDate(String departureDate) {
    return departureDate.substring(0, 4) +
        "." +
        departureDate.substring(4, 6) +
        '.' +
        departureDate.substring(6, 8);
  }

  static getDepartureDetailDate(String departureDate) {
    return "${departureDate.substring(8, 10)}:${departureDate.substring(10)}";
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

  static String convertToTime(String arrivalDate) {
    if (arrivalDate.length != 4) {
      // 유효한 시간 형식이 아닌 경우 예외 처리
      return '유효하지 않은 시간 형식입니다.';
    }

    String hour = arrivalDate.substring(0, 2);
    String minute = arrivalDate.substring(2);
    return '$hour:$minute';
  }


}