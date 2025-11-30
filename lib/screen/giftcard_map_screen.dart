import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'branch/branch_edit_screen.dart';
import 'user_profile_screen.dart';

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
  late DateTime _selectedMonth;
  late final double _markerHueBrown; // #73532E
  final Map<String, BitmapDescriptor> _logoIconCache = <String, BitmapDescriptor>{};
  final Map<String, Future<BitmapDescriptor>> _logoIconLoading = <String, Future<BitmapDescriptor>>{};
  final List<Map<String, dynamic>> _branchRankings = <Map<String, dynamic>>[]; // 지점별 월 랭킹(총액 기준 내림차순)

  static const String _fallbackMarkerPhotoUrl =
      'https://firebasestorage.googleapis.com/v0/b/mileagethief.firebasestorage.app/o/users%2FaP3C0N511beyK7QZG9GyChs5oqO2.png?alt=media&token=5e0ddec7-45ad-4f0e-b83e-485ee1babf1d';

  // 비어있지 않은 첫 번째 URL을 선택 (null/빈문자열 모두 건너뜀)
  String _pickMarkerPhotoUrl({
    String? firstUserPhoto,
    String? storedFirstUserPhoto,
    String? logoUrl,
  }) {
    final List<String?> candidates = <String?>[
      firstUserPhoto,
      storedFirstUserPhoto,
      logoUrl,
      _fallbackMarkerPhotoUrl,
    ];
    for (final String? c in candidates) {
      if (c != null && c.trim().isNotEmpty) {
        return c;
      }
    }
    return _fallbackMarkerPhotoUrl;
  }

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
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
      final String monthKey = DateFormat('yyyyMM').format(_selectedMonth);
      final branchesSnap = await FirebaseFirestore.instance.collection('branches').get();
      // 기존 마커 초기화 후 지점별 기본 마커를 즉시 추가
      setState(() {
        _markers.clear();
        _branchRankings.clear();
      });

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
            .doc(monthKey);
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
        final int branchTotal = ranked.fold<int>(0, (sum, u) => sum + ((u['sellTotal'] as num?)?.toInt() ?? 0));

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
          final String monthTitle = '${DateFormat('M').format(_selectedMonth)}월 판매왕';
          return Marker(
            markerId: MarkerId(doc.id),
            position: position,
            infoWindow: InfoWindow(title: '$branchName ($monthTitle)', snippet: snippet),
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
        setState(() {
          _markers.add(marker);
        });

        // firstUser의 photoUrl로 커스텀 마커 로딩 후 교체 (없으면 지점 로고/저장된 firstUser/폴백 사용)
        final String markerPhoto = _pickMarkerPhotoUrl(
          firstUserPhoto: firstUser?['photoUrl'] as String?,
          storedFirstUserPhoto: (ratesData['firstUser'] is Map)
              ? (Map<String, dynamic>.from(ratesData['firstUser'] as Map))['photoUrl'] as String?
              : null,
          logoUrl: data['logoUrl'] as String?,
        );
        debugPrint('[Map] ${doc.id}: loading marker icon from ${markerPhoto.length > 120 ? markerPhoto.substring(0, 120) + '...' : markerPhoto}');
        if (markerPhoto.isNotEmpty) {
          _getCircleMarkerFromUrl(markerPhoto).then((BitmapDescriptor icon) {
            if (!mounted) return;
            setState(() {
              _markers.removeWhere((m) => m.markerId.value == doc.id);
              _markers.add(_buildMarker(icon, customAnchor: true));
            });
          }).catchError((_) {
            // 무시: 로고 로딩 실패 시 기본 마커 유지
            debugPrint('[Map] ${doc.id}: marker icon load failed, try fallback');
            _getCircleMarkerFromUrl(_fallbackMarkerPhotoUrl).then((BitmapDescriptor icon) {
              if (!mounted) return;
              setState(() {
                _markers.removeWhere((m) => m.markerId.value == doc.id);
                _markers.add(_buildMarker(icon, customAnchor: true));
              });
            }).catchError((_) {
              debugPrint('[Map] ${doc.id}: fallback icon load failed, keep default');
            });
          });
        }

        // 바텀시트용 지점 랭킹 데이터 누적
        _branchRankings.add(<String, dynamic>{
          'branchId': doc.id,
          'branchName': branchName,
          'lat': lat,
          'lng': lng,
          'firstUser': firstUser,
          'secondUser': secondUser,
          'thirdUser': thirdUser,
          'total': branchTotal,
        });
      }

      // 총액 기준 내림차순 정렬
      _branchRankings.sort((a, b) => ((b['total'] as int) - (a['total'] as int)));
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

      // 1차: 기본 NetworkAssetBundle
      Uint8List? bytes;
      try {
        final ByteData byteData = await NetworkAssetBundle(uri).load(uri.toString());
        bytes = byteData.buffer.asUint8List();
      } catch (e) {
        debugPrint('[Map] bundle load failed: $e, url=$url');
      }

      // 2차: HttpClient로 재시도(리다이렉트/403 등 대응)
      if (bytes == null) {
        try {
          final HttpClient client = HttpClient()..autoUncompress = true;
          final HttpClientRequest request = await client.getUrl(uri);
          final HttpClientResponse response = await request.close();
          bytes = await consolidateHttpClientResponseBytes(response);
          client.close(force: true);
        } catch (e) {
          debugPrint('[Map] http load failed: $e, url=$url');
          rethrow;
        }
      }

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
  }) async {
    final String name = (branchData['name'] as String?) ?? branchId;
    final String? phone = branchData['phone'] as String?;
    final Map<String, dynamic>? openingHours = branchData['openingHours'] is Map
        ? Map<String, dynamic>.from(branchData['openingHours'] as Map)
        : null;
    final String? notice = branchData['notice'] as String?;
    final String? address = branchData['address'] as String?;

    final String monthLabel = DateFormat('yyyy.MM').format(_selectedMonth);

    // Admin 체크 및 특정 UID 편집 권한 체크
    bool canEdit = false;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final currentUid = currentUser.uid;
      
      // 특정 UID에 편집 권한 부여
      const allowedUids = ['xhMasz7TbTSAyRkLbFsUKQcQhc33'];
      if (allowedUids.contains(currentUid)) {
        canEdit = true;
      } else {
        // Admin 권한 체크
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .get();
          final userData = userDoc.data();
          final roles = userData?['roles'] ?? [];
          canEdit = roles.contains('admin');
        } catch (_) {
          canEdit = false;
        }
      }
    }

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
                        if (canEdit)
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Color(0xFF74512D)),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BranchEditScreen(
                                    branchId: branchId,
                                    branchData: branchData,
                                  ),
                                ),
                              );
                              if (result == true) {
                                // 수정 후 마커 다시 로드
                                _loadMonthlyMarkers();
                              }
                            },
                            tooltip: '편집',
                          ),
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
                              .map((e) {
                                final timeValue = e.value.toString();
                                final displayValue = timeValue == '휴무' ? '휴무' : timeValue;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '${_localizeHoursKey(e.key)}: $displayValue',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              })
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
    // 일반적인 그룹 키
    switch (key) {
      case 'monFri':
        return '월~금';
      case 'monSat':
        return '월~토';
      case 'monSun':
        return '월~일';
      case 'sat':
        return '토';
      case 'sun':
        return '일';
      case 'mon':
        return '월';
      case 'tue':
        return '화';
      case 'wed':
        return '수';
      case 'thu':
        return '목';
      case 'fri':
        return '금';
      default:
        // 조합된 키 처리 (예: tueWed, thuFri 등)
        if (key.length >= 6) {
          // 두 요일 조합 처리
          final dayMap = {
            'mon': '월',
            'tue': '화',
            'wed': '수',
            'thu': '목',
            'fri': '금',
            'sat': '토',
            'sun': '일',
          };
          
          // 3글자씩 나누어 처리
          if (key.length == 6) {
            final first = key.substring(0, 3);
            final second = key.substring(3, 6);
            if (dayMap.containsKey(first) && dayMap.containsKey(second)) {
              return '${dayMap[first]}~${dayMap[second]}';
            }
          }
        }
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
        // 좌상단 월 라벨
        Positioned(
          left: 12,
          top: 12,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _showMonthPickerSheet,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${DateFormat('yyyy.MM').format(_selectedMonth)} 기준',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.expand_more, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 좌하단 '지점 랭킹' Chip
        if (_branchRankings.isNotEmpty)
          Positioned(
            left: 12,
            bottom: 24,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showBranchRankingsSheet,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.leaderboard, size: 16, color: Colors.black87),
                      SizedBox(width: 6),
                      Text('지점 랭킹', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showBranchRankingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final double screenH = MediaQuery.of(ctx).size.height;
        // 상단(AppBar+TabBar) + 칩 영역을 보존하여 시트가 그 위로 넘어가지 않도록 제한
        final double reservedTop =
            MediaQuery.of(ctx).padding.top + kToolbarHeight + 48.0 + 52.0; // status + appbar + tabbar + chip 여유
        final double maxHeight = (screenH - reservedTop).clamp(280.0, screenH);
        final String monthLabel = DateFormat('yyyy.MM').format(_selectedMonth);
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text('지점 랭킹', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 8),
                      Text('($monthLabel 기준)', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      const Spacer(),
                      Text('${_branchRankings.length}개 지점', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _branchRankings.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final Map<String, dynamic> b = _branchRankings[index];
                      final String name = (b['branchName'] as String?) ?? b['branchId'] as String;
                      final int total = (b['total'] as num?)?.toInt() ?? 0;
                      final Map<String, dynamic>? first = b['firstUser'] as Map<String, dynamic>?;
                      final String? firstUid = first?['uid'] as String?;
                      final String? firstPhoto = first?['photoUrl'] as String?;
                      final int firstTotal = (first?['sellTotal'] as num?)?.toInt() ?? 0;

                      Color bg;
                      Color fg = Colors.white;
                      String label;
                      switch (index) {
                        case 0:
                          bg = const Color(0xFFFFD700); // gold
                          label = '1';
                          break;
                        case 1:
                          bg = const Color(0xFFB0BEC5); // silver-ish
                          label = '2';
                          break;
                        case 2:
                          bg = const Color(0xFFCD7F32); // bronze
                          label = '3';
                          break;
                        default:
                          bg = Colors.grey.shade200;
                          fg = Colors.black87;
                          label = '${index + 1}';
                      }

                      return InkWell(
                        onTap: () async {
                          final GoogleMapController c = await _mapController.future;
                          final double lat = (b['lat'] as num).toDouble();
                          final double lng = (b['lng'] as num).toDouble();
                          await c.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                                child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (firstPhoto != null && firstPhoto.isNotEmpty && firstUid != null && firstUid.isNotEmpty)
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserProfileScreen(userUid: firstUid)));
                                            },
                                            child: CircleAvatar(radius: 10, backgroundImage: NetworkImage(firstPhoto)),
                                          )
                                        else
                                          const CircleAvatar(radius: 10, backgroundColor: Color(0xFFE0E0E0), child: Icon(Icons.person, size: 12, color: Colors.white)),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            (first != null)
                                                ? '1위 ${first['displayName'] ?? '익명'} · ${_formatCurrency(firstTotal)}'
                                                : '데이터 없음',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.black54, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(_formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  void _showMonthPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final double screenH = MediaQuery.of(ctx).size.height;
        final double reservedTop =
            MediaQuery.of(ctx).padding.top + kToolbarHeight + 48.0 + 52.0;
        final double maxHeight = (screenH - reservedTop).clamp(280.0, screenH);
        final DateTime start = DateTime(2025, 11);
        final DateTime now = DateTime(DateTime.now().year, DateTime.now().month);
        final List<DateTime> months = <DateTime>[];
        DateTime cur = now;
        while (!(cur.year == start.year && cur.month == start.month)) {
          months.add(cur);
          cur = DateTime(cur.year, cur.month - 1);
        }
        months.add(start);

        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('월 선택', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: months.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final DateTime m = months[index];
                      final String label = DateFormat('yyyy.MM').format(m);
                      final bool selected = (m.year == _selectedMonth.year && m.month == _selectedMonth.month);
                      return ListTile(
                        title: Text(label),
                        trailing: selected ? const Icon(Icons.check, color: Color(0xFF73532E)) : null,
                        onTap: () async {
                          Navigator.pop(context);
                          setState(() {
                            _selectedMonth = m;
                          });
                          await _loadMonthlyMarkers();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
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


