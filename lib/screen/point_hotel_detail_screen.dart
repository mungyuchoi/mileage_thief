import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
          const SizedBox(height: 18),
          _StaySummaryCard(
            hotel: hotel,
            nights: nights,
            checkIn: checkIn,
          ),
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
          const SizedBox(height: 22),
          Text(
            '편의시설',
            style: McTextStyles.sectionTitle.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amenity in hotel.amenities)
                Chip(
                  label: Text(amenity),
                  avatar: const Icon(Icons.check_rounded, size: 17),
                  backgroundColor: const Color(0xFFF7F7F8),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Reviews',
            style: McTextStyles.sectionTitle.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          _ReviewBox(rating: hotel.rating),
          const SizedBox(height: 90),
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
                  '$checkInLabel · $nights박',
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
                  hotel.pointsPerNight * nights,
                ),
                suffix: 'pts',
              ),
              _ValueMetric(
                label: '현금가',
                value: NumberFormat('#,###').format(
                  hotel.cashPerNightKrw * nights,
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
    final now = DateTime.now();
    final bestPoints = hotel.calendarPoints.reduce((a, b) => a < b ? a : b);
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final day = now.add(Duration(days: index));
          final points =
              hotel.calendarPoints[index % hotel.calendarPoints.length];
          final isBest = points == bestPoints;
          return Container(
            width: 68,
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
                  _weekdayLabel(day.weekday),
                  style: McTextStyles.micro,
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.day}',
                  style: const TextStyle(
                    color: McColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    NumberFormat('#,###').format(points),
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
        itemCount: 14,
      ),
    );
  }
}

String _weekdayLabel(int weekday) {
  const labels = ['월', '화', '수', '목', '금', '토', '일'];
  return labels[(weekday - 1).clamp(0, labels.length - 1)];
}

class _ReviewBox extends StatelessWidget {
  final double rating;

  const _ReviewBox({required this.rating});

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
          const Expanded(
            child: Text(
              '위치와 객실 컨디션이 안정적이고, 포인트 차감 대비 체감 가치가 좋은 편입니다.',
              style: McTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}
