import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/hotel_deal_card_model.dart';
import '../../models/hotel_static_model.dart';
import '../../services/hotel_deals_service.dart';
import '../../milecatch_rich_editor/src/constants/color_constants.dart';

class HotelDetailScreen extends StatefulWidget {
  final HotelDealCardModel initialDeal;
  const HotelDetailScreen({super.key, required this.initialDeal});

  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  late final String _dealId = widget.initialDeal.dealId;
  late final String _hotelId = widget.initialDeal.hotelId;

  @override
  void initState() {
    super.initState();
    // 방문/히스토리 기록 (실패해도 UX 영향 없도록 fire-and-forget)
    HotelDealsService.incrementVisitCount(_hotelId);
    HotelDealsService.upsertHotelHistory(
      hotelId: _hotelId,
      name: widget.initialDeal.name,
      imageUrl: widget.initialDeal.imageUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HotelDealCardModel?>(
      stream: HotelDealsService.getDealCardStream(_dealId),
      builder: (context, dealSnap) {
        final deal = dealSnap.data ?? widget.initialDeal;
        return FutureBuilder<HotelStaticModel?>(
          future: HotelDealsService.getHotelStatic(_hotelId),
          builder: (context, staticSnap) {
            final hotel = staticSnap.data;
            final images = _getImages(deal, hotel);

            return Scaffold(
              backgroundColor: Colors.grey[50],
              appBar: AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                elevation: 1,
                iconTheme: const IconThemeData(color: Colors.black),
                title: const Text(
                  '특가 호텔',
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
                actions: [
                  _SavedButton(
                    hotelId: _hotelId,
                    name: deal.name,
                    imageUrl: deal.imageUrl,
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: SafeArea(
                child: ListView(
                  children: [
                    _HeaderGallery(images: images),
                    const SizedBox(height: 12),
                    _InfoSection(deal: deal, hotel: hotel),
                    const SizedBox(height: 12),
                    _PriceSection(deal: deal),
                    const SizedBox(height: 12),
                    _ActionSection(deal: deal),
                    const SizedBox(height: 12),
                    _PriceHistorySection(
                      hotelId: _hotelId,
                      windowKey: deal.windowKey,
                      checkInDate: deal.checkInDate,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<String> _getImages(HotelDealCardModel deal, HotelStaticModel? hotel) {
    final urls = (hotel?.imageUrls ?? const <String>[])
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (urls.isNotEmpty) return urls.take(10).toList();
    if (deal.imageUrl.trim().isNotEmpty) return [deal.imageUrl];
    return const <String>[];
  }
}

class _SavedButton extends StatelessWidget {
  final String hotelId;
  final String name;
  final String imageUrl;

  const _SavedButton({
    required this.hotelId,
    required this.name,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return IconButton(
        onPressed: () => Fluttertoast.showToast(msg: '로그인 후 이용 가능합니다.'),
        icon: const Icon(Icons.favorite_border, color: Colors.black54),
      );
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_hotels')
        .doc(hotelId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final saved = snap.data?.exists ?? false;
        return IconButton(
          onPressed: () async {
            await HotelDealsService.toggleSavedHotel(
              hotelId: hotelId,
              name: name,
              imageUrl: imageUrl,
            );
            Fluttertoast.showToast(msg: saved ? '즐겨찾기 해제' : '즐겨찾기 저장');
          },
          icon: Icon(
            saved ? Icons.favorite : Icons.favorite_border,
            color: saved ? Colors.red[400] : Colors.black54,
          ),
        );
      },
    );
  }
}

class _HeaderGallery extends StatelessWidget {
  final List<String> images;
  const _HeaderGallery({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Container(
        height: 240,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, color: Colors.black38, size: 36),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _HotelGalleryScreen(images: images)),
        );
      },
      child: Container(
        height: 240,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Stack(
          children: [
            PageView.builder(
              itemCount: images.length,
              itemBuilder: (context, i) {
                return Image.network(
                  images[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.black38)),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ColorConstants.milecatchBrown,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${images.length}장 · 탭해서 크게 보기',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final HotelDealCardModel deal;
  final HotelStaticModel? hotel;

  const _InfoSection({required this.deal, required this.hotel});

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('#,###');
    final areaName = (hotel?.areaName ?? '').trim();
    final star = deal.starRating > 0 ? deal.starRating.toStringAsFixed(1) : '-';
    final review = deal.reviewScore > 0 ? deal.reviewScore.toStringAsFixed(1) : '-';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deal.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(icon: Icons.star, label: '$star성급'),
              _Chip(icon: Icons.reviews_outlined, label: '리뷰 $review'),
              if (deal.reviewCount > 0)
                _Chip(icon: Icons.people_alt_outlined, label: '${number.format(deal.reviewCount)}개'),
              if (areaName.isNotEmpty) _Chip(icon: Icons.place_outlined, label: areaName),
              if (deal.checkInDate.isNotEmpty) _Chip(icon: Icons.calendar_month_outlined, label: deal.checkInDate),
              if (deal.windowKey.isNotEmpty) _Chip(icon: Icons.schedule_outlined, label: _windowLabel(deal.windowKey)),
            ],
          ),
        ],
      ),
    );
  }

  String _windowLabel(String key) {
    switch (key) {
      case 'TODAY':
        return '오늘';
      case 'TOMORROW':
        return '내일';
      case 'THIS_WEEKEND':
        return '이번주말';
      case 'NEXT_WEEKEND':
        return '다음주말';
      default:
        return key;
    }
  }
}

class _PriceSection extends StatelessWidget {
  final HotelDealCardModel deal;
  const _PriceSection({required this.deal});

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('#,###');
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '가격',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (deal.discountPct > 0)
                Text(
                  '${deal.discountPct}%',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.red[600]),
                ),
              if (deal.discountPct > 0) const SizedBox(width: 8),
              Text(
                '${number.format(deal.totalPrice)}원',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
              ),
              const SizedBox(width: 8),
              if (deal.price > 0 && deal.totalPrice != deal.price)
                Text(
                  '(${number.format(deal.price)}원)',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                icon: deal.hasFreeCancellation ? Icons.check_circle : Icons.cancel_outlined,
                label: deal.hasFreeCancellation ? '무료 취소 가능' : '무료 취소 정보 없음',
                color: deal.hasFreeCancellation ? Colors.green : Colors.black54,
              ),
              if (deal.remainingRooms != null)
                _Chip(
                  icon: Icons.bed_outlined,
                  label: '객실 ${deal.remainingRooms}개 남음',
                  color: (deal.remainingRooms != null && deal.remainingRooms! <= 4) ? Colors.red[600] : Colors.black54,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  final HotelDealCardModel deal;
  const _ActionSection({required this.deal});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openBooking(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConstants.milecatchBrown,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('아고다로 예약하기', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBooking(BuildContext context) async {
    final urlStr = deal.bookingUrl.trim();
    if (urlStr.isEmpty) {
      Fluttertoast.showToast(msg: '예약 링크가 없습니다.');
      return;
    }
    try {
      final url = Uri.parse(urlStr);
      final ok = await canLaunchUrl(url);
      if (!ok) {
        Fluttertoast.showToast(msg: '예약 페이지를 열 수 없습니다.');
        return;
      }
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      Fluttertoast.showToast(msg: '예약 페이지를 열 수 없습니다.');
    }
  }
}

class _PriceHistorySection extends StatelessWidget {
  final String hotelId;
  final String windowKey;
  final String checkInDate;

  const _PriceHistorySection({
    required this.hotelId,
    required this.windowKey,
    required this.checkInDate,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '가격 이력',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            checkInDate.isNotEmpty ? '$checkInDate · ${_windowLabel(windowKey)} 기준' : '최근 기록',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: HotelDealsService.getPriceHistoryStream(hotelId, limit: 50),
            builder: (context, snap) {
              final raw = snap.data ?? const <Map<String, dynamic>>[];
              final filtered = _filter(raw);
              if (filtered.length < 2) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('가격 이력이 아직 부족합니다.', style: TextStyle(color: Colors.black54)),
                );
              }

              final points = _toPoints(filtered);
              if (points.length < 2) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('가격 이력을 표시할 수 없습니다.', style: TextStyle(color: Colors.black54)),
                );
              }

              return Column(
                children: [
                  SizedBox(
                    height: 170,
                    child: LineChart(
                      _buildChart(points),
                      duration: const Duration(milliseconds: 250),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _HistoryList(items: filtered.take(10).toList()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _windowLabel(String key) {
    switch (key) {
      case 'TODAY':
        return '오늘';
      case 'TOMORROW':
        return '내일';
      case 'THIS_WEEKEND':
        return '이번주말';
      case 'NEXT_WEEKEND':
        return '다음주말';
      default:
        return key;
    }
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> raw) {
    // 인덱스 없이도 동작하도록: 최신 50개를 받은 뒤 클라이언트 필터
    final targetDate = checkInDate.trim();
    final targetWindow = windowKey.trim();
    if (targetDate.isEmpty || targetWindow.isEmpty) return raw;
    final filtered = raw.where((e) {
      final d = (e['checkInDate'] as String?) ?? '';
      final w = (e['windowKey'] as String?) ?? '';
      return d == targetDate && w == targetWindow;
    }).toList();
    return filtered.isNotEmpty ? filtered : raw;
  }

  List<_PricePoint> _toPoints(List<Map<String, dynamic>> items) {
    final list = <_PricePoint>[];
    for (final e in items) {
      final recordedAt = _parseIso(e['recordedAt'] as String?);
      final totalPrice = (e['totalPrice'] as num?)?.toDouble();
      if (recordedAt == null || totalPrice == null) continue;
      list.add(_PricePoint(recordedAt, totalPrice));
    }
    list.sort((a, b) => a.time.compareTo(b.time));
    // x축: 0..n-1 (시간 간격이 불규칙해도 가독성 우선)
    return list;
  }

  LineChartData _buildChart(List<_PricePoint> points) {
    final yValues = points.map((p) => p.value).toList();
    final minY = yValues.reduce(min);
    final maxY = yValues.reduce(max);
    final pad = max(1.0, (maxY - minY) * 0.08);

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].value));
    }

    return LineChartData(
      minY: minY - pad,
      maxY: maxY + pad,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (maxY - minY) == 0 ? 1 : (maxY - minY) / 4,
        getDrawingHorizontalLine: (_) => FlLine(color: Colors.black12, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 3,
          color: ColorConstants.milecatchBrown,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: ColorConstants.milecatchBrown.withOpacity(0.10),
          ),
        ),
      ],
    );
  }

  DateTime? _parseIso(String? s) {
    if (s == null) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }
}

class _HistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _HistoryList({required this.items});

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('#,###');
    return Column(
      children: [
        for (final e in items)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    (e['recordedAt'] as String?) ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${number.format((e['totalPrice'] as num?)?.toInt() ?? 0)}원',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HotelGalleryScreen extends StatelessWidget {
  final List<String> images;
  const _HotelGalleryScreen({required this.images});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('갤러리', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: PhotoViewGallery.builder(
        itemCount: images.length,
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(images[index]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.2,
          );
        },
        loadingBuilder: (context, event) {
          return const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                color: ColorConstants.milecatchBrown,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _Chip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PricePoint {
  final DateTime time;
  final double value;
  const _PricePoint(this.time, this.value);
}


