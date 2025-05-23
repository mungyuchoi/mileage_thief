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
    this.economyMileage = '',
    this.businessMileage = '',
    this.firstMileage = '',
    this.economyAmount = '',
    this.businessAmount = '',
    this.firstAmount = '',
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
  String economyMileage;
  String businessMileage;
  String firstMileage;
  String economyAmount;
  String businessAmount;
  String firstAmount;
  String uploadDate;
  bool hasEconomy;
  bool hasBusiness;
  bool hasFirst;
  bool isExpanded;

  static MileageV2 fromJson(Map<String, dynamic> json, Map<String, dynamic>? meta) {
    final instance = MileageV2(
      aircraftType: meta?['aircraftType'] ?? json['aircraftType'] ?? '',
      arrivalAirport: json['arrivalAirport'] ?? '',
      arrivalCity: meta?['arrivalCity'] ?? json['arrivalCity'] ?? '',
      arrivalDate: json['departureDate'] ?? '',
      departureAirport: json['departureAirport'] ?? '',
      departureCity: meta?['departureCity'] ?? json['departureCity'] ?? '',
      departureDate: json['departureDate'] ?? '',
      economyMileage: json['economy']?['mileage']?.toString() ?? '',
      businessMileage: json['business']?['mileage']?.toString() ?? '',
      firstMileage: json['first']?['mileage']?.toString() ?? '',
      economyAmount: json['economy']?['amount']?.toString() ?? '',
      businessAmount: json['business']?['amount']?.toString() ?? '',
      firstAmount: json['first']?['amount']?.toString() ?? '',
      uploadDate: json['metadata']?['updatedAt']?.toString() ?? '',
      hasEconomy: int.tryParse(json['economy']?['amount']?.toString() ?? '0') != null && int.tryParse(json['economy']?['amount']?.toString() ?? '0')! > 0,
      hasBusiness: int.tryParse(json['business']?['amount']?.toString() ?? '0') != null && int.tryParse(json['business']?['amount']?.toString() ?? '0')! > 0,
      hasFirst: int.tryParse(json['first']?['amount']?.toString() ?? '0') != null && int.tryParse(json['first']?['amount']?.toString() ?? '0')! > 0,
      isExpanded: false,
    );
    print('[MileageV2.fromJson] economyMileage: \\${instance.economyMileage}, businessMileage: \\${instance.businessMileage}, firstMileage: \\${instance.firstMileage}, economyAmount: \\${instance.economyAmount}, businessAmount: \\${instance.businessAmount}, firstAmount: \\${instance.firstAmount}');
    return instance;
  }
} 