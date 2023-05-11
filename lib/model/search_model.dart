class SearchModel {
  final bool isRoundTrip;
  final String? departureAirport;
  final String? arrivalAirport;
  final String? seatClass;
  final String? searchDate;
  String? startMonth = DateTime.now().month.toString();
  String? startYear = DateTime.now().year.toString();
  String? endMonth = DateTime.now().month.toString();
  String? endYear = (DateTime.now().year + 1).toString();

  SearchModel(
      {required this.isRoundTrip,
      required this.departureAirport,
      required this.arrivalAirport,
      required this.seatClass,
      required this.searchDate,
      this.startMonth,
      this.startYear,
      this.endMonth,
      this.endYear});
}
