import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../models/deal_model.dart';
import '../../../utils/deal_image_utils.dart';
import '../../../milecatch_rich_editor/src/constants/color_constants.dart';

class DealCard extends StatelessWidget {
  final DealModel deal;
  final int index;

  const DealCard({
    super.key,
    required this.deal,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final discountPercent = deal.priceChangePercent ?? deal.discountPercent;
    final countryCode = DealImageUtils.inferCountryCode(
      countryCode: deal.countryCode,
      airportCode: deal.destAirport,
      cityName: deal.destCity,
    );
    final isRoundTrip = deal.tripType == 'VV' || deal.tripType == 'RT';
    final firstDate = deal.availableDates.isNotEmpty ? deal.availableDates.first : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 첫 번째 줄: 항공사 로고 + 비행 정보
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽: 항공사 로고 및 이름
                Column(
                  children: [
                    DealImageUtils.getAirlineLogo(
                      deal.airlineCode,
                      width: 32,
                      height: 32,
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 50,
                      child: Text(
                        deal.airlineName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // 중앙: 비행 정보 (우측까지 확장)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 가는 편
                      _buildFlightRow(
                        origin: deal.originCity,
                        originAirport: deal.originAirport,
                        dest: deal.destCity,
                        destAirport: deal.destAirport,
                        flightInfo: deal.outbound,
                        date: firstDate?.departure,
                        dateStr: firstDate?.departureDate,
                        duration: deal.flightDuration,
                        isDirect: deal.isDirect,
                      ),
                      // 오는 편 (왕복인 경우)
                      if (isRoundTrip && deal.inbound != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildFlightRow(
                            origin: deal.destCity,
                            originAirport: deal.destAirport,
                            dest: deal.originCity,
                            destAirport: deal.originAirport,
                            flightInfo: deal.inbound,
                            date: firstDate?.returnDate,
                            dateStr: firstDate?.returnDateStr,
                            duration: deal.inbound?.durationText ?? deal.flightDuration,
                            isDirect: deal.isDirect,
                          ),
                        ),
                      const SizedBox(height: 12),
                      // 여행 기간 및 직항 표시
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ColorConstants.milecatchBrown.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${deal.travelDays}박 ${deal.travelDays + 1}일',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ColorConstants.milecatchBrown,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              deal.isDirect ? '직항' : '경유 ${deal.viaCount}회',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isRoundTrip ? '왕복' : '편도',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 두 번째 줄: 여행사 로고 + 가격 + 예약 버튼
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 왼쪽: 여행사 로고 및 이름
                Column(
                  children: [
                    DealImageUtils.getAgencyLogo(
                      deal.agencyCode,
                      width: 32,
                      height: 32,
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 50,
                      child: Text(
                        deal.agency,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // 중앙: 가격 정보
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 할인율
                      if (discountPercent != null && discountPercent < 0)
                        Container(
                          margin: const EdgeInsets.only(right: 8, bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${discountPercent.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      // 가격
                      Text(
                        deal.priceDisplay.isNotEmpty 
                            ? deal.priceDisplay 
                            : '${deal.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 오른쪽: 버튼들 (수평 배치)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 가격그래프 버튼
                    ElevatedButton(
                      onPressed: () => _handlePriceGraph(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Text(
                        '가격그래프',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // 예약하기 버튼
                    ElevatedButton(
                      onPressed: () => _handleBooking(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Text(
                        '예약가능',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightRow({
    required String origin,
    required String originAirport,
    required String dest,
    required String destAirport,
    FlightInfo? flightInfo,
    String? date,
    String? dateStr,
    required String duration,
    required bool isDirect,
  }) {
    final departureTime = flightInfo?.departureTime ?? '';
    final arrivalTime = flightInfo?.arrivalTime ?? '';
    
    // 날짜 파싱 (예: "1/22(목)" -> "01-22(목)")
    String formattedDate = date ?? '';
    if (dateStr != null) {
      try {
        final dateTime = DateTime.parse(dateStr);
        final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
        formattedDate = '${dateTime.month}-${dateTime.day.toString().padLeft(2, '0')}(${weekdays[dateTime.weekday - 1]})';
      } catch (e) {
        formattedDate = date ?? '';
      }
    }

    return Row(
      children: [
        // 출발지
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                origin,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                formattedDate,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              if (departureTime.isNotEmpty)
                Text(
                  departureTime,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
            ],
          ),
        ),
        // 비행 시간 및 화살표
        Column(
          children: [
            Text(
              duration,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 30,
                  height: 1,
                  color: Colors.grey[400],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.flight,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
                Container(
                  width: 30,
                  height: 1,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
        // 도착지
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dest,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.right,
              ),
              Text(
                formattedDate,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.right,
              ),
              if (arrivalTime.isNotEmpty)
                Text(
                  arrivalTime,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.right,
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _handlePriceGraph(BuildContext context) {
    Fluttertoast.showToast(
      msg: "기능 준비중입니다.",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.grey[800],
      textColor: Colors.white,
    );
  }

  void _handleBooking(BuildContext context) async {
    try {
      final url = Uri.parse(deal.bookingUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('예약 페이지를 열 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }
}

