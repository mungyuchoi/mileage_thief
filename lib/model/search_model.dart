class SearchModel {
  final bool isRoundTrip;
  final String? departureAirport;
  final String? arrivalAirport;
  final String? seatClass;
  final String? searchDate;

  SearchModel(
      {required this.isRoundTrip,
      required this.departureAirport,
      required this.arrivalAirport,
      required this.seatClass,
      required this.searchDate});
}
