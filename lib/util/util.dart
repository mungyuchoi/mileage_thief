
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
    return "출국일정 (" + aircraft + ")";
  }
}