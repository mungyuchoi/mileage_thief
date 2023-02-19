class Mileage {
  Mileage(
      {required this.aircraftType,
      required this.arrivalAirport,
      required this.arrivalCity,
      required this.arrivalDate,
      required this.departureAirport,
      required this.departureCity,
      required this.departureDate,
      this.economyPrice = '',
      this.economySeat = '0석',
      this.businessPrice = '',
      this.businessSeat = '0석',
      this.firstPrice = '',
      this.firstSeat = '',
      this.uploadDate = '',
      this.isExpanded = false});

  String aircraftType;
  String arrivalAirport;
  String arrivalCity;
  String arrivalDate;
  String departureAirport;
  String departureCity;
  String departureDate;
  String economyPrice;
  String economySeat;
  String businessPrice;
  String businessSeat;
  String firstPrice;
  String firstSeat;
  String uploadDate;
  bool isExpanded;

  static Mileage fromJson(Map<dynamic, dynamic> json) => Mileage(
      aircraftType: json['aircraftType'],
      arrivalAirport: json['arrivalAirport'],
      arrivalCity: json['arrivalCity'],
      arrivalDate: json['arrivalDate'],
      departureAirport: json['departureAirport'],
      departureCity: json['departureCity'],
      departureDate: json['departureDate'],
      isExpanded: false);

  Object? toPrint() {
    print('departureAirport: $departureAirport' +
        'departureCity: $departureCity' +
        'departureDate: $departureDate' +
        'arrivalAirport: $arrivalAirport' +
        'arrivalCity: $arrivalCity' +
        'arrivalDate: $arrivalDate' +
        'aircraftType: $aircraftType'
    );
  }
}
