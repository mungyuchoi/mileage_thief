import 'package:cloud_firestore/cloud_firestore.dart';

class KoreanAirAwardDashboardService {
  KoreanAirAwardDashboardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const List<KoreanAirAwardRouteConfig> routeConfigs = [
    KoreanAirAwardRouteConfig(arrivalAirport: 'PQC', arrivalCity: '푸꾸옥'),
    KoreanAirAwardRouteConfig(arrivalAirport: 'HKT', arrivalCity: '푸켓'),
    KoreanAirAwardRouteConfig(arrivalAirport: 'CXR', arrivalCity: '나트랑'),
    KoreanAirAwardRouteConfig(arrivalAirport: 'LAX', arrivalCity: '로스앤젤레스'),
    KoreanAirAwardRouteConfig(arrivalAirport: 'JFK', arrivalCity: '뉴욕'),
    KoreanAirAwardRouteConfig(arrivalAirport: 'HNL', arrivalCity: '호놀룰루'),
    KoreanAirAwardRouteConfig(arrivalAirport: 'BCN', arrivalCity: '바르셀로나'),
    KoreanAirAwardRouteConfig(arrivalAirport: 'DPS', arrivalCity: '발리'),
    KoreanAirAwardRouteConfig(arrivalAirport: 'FCO', arrivalCity: '로마'),
    KoreanAirAwardRouteConfig(arrivalAirport: 'CDG', arrivalCity: '파리'),
    KoreanAirAwardRouteConfig(arrivalAirport: 'SYD', arrivalCity: '시드니'),
  ];

  Future<KoreanAirAwardDashboardData> fetchDashboard() async {
    final routes = await Future.wait(
      routeConfigs.map(_fetchRoute),
    );
    return KoreanAirAwardDashboardData(routes: routes);
  }

  Future<KoreanAirAwardRouteItem> _fetchRoute(
    KoreanAirAwardRouteConfig config,
  ) async {
    final outboundRouteKey = 'ICN-${config.arrivalAirport}';
    final inboundRouteKey = '${config.arrivalAirport}-ICN';
    final directions = await Future.wait([
      _fetchDirection(outboundRouteKey, '가는편'),
      _fetchDirection(inboundRouteKey, '오는편'),
    ]);

    return KoreanAirAwardRouteItem(
      config: config,
      outbound: directions[0],
      inbound: directions[1],
    );
  }

  Future<KoreanAirAwardDirection> _fetchDirection(
    String routeKey,
    String label,
  ) async {
    final routeParts = routeKey.split('-');
    final departureAirport = routeParts.isNotEmpty ? routeParts.first : '';
    final arrivalAirport = routeParts.length > 1 ? routeParts.last : '';

    try {
      final latestSnap = await _firestore
          .collection('dan')
          .doc(routeKey)
          .collection('latest')
          .doc('meta')
          .get();
      final latestData = latestSnap.data();
      final timestampKey = latestData?['id']?.toString().trim() ?? '';
      if (timestampKey.isEmpty) {
        return KoreanAirAwardDirection.empty(
          routeKey: routeKey,
          label: label,
          departureAirport: departureAirport,
          arrivalAirport: arrivalAirport,
        );
      }

      final snapshot = await _firestore
          .collection('dan')
          .doc(routeKey)
          .collection(timestampKey)
          .doc('snapshot')
          .get();
      final snapshotData = snapshot.data();
      if (snapshotData == null) {
        return KoreanAirAwardDirection.empty(
          routeKey: routeKey,
          label: label,
          departureAirport: departureAirport,
          arrivalAirport: arrivalAirport,
          timestampKey: timestampKey,
          updatedAt: _timestampToDate(latestData?['updatedAt']),
        );
      }

      final seatsRaw =
          (snapshotData['seatsByDate'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final days = <KoreanAirAwardDay>[];
      for (final entry in seatsRaw.entries) {
        final date = _parseDateKey(entry.key);
        if (date == null) continue;
        final value = (entry.value as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        days.add(KoreanAirAwardDay(
          date: date,
          economyCount: _seatCount(value['economy']),
          businessCount: _seatCount(value['business']),
          firstCount: _seatCount(value['first']),
        ));
      }
      days.sort((a, b) => a.date.compareTo(b.date));

      return KoreanAirAwardDirection(
        routeKey: routeKey,
        label: label,
        departureAirport:
            snapshotData['departureAirport']?.toString() ?? departureAirport,
        arrivalAirport:
            snapshotData['arrivalAirport']?.toString() ?? arrivalAirport,
        timestampKey: timestampKey,
        updatedAt: _timestampToDate(snapshotData['updatedAt']) ??
            _timestampToDate(latestData?['updatedAt']),
        days: days,
      );
    } catch (_) {
      return KoreanAirAwardDirection.empty(
        routeKey: routeKey,
        label: label,
        departureAirport: departureAirport,
        arrivalAirport: arrivalAirport,
      );
    }
  }

  static int _seatCount(dynamic value) {
    if (value is! Map) return 0;
    final amount = value['amount']?.toString().replaceAll(',', '').trim();
    return int.tryParse(amount ?? '') ?? 0;
  }

  static DateTime? _parseDateKey(String key) {
    if (key.length != 8) return null;
    final year = int.tryParse(key.substring(0, 4));
    final month = int.tryParse(key.substring(4, 6));
    final day = int.tryParse(key.substring(6, 8));
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  static DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class KoreanAirAwardDashboardData {
  KoreanAirAwardDashboardData({required this.routes});

  final List<KoreanAirAwardRouteItem> routes;

  String get latestTimestampKey {
    final keys = routes
        .expand((route) => [
              route.outbound.timestampKey,
              route.inbound.timestampKey,
            ])
        .where((key) => key.isNotEmpty)
        .toList()
      ..sort();
    return keys.isEmpty ? '' : keys.last;
  }

  String get latestLabel => _formatTimestampKey(latestTimestampKey);

  int get businessDateCount => routes.fold(
        0,
        (total, route) => total + route.businessDateCount,
      );

  int get firstDateCount => routes.fold(
        0,
        (total, route) => total + route.firstDateCount,
      );

  int get premiumRouteCount =>
      routes.where((route) => route.premiumDateCount > 0).length;

  static String _formatTimestampKey(String key) {
    if (key.length < 10) return '업데이트 정보 없음';
    final year = int.tryParse(key.substring(0, 4));
    final month = int.tryParse(key.substring(4, 6));
    final day = int.tryParse(key.substring(6, 8));
    final hour = key.substring(8, 10);
    if (year == null || month == null || day == null) {
      return '업데이트 정보 없음';
    }
    return '$year년 $month월 $day일 $hour시';
  }
}

class KoreanAirAwardRouteConfig {
  const KoreanAirAwardRouteConfig({
    required this.arrivalAirport,
    required this.arrivalCity,
  });

  final String arrivalAirport;
  final String arrivalCity;
}

class KoreanAirAwardRouteItem {
  const KoreanAirAwardRouteItem({
    required this.config,
    required this.outbound,
    required this.inbound,
  });

  final KoreanAirAwardRouteConfig config;
  final KoreanAirAwardDirection outbound;
  final KoreanAirAwardDirection inbound;

  int get businessDateCount =>
      outbound.businessDateCount + inbound.businessDateCount;

  int get firstDateCount => outbound.firstDateCount + inbound.firstDateCount;

  int get premiumDateCount => businessDateCount + firstDateCount;
}

class KoreanAirAwardDirection {
  const KoreanAirAwardDirection({
    required this.routeKey,
    required this.label,
    required this.departureAirport,
    required this.arrivalAirport,
    required this.timestampKey,
    required this.updatedAt,
    required this.days,
  });

  factory KoreanAirAwardDirection.empty({
    required String routeKey,
    required String label,
    required String departureAirport,
    required String arrivalAirport,
    String timestampKey = '',
    DateTime? updatedAt,
  }) {
    return KoreanAirAwardDirection(
      routeKey: routeKey,
      label: label,
      departureAirport: departureAirport,
      arrivalAirport: arrivalAirport,
      timestampKey: timestampKey,
      updatedAt: updatedAt,
      days: const [],
    );
  }

  final String routeKey;
  final String label;
  final String departureAirport;
  final String arrivalAirport;
  final String timestampKey;
  final DateTime? updatedAt;
  final List<KoreanAirAwardDay> days;

  Map<String, KoreanAirAwardDay> get dayByKey => {
        for (final day in days) KoreanAirAwardDay.dateKey(day.date): day,
      };

  int get businessDateCount => days.where((day) => day.hasBusiness).length;

  int get firstDateCount => days.where((day) => day.hasFirst).length;

  int get premiumDateCount =>
      days.where((day) => day.hasBusiness || day.hasFirst).length;
}

class KoreanAirAwardDay {
  const KoreanAirAwardDay({
    required this.date,
    required this.economyCount,
    required this.businessCount,
    required this.firstCount,
  });

  final DateTime date;
  final int economyCount;
  final int businessCount;
  final int firstCount;

  bool get hasEconomy => economyCount > 0;
  bool get hasBusiness => businessCount > 0;
  bool get hasFirst => firstCount > 0;
  bool get hasPremium => hasBusiness || hasFirst;

  bool matches({
    required bool business,
    required bool first,
  }) {
    return (business && hasBusiness) || (first && hasFirst);
  }

  static String dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}$month$day';
  }
}
