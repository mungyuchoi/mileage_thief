import 'dart:async';

import 'package:flutter/material.dart';
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
  late final String _todayId;
  late final double _markerHueBrown; // #73532E

  @override
  void initState() {
    super.initState();
    _todayId = DateFormat('yyyyMMdd').format(DateTime.now());
    _markerHueBrown = HSVColor.fromColor(const Color(0xFF73532E)).hue;
    _initLocation();
    _loadTodayMarkers();
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

  Future<void> _loadTodayMarkers() async {
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
            .collection('rates_daily')
            .doc(_todayId);
        final ratesDoc = await ratesRef.get();
        if (!ratesDoc.exists) {
          continue; // 오늘 데이터 없으면 마커 표시 안함
        }

        final ratesData = ratesDoc.data() as Map<String, dynamic>?;
        final Map<String, dynamic>? cards = ratesData?['cards'] != null
            ? Map<String, dynamic>.from(ratesData!['cards'] as Map)
            : null;
        if (cards == null || cards.isEmpty) {
          continue;
        }

        // 대표 표시용: buyRate가 가장 높은 상품권 선택
        String? topCardName;
        double? topBuyRate;
        int? topBuyPrice;
        final List<MapEntry<String, dynamic>> entries = cards.entries.toList();
        for (final e in entries) {
          final dynamic v = e.value;
          if (v is Map) {
            final dynamic buyRateDyn = v['buyRate'];
            final dynamic buyPriceDyn = v['buyPrice'];
            if (buyRateDyn is num && buyPriceDyn is num) {
              final double r = buyRateDyn.toDouble();
              final int p = buyPriceDyn.toInt();
              if (topBuyRate == null || r > topBuyRate) {
                topBuyRate = r;
                topBuyPrice = p;
                topCardName = e.key;
              }
            }
          }
        }

        if (topCardName == null || topBuyRate == null || topBuyPrice == null) {
          continue;
        }

        final String branchName = (data['name'] as String?) ?? doc.id;
        final String snippet = '${_toDisplayCardName(topCardName)} ${topBuyRate.toStringAsFixed(2)}%  ${_formatCurrency(topBuyPrice)}';
        final String dateLabel = _formatDateId((ratesData?['date'] as String?) ?? _todayId);
        final String? updatedText = _extractUpdatedText(ratesData);

        final marker = Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: '$branchName (상품권 매입)', snippet: snippet),
          // 갈색(#73532E)과 가장 가까운 hue를 적용
          icon: BitmapDescriptor.defaultMarkerWithHue(_markerHueBrown),
          onTap: () {
            _showBranchBottomSheet(
              branchId: doc.id,
              branchData: data,
              cards: cards,
              dateLabel: dateLabel,
              updatedText: updatedText,
            );
          },
        );
        newMarkers.add(marker);
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
    required Map<String, dynamic> cards,
    required String dateLabel,
    String? updatedText,
  }) {
    final String name = (branchData['name'] as String?) ?? branchId;
    final String? phone = branchData['phone'] as String?;
    final Map<String, dynamic>? openingHours = branchData['openingHours'] is Map
        ? Map<String, dynamic>.from(branchData['openingHours'] as Map)
        : null;
    final String? notice = branchData['notice'] as String?;
    final String? address = branchData['address'] as String?;

    // 카드 정보를 buyRate 내림차순 정렬
    final List<MapEntry<String, dynamic>> sortedCards = cards.entries.where((e) => e.value is Map).toList()
      ..sort((a, b) {
        final double ar = ((a.value as Map)['buyRate'] is num) ? ((a.value as Map)['buyRate'] as num).toDouble() : -9999;
        final double br = ((b.value as Map)['buyRate'] is num) ? ((b.value as Map)['buyRate'] as num).toDouble() : -9999;
        return br.compareTo(ar);
      });

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
                        Text(
                          updatedText != null ? '$dateLabel (업데이트 $updatedText)' : '$dateLabel (업데이트 날짜)',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
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
                    Text('오늘 매입가', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: sortedCards.length,
                      separatorBuilder: (_, __) => const Divider(height: 12),
                      itemBuilder: (context, index) {
                        final entry = sortedCards[index];
                        final String cardName = _toDisplayCardName(entry.key);
                        final Map v = entry.value as Map;
                        final double? buyRate = (v['buyRate'] is num) ? (v['buyRate'] as num).toDouble() : null;
                        final int? buyPrice = (v['buyPrice'] is num) ? (v['buyPrice'] as num).toInt() : null;
                        if (buyRate == null || buyPrice == null) {
                          return const SizedBox.shrink();
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(cardName),
                            Text('${buyRate.toStringAsFixed(2)}%  ${_formatCurrency(buyPrice)}'),
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


