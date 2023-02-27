class RoundMileage {
  RoundMileage(
      {required this.departureMileage,
      required this.arrivalMileage,
      this.isExpanded = false});

  Mileage departureMileage;
  Mileage arrivalMileage;
  bool isExpanded;
}

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
      this.firstSeat = '0석',
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
      aircraftType: json['aircraftType'].toString(),
      arrivalAirport: json['arrivalAirport'],
      arrivalCity: json['arrivalCity'],
      arrivalDate: json['arrivalDate'],
      departureAirport: json['departureAirport'],
      departureCity: json['departureCity'],
      departureDate: json['departureDate'],
      economyPrice: json['economyPrice'] ?? '',
      economySeat: json['economySeat'] ?? '0석',
      businessPrice: json['businessPrice'] ?? '',
      businessSeat: json['businessSeat'] ?? '0석',
      firstPrice: json['firstPrice'] ?? '',
      firstSeat: json['firstSeat'] ?? '0석',
      uploadDate: json['uploadDate'],
      isExpanded: false);

  Object? toPrint() {
    print('departureAirport: $departureAirport' +
        'departureCity: $departureCity' +
        'departureDate: $departureDate' +
        'arrivalAirport: $arrivalAirport' +
        'arrivalCity: $arrivalCity' +
        'arrivalDate: $arrivalDate' +
        'aircraftType: $aircraftType');
  }
}
