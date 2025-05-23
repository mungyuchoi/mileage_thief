class RoundMileageV2 {
  RoundMileageV2({required this.departureMileage, required this.arrivalMileage, this.isExpanded = false});

  MileageV2 departureMileage;
  MileageV2 arrivalMileage;
  bool isExpanded;
}

class MileageV2 {
  MileageV2({
    required this.aircraftType,
    required this.arrivalAirport,
    required this.arrivalCity,
    required this.arrivalDate,
    required this.departureAirport,
    required this.departureCity,
    required this.departureDate,
    this.economyPrice = '',
    this.businessPrice = '',
    this.firstPrice = '',
    this.uploadDate = '',
    this.hasEconomy = false,
    this.hasBusiness = false,
    this.hasFirst = false,
    this.isExpanded = false,
  });

  String aircraftType;
  String arrivalAirport;
  String arrivalCity;
  String arrivalDate;
  String departureAirport;
  String departureCity;
  String departureDate;
  String economyPrice;
  String businessPrice;
  String firstPrice;
  String uploadDate;
  bool hasEconomy;
  bool hasBusiness;
  bool hasFirst;
  bool isExpanded;

  static MileageV2 fromJson(Map<String, dynamic> json, Map<String, dynamic>? meta) => MileageV2(
    aircraftType: meta?['aircraftType'] ?? '',
    arrivalAirport: json['arrivalAirport'] ?? '',
    arrivalCity: meta?['arrivalCity'] ?? '',
    arrivalDate: '', // 필요시 추가
    departureAirport: json['departureAirport'] ?? '',
    departureCity: meta?['departureCity'] ?? '',
    departureDate: json['departureDate'] ?? '',
    economyPrice: '',
    businessPrice: '',
    firstPrice: '',
    uploadDate: json['metadata']?['updatedAt']?.toString() ?? '',
    hasEconomy: int.tryParse(json['economy']?['amount']?.toString() ?? '0') != null && int.tryParse(json['economy']?['amount']?.toString() ?? '0')! > 0,
    hasBusiness: int.tryParse(json['business']?['amount']?.toString() ?? '0') != null && int.tryParse(json['business']?['amount']?.toString() ?? '0')! > 0,
    hasFirst: int.tryParse(json['first']?['amount']?.toString() ?? '0') != null && int.tryParse(json['first']?['amount']?.toString() ?? '0')! > 0,
    isExpanded: false,
  );
} 