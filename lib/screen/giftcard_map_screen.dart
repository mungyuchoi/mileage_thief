import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class GiftcardMapScreen extends StatefulWidget {
  const GiftcardMapScreen({super.key});

  @override
  State<GiftcardMapScreen> createState() => _GiftcardMapScreenState();
}

class _GiftcardMapScreenState extends State<GiftcardMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  CameraPosition _initialCamera = const CameraPosition(
    target: LatLng(37.5665, 126.9780), // 서울시청 근처 기본값
    zoom: 12,
  );
  bool _locationEnabled = false;
  final Set<Marker> _markers = <Marker>{};
  bool _isLoading = false;
  late final String _monthKey;
  late final double _markerHueBrown; // #73532E
  final Map<String, BitmapDescriptor> _logoIconCache = <String, BitmapDescriptor>{};
  final Map<String, Future<BitmapDescriptor>> _logoIconLoading = <String, Future<BitmapDescriptor>>{};

  @override
  void initState() {
    super.initState();
    _monthKey = DateFormat('yyyyMM').format(DateTime.now());
    _markerHueBrown = HSVColor.fromColor(const Color(0xFF73532E)).hue;
    _initLocation();
    _loadMonthlyMarkers();
    // 기본 마커 사용으로 커스텀 로드는 제거
  }

  Future<void> _initLocation() async {
    final permission = await Geolocator.checkPermission();
    LocationPermission granted = permission;
    if (permission == LocationPermission.denied) {
      granted = await Geolocator.requestPermission();
    }
    if (granted == LocationPermission.deniedForever) {
      setState(() {
        _locationEnabled = false;
      });
      return;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationEnabled = false;
      });
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _locationEnabled = true;
        _initialCamera = CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 15);
      });
      final controller = await _mapController.future;
      await controller.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
    } catch (_) {
      setState(() {
        _locationEnabled = false;
      });
    }
  }

  // 커스텀 마커 로직 제거됨

  Future<void> _loadMonthlyMarkers() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final branchesSnap = await FirebaseFirestore.instance.collection('branches').get();
      final List<Marker> newMarkers = [];

      for (final doc in branchesSnap.docs) {
        final data = doc.data();
        final double? lat = (data['latitude'] is num) ? (data['latitude'] as num).toDouble() : null;
        final double? lng = (data['longitude'] is num) ? (data['longitude'] as num).toDouble() : null;
        if (lat == null || lng == null) {
          continue;
        }

        final ratesRef = FirebaseFirestore.instance
            .collection('branches')
            .doc(doc.id)
            .collection('rates_monthly')
            .doc(_monthKey);
        final ratesDoc = await ratesRef.get();
        if (!ratesDoc.exists) {
          continue; // 이번 달 데이터 없으면 마커 표시 안함
        }

        final Map<String, dynamic> ratesData = Map<String, dynamic>.from(ratesDoc.data() as Map);
        final List<dynamic> saleUsers = (ratesData['users'] is List) ? List<dynamic>.from(ratesData['users'] as List) : <dynamic>[];

        // uid별 합산으로 랭킹 계산
        final Map<String, Map<String, dynamic>> agg = {};
        for (final u in saleUsers) {
          if (u is! Map) continue;
          final String uid = (u['uid'] as String?) ?? '';
          if (uid.isEmpty) continue;
          final int v = (u['sellTotal'] as num?)?.toInt() ?? 0;
          final String dn = (u['displayName'] as String?) ?? '';
          final String pu = (u['photoUrl'] as String?) ?? '';
          final Map<String, dynamic> cur = agg[uid] ?? {'uid': uid, 'displayName': dn, 'photoUrl': pu, 'sellTotal': 0};
          cur['sellTotal'] = ((cur['sellTotal'] as int?) ?? 0) + v;
          cur['displayName'] = dn;
          cur['photoUrl'] = pu;
          agg[uid] = cur;
        }
        final List<Map<String, dynamic>> ranked = agg.values.toList()
          ..sort((a, b) => ((b['sellTotal'] as int) - (a['sellTotal'] as int)));
        final Map<String, dynamic>? firstUser = ranked.isNotEmpty ? ranked[0] : null;
        final Map<String, dynamic>? secondUser = ranked.length > 1 ? ranked[1] : null;
        final Map<String, dynamic>? thirdUser = ranked.length > 2 ? ranked[2] : null;

        // 저장된 top3와 다르면 업데이트(베스트 effort)
        try {
          final Map<String, dynamic>? f0 = (ratesData['firstUser'] is Map) ? Map<String, dynamic>.from(ratesData['firstUser'] as Map) : null;
          if (f0?['uid'] != firstUser?['uid'] ||
              (ratesData['secondUser'] as Map?)?['uid'] != secondUser?['uid'] ||
              (ratesData['thirdUser'] as Map?)?['uid'] != thirdUser?['uid']) {
            await ratesRef.set({'firstUser': firstUser, 'secondUser': secondUser, 'thirdUser': thirdUser, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
          }
        } catch (_) {}

        final String branchName = (data['name'] as String?) ?? doc.id;
        final String snippet = (firstUser != null)
            ? '${firstUser['displayName'] ?? '판매왕'} ${_formatCurrency(((firstUser['sellTotal'] as num?)?.toInt() ?? 0))}'
            : '이달 판매 데이터 없음';

        final LatLng position = LatLng(lat, lng);
        Marker _buildMarker(BitmapDescriptor icon, {bool customAnchor = false}) {
          return Marker(
            markerId: MarkerId(doc.id),
            position: position,
            infoWindow: InfoWindow(title: '$branchName (이달 판매왕)', snippet: snippet),
            icon: icon,
            anchor: customAnchor ? const Offset(0.5, 0.5) : const Offset(0.5, 1.0),
            onTap: () {
              _showBranchBottomSheet(
                branchId: doc.id,
                branchData: data,
                rankedUsers: ranked,
                firstUser: firstUser,
                secondUser: secondUser,
                thirdUser: thirdUser,
              );
            },
          );
        }

        final Marker marker = _buildMarker(
          BitmapDescriptor.defaultMarkerWithHue(_markerHueBrown),
        );
        newMarkers.add(marker);

        // firstUser의 photoUrl로 커스텀 마커 로딩 후 교체 (없으면 지점 로고 사용)
        final String? markerPhoto = (firstUser?['photoUrl'] as String?) ?? data['logoUrl'] as String?;
        if (markerPhoto != null && markerPhoto.isNotEmpty) {
          _getCircleMarkerFromUrl(markerPhoto).then((BitmapDescriptor icon) {
            if (!mounted) return;
            setState(() {
              _markers.removeWhere((m) => m.markerId.value == doc.id);
              _markers.add(_buildMarker(icon, customAnchor: true));
            });
          }).catchError((_) {
            // 무시: 로고 로딩 실패 시 기본 마커 유지
          });
        }
      }

      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
      });
    } catch (_) {
      // silent fail for now
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<BitmapDescriptor> _getCircleMarkerFromUrl(String url, {int diameter = 120}) async {
    final String key = '$url@$diameter';
    final BitmapDescriptor? cached = _logoIconCache[key];
    if (cached != null) return cached;
    final Future<BitmapDescriptor>? ongoing = _logoIconLoading[key];
    if (ongoing != null) return await ongoing;

    final Completer<BitmapDescriptor> completer = Completer<BitmapDescriptor>();
    _logoIconLoading[key] = completer.future;

    try {
      final Uri uri = Uri.parse(url);
      final ByteData byteData = await NetworkAssetBundle(uri).load(uri.toString());
      final Uint8List bytes = byteData.buffer.asUint8List();

      final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: diameter, targetHeight: diameter);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image rawImage = frameInfo.image;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final double size = diameter.toDouble();
      final Rect drawRect = Rect.fromLTWH(0, 0, size, size);

      final Path clipPath = Path()
        ..addOval(Rect.fromCircle(center: Offset(size / 2, size / 2), radius: size / 2));
      canvas.clipPath(clipPath);
      final Paint paint = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      canvas.drawImageRect(
        rawImage,
        Rect.fromLTWH(0, 0, rawImage.width.toDouble(), rawImage.height.toDouble()),
        drawRect,
        paint,
      );
      // 테두리
      final Paint border = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF73532E)
        ..strokeWidth = 6;
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 3, border);

      final ui.Image outImage = await recorder.endRecording().toImage(diameter, diameter);
      final ByteData? pngBytes = await outImage.toByteData(format: ui.ImageByteFormat.png);
      final BitmapDescriptor descriptor = BitmapDescriptor.fromBytes(pngBytes!.buffer.asUint8List());
      _logoIconCache[key] = descriptor;
      completer.complete(descriptor);
    } catch (e) {
      completer.completeError(e);
    } finally {
      _logoIconLoading.remove(key);
    }

    return completer.future;
  }

  String _formatCurrency(int value) {
    final formatter = NumberFormat('#,###');
    return '${formatter.format(value)}원';
  }

  String _toDisplayCardName(String raw) {
    switch (raw) {
      case 'lotte':
        return '롯데';
      case 'shinsegae':
        return '신세계';
      case 'hyundai':
        return '현대';
      case 'galleria':
        return '갤러리아';
      case 'tourism':
        return '관광';
      case 'eland':
        return '이랜드';
      case 'costco':
        return '코스트코';
      case 'samsung':
        return '삼성';
      default:
        return raw;
    }
  }

  // 색상 기준 마커 로직은 현재 미사용

  String _formatDateId(String yyyymmdd) {
    if (yyyymmdd.length == 8) {
      final y = yyyymmdd.substring(0, 4);
      final m = yyyymmdd.substring(4, 6);
      final d = yyyymmdd.substring(6, 8);
      return '$y.$m.$d';
    }
    return yyyymmdd;
  }

  String? _extractUpdatedText(Map<String, dynamic>? ratesData) {
    if (ratesData == null) return null;
    final dynamic v = ratesData['updatedAt'] ?? ratesData['updated_at'] ?? ratesData['lastUpdated'];
    if (v == null) return null;
    try {
      if (v is Timestamp) {
        return DateFormat('HH:mm').format(v.toDate());
      }
      if (v is int) {
        final dt = DateTime.fromMillisecondsSinceEpoch(v);
        return DateFormat('HH:mm').format(dt);
      }
      if (v is String) {
        final dt = DateTime.tryParse(v);
        if (dt != null) {
          return DateFormat('HH:mm').format(dt);
        }
      }
    } catch (_) {}
    return null;
  }

  void _showBranchBottomSheet({
    required String branchId,
    required Map<String, dynamic> branchData,
    required List<Map<String, dynamic>> rankedUsers,
    Map<String, dynamic>? firstUser,
    Map<String, dynamic>? secondUser,
    Map<String, dynamic>? thirdUser,
  }) {
    final String name = (branchData['name'] as String?) ?? branchId;
    final String? phone = branchData['phone'] as String?;
    final Map<String, dynamic>? openingHours = branchData['openingHours'] is Map
        ? Map<String, dynamic>.from(branchData['openingHours'] as Map)
        : null;
    final String? notice = branchData['notice'] as String?;
    final String? address = branchData['address'] as String?;

    final String monthLabel = DateFormat('yyyy.MM').format(DateTime.now());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          if (phone != null && phone.isNotEmpty)
                            InkWell(
                              onTap: () => _launchDial(phone),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone, size: 16, color: Colors.black54),
                                  const SizedBox(width: 6),
                                  Text(phone, style: const TextStyle(color: Colors.black87, decoration: TextDecoration.underline)),
                                ],
                              ),
                            ),
                          if (address != null && address.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.place, size: 16, color: Colors.black54),
                                const SizedBox(width: 6),
                                Expanded(child: Text(address)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$monthLabel 기준', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
                if (openingHours != null && openingHours.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.black54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: openingHours.entries
                              .map((e) => Text('${_localizeHoursKey(e.key)}: ${e.value}'))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ],
                if (notice != null && notice.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.black54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          notice,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Text('이달의 판매왕', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                _TopThreeRow(first: firstUser, second: secondUser, third: thirdUser),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Text('랭킹', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: rankedUsers.length,
                      separatorBuilder: (_, __) => const Divider(height: 12),
                      itemBuilder: (context, index) {
                        final Map u = Map<String, dynamic>.from(rankedUsers[index] as Map);
                        final String nameLabel = (u['displayName'] as String?) ?? '익명';
                        final String? p = u['photoUrl'] as String?;
                        final int total = (u['sellTotal'] as num?)?.toInt() ?? 0;
                        return Row(
                          children: [
                            Container(
                              width: 28,
                              alignment: Alignment.center,
                              child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            CircleAvatar(radius: 14, backgroundImage: (p != null && p.isNotEmpty) ? NetworkImage(p) : null),
                            const SizedBox(width: 8),
                            Expanded(child: Text(nameLabel, style: const TextStyle(color: Colors.black87))),
                            Text(_formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _localizeHoursKey(String key) {
    switch (key) {
      case 'monFri':
        return '월금';
      case 'sat':
        return '토';
      case 'sun':
        return '주말,공휴일';
      default:
        return key;
    }
  }

  Future<void> _launchDial(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _initialCamera,
          myLocationEnabled: _locationEnabled,
          myLocationButtonEnabled: true,
          compassEnabled: true,
          trafficEnabled: false,
          // 하단 내비/플로팅 버튼과 겹치지 않도록 UI(로고/줌버튼) 패딩
          padding: const EdgeInsets.only(bottom: 60, right: 12, left: 12),
          markers: _markers,
          onMapCreated: (controller) {
            if (!_mapController.isCompleted) {
              _mapController.complete(controller);
            }
          },
        ),
      ],
    );
  }
}

class _TopThreeRow extends StatelessWidget {
  final Map<String, dynamic>? first;
  final Map<String, dynamic>? second;
  final Map<String, dynamic>? third;
  const _TopThreeRow({this.first, this.second, this.third});

  @override
  Widget build(BuildContext context) {
    Widget cell(Map<String, dynamic>? u, String medal, Color color) {
      final String name = (u?['displayName'] as String?) ?? '-';
      final String? p = u?['photoUrl'] as String?;
      final int total = (u?['sellTotal'] as num?)?.toInt() ?? 0;
      return Expanded(
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(radius: 24, backgroundImage: (p != null && p.isNotEmpty) ? NetworkImage(p) : null),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                  child: Text(medal, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(name, overflow: TextOverflow.ellipsis),
            Text(NumberFormat('#,###').format(total), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return Row(
      children: [
        cell(second, '2위', const Color(0xFFB0BEC5)),
        cell(first, '1위', const Color(0xFFFFD700)),
        cell(third, '3위', const Color(0xFFCD7F32)),
      ],
    );
  }
}


