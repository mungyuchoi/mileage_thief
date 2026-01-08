import 'package:cloud_firestore/cloud_firestore.dart';

class HotelRegionModel {
  final String regionKey;
  final String name;
  final String countryCode;
  final bool isLocal;
  final int sortOrder;
  final bool isActive;

  const HotelRegionModel({
    required this.regionKey,
    required this.name,
    required this.countryCode,
    required this.isLocal,
    required this.sortOrder,
    required this.isActive,
  });

  factory HotelRegionModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return HotelRegionModel(
      regionKey: (data['regionKey'] as String?) ?? doc.id,
      name: (data['name'] as String?) ?? '',
      countryCode: (data['countryCode'] as String?) ?? '',
      isLocal: (data['isLocal'] as bool?) ?? false,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 9999,
      isActive: (data['isActive'] as bool?) ?? true,
    );
  }
}


