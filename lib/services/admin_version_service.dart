import 'package:firebase_database/firebase_database.dart';

class AdminVersionInfo {
  const AdminVersionInfo({
    this.androidLatest = '',
    this.iosLatest = '',
    this.latest = '',
  });

  final String androidLatest;
  final String iosLatest;
  final String latest;

  factory AdminVersionInfo.fromMap(Map<dynamic, dynamic> data) {
    return AdminVersionInfo(
      androidLatest: (data['androidLatest'] ?? '').toString(),
      iosLatest: (data['iosLatest'] ?? '').toString(),
      latest: (data['latest'] ?? '').toString(),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'androidLatest': androidLatest,
      'iosLatest': iosLatest,
      'latest': latest,
    };
  }
}

class AdminVersionService {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  static Future<AdminVersionInfo> loadVersion() async {
    final snapshot = await _database.child('VERSION').get();
    final raw = snapshot.value;
    if (raw is Map) {
      return AdminVersionInfo.fromMap(raw);
    }
    return const AdminVersionInfo();
  }

  static Future<void> saveVersion(AdminVersionInfo versionInfo) {
    return _database.child('VERSION').update(versionInfo.toMap());
  }
}
