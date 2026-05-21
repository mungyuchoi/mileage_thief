import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../const/colors.dart';
import '../models/point_hotel_model.dart';

class PointHotelDetailScreen extends StatelessWidget {
  final PointHotel hotel;
  final int nights;
  final DateTime? checkIn;

  const PointHotelDetailScreen({
    super.key,
    required this.hotel,
    required this.nights,
    required this.checkIn,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleTextStyle: McTextStyles.appBarTitle.copyWith(
          fontWeight: FontWeight.w400,
        ),
        title: Text(
          hotel.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '저장',
            onPressed: () {},
            icon: const Icon(Icons.favorite_border_rounded),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: McColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: McColors.ink),
                    children: [
                      TextSpan(
                        text:
                            '${NumberFormat('#,###').format(hotel.pointsPerNight)} pts',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(
                        text: '/박',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: McColors.ink,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w400),
                ),
                onPressed: () {},
                child: const Text('예약 보기'),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                hotel.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFE5E7EB),
                  child: Icon(Icons.hotel_outlined, size: 46),
                ),
              ),
            ),
          ),
          if (hotel.galleryUrls.length > 1) ...[
            const SizedBox(height: 10),
            _GalleryStrip(urls: hotel.galleryUrls),
          ],
          const SizedBox(height: 16),
          Text(
            hotel.name,
            style: const TextStyle(
              color: McColors.ink,
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 18),
              const SizedBox(width: 3),
              Text(
                hotel.rating.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w400),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hotel.locationText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hotel.address,
            style: const TextStyle(
              color: Color(0xFF717171),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _HotelBadges(hotel: hotel),
          const SizedBox(height: 18),
          _StaySummaryCard(
            hotel: hotel,
            nights: nights,
            checkIn: checkIn,
          ),
          if (_hasQuickFacts(hotel)) ...[
            const SizedBox(height: 22),
            Text(
              '기본 정보',
              style: McTextStyles.sectionTitle.copyWith(
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12),
            _QuickFactsGrid(hotel: hotel),
          ],
          if (_hasMapLocation(hotel)) ...[
            const SizedBox(height: 22),
            Text(
              '위치',
              style: McTextStyles.sectionTitle.copyWith(
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12),
            _HotelMapCard(hotel: hotel),
          ],
          const SizedBox(height: 22),
          Text(
            '호텔 소개',
            style: McTextStyles.sectionTitle.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(hotel.description, style: McTextStyles.body),
          const SizedBox(height: 22),
          Text(
            '포인트 캘린더',
            style: McTextStyles.sectionTitle.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          _PointCalendar(hotel: hotel),
          if (hotel.pointCalendarNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              hotel.pointCalendarNote,
              style: McTextStyles.meta,
            ),
          ],
          const SizedBox(height: 22),
          Text(
            '편의시설',
            style: McTextStyles.sectionTitle.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          _AmenityGrid(amenities: hotel.displayAmenities),
          for (final section in hotel.detailSections) ...[
            const SizedBox(height: 24),
            _DetailInfoSection(section: section),
          ],
          const SizedBox(height: 22),
          Text(
            '후기',
            style: McTextStyles.sectionTitle.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          _ReviewBox(rating: hotel.rating, reviewCount: hotel.reviewCount),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

bool _hasQuickFacts(PointHotel hotel) {
  return hotel.propertyCode.isNotEmpty ||
      hotel.phone.isNotEmpty ||
      hotel.checkInTime.isNotEmpty ||
      hotel.checkOutTime.isNotEmpty ||
      hotel.reviewCount != null ||
      hotel.loyaltyProgram.isNotEmpty;
}

bool _hasMapLocation(PointHotel hotel) {
  return hotel.latitude != null && hotel.longitude != null;
}

Future<void> _launchHotelMap(PointHotel hotel) async {
  final rawUrl = hotel.mapUrl.isNotEmpty
      ? hotel.mapUrl
      : 'https://maps.google.com/?q=${hotel.latitude},${hotel.longitude}';
  final uri = Uri.tryParse(rawUrl);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _GalleryStrip extends StatelessWidget {
  final List<String> urls;

  const _GalleryStrip({required this.urls});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1.25,
              child: Image.network(
                urls[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFE5E7EB),
                  child: Icon(Icons.image_not_supported_outlined, size: 20),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HotelBadges extends StatelessWidget {
  final PointHotel hotel;

  const _HotelBadges({required this.hotel});

  @override
  Widget build(BuildContext context) {
    final badges = <String>[
      if (hotel.loyaltyProgram.isNotEmpty) hotel.loyaltyProgram,
      if (hotel.propertyCode.isNotEmpty) hotel.propertyCode,
      if (hotel.checkInTime.isNotEmpty) '체크인 ${hotel.checkInTime}',
      if (hotel.checkOutTime.isNotEmpty) '체크아웃 ${hotel.checkOutTime}',
    ];
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final badge in badges)
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: McColors.line),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                badge,
                style: const TextStyle(
                  color: McColors.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickFactsGrid extends StatelessWidget {
  final PointHotel hotel;

  const _QuickFactsGrid({required this.hotel});

  @override
  Widget build(BuildContext context) {
    final facts = <_QuickFact>[
      if (hotel.checkInTime.isNotEmpty)
        _QuickFact(
          icon: Icons.login_rounded,
          label: '체크인',
          value: hotel.checkInTime,
        ),
      if (hotel.checkOutTime.isNotEmpty)
        _QuickFact(
          icon: Icons.logout_rounded,
          label: '체크아웃',
          value: hotel.checkOutTime,
        ),
      if (hotel.propertyCode.isNotEmpty)
        _QuickFact(
          icon: Icons.confirmation_number_outlined,
          label: '호텔 코드',
          value: hotel.propertyCode,
        ),
      if (hotel.phone.isNotEmpty)
        _QuickFact(
          icon: Icons.call_outlined,
          label: '전화',
          value: hotel.phone,
        ),
      if (hotel.reviewCount != null)
        _QuickFact(
          icon: Icons.reviews_outlined,
          label: '리뷰',
          value: '${NumberFormat('#,###').format(hotel.reviewCount)}개',
        ),
      if (hotel.loyaltyProgram.isNotEmpty)
        _QuickFact(
          icon: Icons.workspace_premium_outlined,
          label: '프로그램',
          value: hotel.loyaltyProgram,
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        final itemWidth = (constraints.maxWidth - 10 * (columns - 1)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final fact in facts)
              SizedBox(
                width: itemWidth,
                child: _QuickFactTile(fact: fact),
              ),
          ],
        );
      },
    );
  }
}

class _QuickFact {
  final IconData icon;
  final String label;
  final String value;

  const _QuickFact({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _QuickFactTile extends StatelessWidget {
  final _QuickFact fact;

  const _QuickFactTile({required this.fact});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(fact.icon, size: 22, color: McColors.inkSoft),
          const SizedBox(height: 9),
          Text(fact.label, style: McTextStyles.micro),
          const SizedBox(height: 3),
          Text(
            fact.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: McColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _HotelMapCard extends StatelessWidget {
  final PointHotel hotel;

  const _HotelMapCard({required this.hotel});

  @override
  Widget build(BuildContext context) {
    final position = LatLng(hotel.latitude!, hotel.longitude!);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 218,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: position,
                zoom: 15.5,
              ),
              markers: {
                Marker(
                  markerId: MarkerId('hotel_${hotel.id}'),
                  position: position,
                  infoWindow: InfoWindow(
                    title: hotel.name,
                    snippet: hotel.address,
                  ),
                ),
              },
              compassEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              rotateGesturesEnabled: false,
              scrollGesturesEnabled: false,
              tiltGesturesEnabled: false,
              zoomControlsEnabled: false,
              zoomGesturesEnabled: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 22,
                  color: McColors.inkSoft,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hotel.address,
                    style: McTextStyles.body,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'Google 지도 열기',
                  onPressed: () => _launchHotelMap(hotel),
                  style: IconButton.styleFrom(
                    backgroundColor: McColors.ink,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(42, 42),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 19),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaySummaryCard extends StatelessWidget {
  final PointHotel hotel;
  final int nights;
  final DateTime? checkIn;

  const _StaySummaryCard({
    required this.hotel,
    required this.nights,
    required this.checkIn,
  });

  @override
  Widget build(BuildContext context) {
    final checkInLabel =
        checkIn == null ? '모든 날짜' : DateFormat('M월 d일').format(checkIn!);
    final totalPoints = hotel.awardPointsForNights(nights);
    final totalCash = hotel.cashPerNightKrw * nights;
    final hasFreeNight =
        totalPoints < hotel.pointsPerNight * nights && nights >= 5;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: McColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasFreeNight
                      ? '$checkInLabel · $nights박 · 5박 리워드 반영'
                      : '$checkInLabel · $nights박',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                hotel.hostText,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              _ValueMetric(
                label: '포인트',
                value: NumberFormat('#,###').format(
                  totalPoints,
                ),
                suffix: 'pts',
              ),
              _ValueMetric(
                label: '현금가',
                value: NumberFormat('#,###').format(
                  totalCash,
                ),
                suffix: '원',
              ),
              _ValueMetric(
                label: '가치',
                value: hotel.krwPerPoint.toStringAsFixed(1),
                suffix: '원/pt',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValueMetric extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;

  const _ValueMetric({
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: McTextStyles.micro),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: McColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: ' $suffix',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointCalendar extends StatelessWidget {
  final PointHotel hotel;

  const _PointCalendar({required this.hotel});

  @override
  Widget build(BuildContext context) {
    final entries = _calendarItems(hotel);
    final bestPoints =
        entries.map((entry) => entry.points).reduce((a, b) => a < b ? a : b);
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final isBest = entry.points == bestPoints;
          return Container(
            width: 74,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isBest ? const Color(0xFFFFF1F2) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isBest ? const Color(0xFFF3A5AA) : McColors.line,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.topLabel,
                  style: McTextStyles.micro,
                ),
                const SizedBox(height: 4),
                Text(
                  entry.dayLabel,
                  style: const TextStyle(
                    color: McColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    NumberFormat('#,###').format(entry.points),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: entries.length,
      ),
    );
  }
}

List<_CalendarItemData> _calendarItems(PointHotel hotel) {
  if (hotel.calendarEntries.isNotEmpty) {
    return hotel.calendarEntries.map((entry) {
      final date = DateTime.tryParse(entry.date);
      return _CalendarItemData(
        topLabel: date == null ? entry.date : DateFormat('M/d').format(date),
        dayLabel: date == null ? '' : _weekdayLabel(date.weekday),
        points: entry.points,
      );
    }).toList(growable: false);
  }

  final now = DateTime.now();
  return List.generate(14, (index) {
    final day = now.add(Duration(days: index));
    return _CalendarItemData(
      topLabel: _weekdayLabel(day.weekday),
      dayLabel: '${day.day}',
      points: hotel.calendarPoints[index % hotel.calendarPoints.length],
    );
  });
}

class _CalendarItemData {
  final String topLabel;
  final String dayLabel;
  final int points;

  const _CalendarItemData({
    required this.topLabel,
    required this.dayLabel,
    required this.points,
  });
}

String _weekdayLabel(int weekday) {
  const labels = ['월', '화', '수', '목', '금', '토', '일'];
  return labels[(weekday - 1).clamp(0, labels.length - 1)];
}

class _ReviewBox extends StatelessWidget {
  final double rating;
  final int? reviewCount;

  const _ReviewBox({
    required this.rating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: McColors.line),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: McColors.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFACC15),
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              reviewCount == null
                  ? '위치와 객실 컨디션이 안정적이고, 포인트 차감 대비 체감 가치가 좋은 편입니다.'
                  : 'Marriott 투숙객 평점 기준 ${NumberFormat('#,###').format(reviewCount)}개의 후기가 반영되어 있습니다.',
              style: McTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenityGrid extends StatelessWidget {
  final List<PointHotelAmenity> amenities;

  const _AmenityGrid({required this.amenities});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 520
                ? 3
                : 2;
        final itemWidth = (constraints.maxWidth - 16 * (columns - 1)) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 18,
          children: [
            for (final amenity in amenities)
              SizedBox(
                width: itemWidth,
                child: _AmenityTile(amenity: amenity),
              ),
          ],
        );
      },
    );
  }
}

class _AmenityTile extends StatelessWidget {
  final PointHotelAmenity amenity;

  const _AmenityTile({required this.amenity});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Icon(
            _amenityIcon(amenity.title),
            color: McColors.inkSoft,
            size: 26,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      amenity.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: McColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (amenity.included) ...[
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 15,
                      color: McColors.inkSoft,
                    ),
                  ],
                ],
              ),
              if (amenity.subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  amenity.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: McColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

IconData _amenityIcon(String title) {
  final text = title.toLowerCase();
  if (text.contains('sustain')) return Icons.eco_outlined;
  if (text.contains('restaurant') || text.contains('레스토랑')) {
    return Icons.restaurant_outlined;
  }
  if (text.contains('gift')) return Icons.card_giftcard_outlined;
  if (text.contains('pool') || text.contains('수영장')) return Icons.pool_outlined;
  if (text.contains('whirlpool') ||
      text.contains('hot tub') ||
      text.contains('온수')) {
    return Icons.hot_tub_outlined;
  }
  if (text.contains('meeting') || text.contains('미팅')) {
    return Icons.meeting_room_outlined;
  }
  if (text.contains('spa') || text.contains('스파')) return Icons.spa_outlined;
  if (text.contains('fitness') || text.contains('피트니스')) {
    return Icons.fitness_center_outlined;
  }
  if (text.contains('laundry') || text.contains('세탁')) {
    return Icons.local_laundry_service_outlined;
  }
  if (text.contains('dry cleaning') || text.contains('드라이클리닝')) {
    return Icons.checkroom_outlined;
  }
  if (text.contains('wi-fi') ||
      text.contains('wifi') ||
      text.contains('wi') ||
      text.contains('와이파이')) {
    return Icons.wifi_outlined;
  }
  if (text.contains('mobile key') || text.contains('모바일 키')) {
    return Icons.key_outlined;
  }
  if (text.contains('breakfast') || text.contains('조식')) {
    return Icons.free_breakfast_outlined;
  }
  if (text.contains('room service') || text.contains('룸 서비스')) {
    return Icons.room_service_outlined;
  }
  if (text.contains('24')) return Icons.av_timer_outlined;
  if (text.contains('wake') || text.contains('모닝콜')) {
    return Icons.add_ic_call_outlined;
  }
  if (text.contains('turndown') || text.contains('턴다운')) {
    return Icons.bed_outlined;
  }
  if (text.contains('business') || text.contains('비즈니스')) {
    return Icons.business_center_outlined;
  }
  if (text.contains('bicycle') || text.contains('자전거')) {
    return Icons.directions_bike_outlined;
  }
  if (text.contains('kids') || text.contains('키즈')) {
    return Icons.family_restroom_outlined;
  }
  if (text.contains('club') ||
      text.contains('lounge') ||
      text.contains('라운지')) {
    return Icons.local_bar_outlined;
  }
  if (text.contains('service request') || text.contains('서비스 요청')) {
    return Icons.support_agent_outlined;
  }
  return Icons.check_circle_outline_rounded;
}

class _DetailInfoSection extends StatelessWidget {
  final PointHotelInfoSection section;

  const _DetailInfoSection({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: McTextStyles.sectionTitle.copyWith(
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: McColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (var index = 0; index < section.items.length; index++) ...[
                _InfoLine(item: section.items[index]),
                if (index != section.items.length - 1)
                  const Divider(height: 1, indent: 14, endIndent: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final PointHotelInfoItem item;

  const _InfoLine({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              item.title,
              style: McTextStyles.meta.copyWith(color: McColors.inkSoft),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.body,
              style: McTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}
