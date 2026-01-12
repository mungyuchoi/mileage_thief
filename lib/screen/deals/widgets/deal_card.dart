import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/deal_model.dart';
import '../../../utils/deal_image_utils.dart';
import '../../../milecatch_rich_editor/src/constants/color_constants.dart';
import 'price_graph_dialog.dart';

class DealCard extends StatelessWidget {
  static const String _kPriceGraphDialogDontShowKey = 'deals_price_graph_dialog_dont_show';
  
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
    final firstDate = deal.availableDates.isNotEmpty ? deal.availableDates.first : null;
    
    // 디버깅: 실제 데이터 확인
    print('=== Deal Debug Info ===');
    print('Deal ID: ${deal.dealId}');
    print('Agency: ${deal.agency} (${deal.agencyCode})');
    print('Trip Type: ${deal.tripType}');
    print('Inbound: ${deal.inbound?.toString() ?? "NULL"}');
    print('Available Dates count: ${deal.availableDates.length}');
    if (deal.availableDates.isNotEmpty) {
      print('First available date - departure: ${firstDate?.departure}, return: ${firstDate?.returnDate}');
      print('First available date - departureDate: ${firstDate?.departureDate}, returnDateStr: ${firstDate?.returnDateStr}');
    }
    print('Date Ranges count: ${deal.dateRanges.length}');
    if (deal.dateRanges.isNotEmpty) {
      print('First date range - start: ${deal.dateRanges.first.start}, end: ${deal.dateRanges.first.end}');
    }
    print('Supply dates - start: ${deal.supplyStartDate}, end: ${deal.supplyEndDate}');
    
    // 특가 항공권 여행사 목록 (출발일만 표시해야 하는 여행사)
    const specialDealAgencies = ['ttangdeal', 'yellowtour'];
    final isSpecialDealAgency = specialDealAgencies.contains(deal.agencyCode);
    
    // 특가 항공권 처리 로직:
    // 특가 항공권 여행사는 항상 출발일만 표시 (available_dates가 비어있을 때만 편도로 처리)
    // 일반 여행사의 경우: inbound가 있고 available_dates에 returnDateStr이 있으면 왕복
    final hasActualReturnDate = firstDate?.returnDateStr != null && 
                                 firstDate?.returnDateStr?.isNotEmpty == true;
    
    // 특가 항공권 여행사의 경우: available_dates가 비어있으면 항상 편도로 처리
    // 일반 여행사의 경우: inbound가 있고 returnDateStr이 있으면 왕복
    final shouldShowRoundTrip = isSpecialDealAgency 
        ? false  // 특가 항공권 여행사는 항상 편도로 처리
        : ((deal.tripType == 'VV' || deal.tripType == 'RT') && deal.inbound != null && hasActualReturnDate);
    
    final isRoundTrip = shouldShowRoundTrip;
    
    print('Is Special Deal Agency: $isSpecialDealAgency');
    print('Has Actual Return Date: $hasActualReturnDate');
    print('Is Round Trip: $isRoundTrip');
    print('========================');
    
    // availableDates가 비어있을 때 date_ranges나 supply_start_date/supply_end_date로 날짜 생성
    String? fallbackDepartureDate;
    String? fallbackDepartureDateStr;
    String? fallbackReturnDate;
    String? fallbackReturnDateStr;
    
    if (firstDate == null) {
      // date_ranges 우선 사용
      if (deal.dateRanges.isNotEmpty) {
        final dateRange = deal.dateRanges.first;
        try {
          final startDate = DateTime.parse(dateRange.start);
          final endDate = DateTime.parse(dateRange.end);
          final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
          
          fallbackDepartureDate = '${startDate.month}-${startDate.day.toString().padLeft(2, '0')}(${weekdays[startDate.weekday - 1]})';
          fallbackDepartureDateStr = dateRange.start;
          
          // date_ranges의 end는 공급 종료일일 수 있으므로, inbound가 있을 때만 귀국일로 사용
          if (isRoundTrip && deal.inbound != null) {
            fallbackReturnDate = '${endDate.month}-${endDate.day.toString().padLeft(2, '0')}(${weekdays[endDate.weekday - 1]})';
            fallbackReturnDateStr = dateRange.end;
          }
        } catch (e) {
          // 파싱 실패 시 무시
        }
      }
      
      // date_ranges도 없으면 supply_start_date/supply_end_date 사용
      if (fallbackDepartureDateStr == null && deal.supplyStartDate.isNotEmpty) {
        try {
          if (deal.supplyStartDate.length == 8) {
            final year = int.parse(deal.supplyStartDate.substring(0, 4));
            final month = int.parse(deal.supplyStartDate.substring(4, 6));
            final day = int.parse(deal.supplyStartDate.substring(6, 8));
            final startDate = DateTime(year, month, day);
            final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
            
            fallbackDepartureDate = '${startDate.month}-${startDate.day.toString().padLeft(2, '0')}(${weekdays[startDate.weekday - 1]})';
            fallbackDepartureDateStr = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          }
          
          if (isRoundTrip && deal.supplyEndDate.isNotEmpty && deal.supplyEndDate.length == 8) {
            final year = int.parse(deal.supplyEndDate.substring(0, 4));
            final month = int.parse(deal.supplyEndDate.substring(4, 6));
            final day = int.parse(deal.supplyEndDate.substring(6, 8));
            final endDate = DateTime(year, month, day);
            final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
            
            fallbackReturnDate = '${endDate.month}-${endDate.day.toString().padLeft(2, '0')}(${weekdays[endDate.weekday - 1]})';
            fallbackReturnDateStr = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          }
        } catch (e) {
          // 파싱 실패 시 무시
        }
      }
    }

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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFlightRow(
                            origin: deal.originCity,
                            originAirport: deal.originAirport,
                            dest: deal.destCity,
                            destAirport: deal.destAirport,
                            flightInfo: deal.outbound,
                            date: firstDate?.departure ?? fallbackDepartureDate,
                            dateStr: firstDate?.departureDate ?? fallbackDepartureDateStr,
                            duration: deal.flightDuration,
                            isDirect: deal.isDirect,
                          ),
                          // 편도인 경우 출발 가능 기간 표시
                          if (!isRoundTrip && (deal.dateRanges.isNotEmpty || (deal.supplyStartDate.isNotEmpty && deal.supplyEndDate.isNotEmpty)))
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 0),
                              child: _buildSupplyPeriodText(deal),
                            ),
                        ],
                      ),
                      // 오는 편 (왕복인 경우, inbound 정보가 반드시 있어야 함)
                      if (isRoundTrip && deal.inbound != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildFlightRow(
                            origin: deal.destCity,
                            originAirport: deal.destAirport,
                            dest: deal.originCity,
                            destAirport: deal.originAirport,
                            flightInfo: deal.inbound,
                            date: firstDate?.returnDate ?? fallbackReturnDate,
                            dateStr: firstDate?.returnDateStr ?? fallbackReturnDateStr,
                            duration: deal.inbound?.durationText ?? deal.flightDuration,
                            isDirect: deal.isDirect,
                          ),
                        ),
                      const SizedBox(height: 12),
                      // 여행 기간 및 직항 표시
                      Row(
                        children: [
                          // 편도인 경우 여행 기간 표시하지 않음
                          if (isRoundTrip)
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
                          if (isRoundTrip)
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
                      // 가격
                      Text(
                        deal.priceDisplay.isNotEmpty 
                            ? deal.priceDisplay 
                            : '${deal.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                        style: TextStyle(
                          fontSize: 16,
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
                    // 가격그래프 버튼 (할인율이 있을 때만 표시)
                    if (discountPercent != null && discountPercent < 0)
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
                    if (discountPercent != null && discountPercent < 0)
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

  Future<void> _handlePriceGraph(BuildContext context) async {
    final ok = await _confirmAndSpendPeanutsForPriceGraph(context);
    if (ok) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => PriceGraphDialog(deal: deal),
        );
      }
    }
  }

  Future<bool> _confirmAndSpendPeanutsForPriceGraph(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Fluttertoast.showToast(msg: '땅콩이 모자랍니다.');
        return false;
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final int peanuts = (doc.data()?['peanutCount'] as num?)?.toInt() ?? 0;
      if (peanuts < 5) {
        Fluttertoast.showToast(msg: '땅콩이 모자랍니다.');
        return false;
      }

      // "다시 보지 않기"가 설정되어 있는지 확인
      final prefs = await SharedPreferences.getInstance();
      final bool dontShowDialog =
          prefs.getBool(_kPriceGraphDialogDontShowKey) ?? false;

      bool proceed = false;
      if (!dontShowDialog) {
        bool localDontShow = false;
        final bool? dontShowNext = await showDialog<bool>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  backgroundColor: Colors.white,
                  title: const Text(
                    '안내',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '가격 그래프를 이용할 때마다 땅콩 5개가 소모됩니다.',
                        style: TextStyle(color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '다시 보지 않기',
                          style: TextStyle(color: Colors.black),
                        ),
                        value: localDontShow,
                        activeColor: const Color(0xFF74512D),
                        onChanged: (v) {
                          setState(() {
                            localDontShow = v ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text(
                        '취소',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(localDontShow),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );

        if (dontShowNext == null) {
          return false;
        }

        proceed = true;

        if (dontShowNext == true) {
          await prefs.setBool(_kPriceGraphDialogDontShowKey, true);
        }
      } else {
        proceed = true;
      }

      if (!proceed) return false;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'peanutCount': FieldValue.increment(-5)});

      Fluttertoast.showToast(msg: '땅콩 5개가 사용되었습니다.');
      return true;
    } catch (_) {
      Fluttertoast.showToast(msg: '처리 중 오류가 발생했습니다.');
      return false;
    }
  }

  Widget _buildSupplyPeriodText(DealModel deal) {
    String? startDateStr;
    String? endDateStr;
    
    // date_ranges 우선 사용
    if (deal.dateRanges.isNotEmpty) {
      final dateRange = deal.dateRanges.first;
      startDateStr = dateRange.start;
      endDateStr = dateRange.end;
    } 
    // date_ranges가 없으면 supply_start_date/supply_end_date 사용
    else if (deal.supplyStartDate.isNotEmpty && deal.supplyEndDate.isNotEmpty) {
      try {
        if (deal.supplyStartDate.length == 8 && deal.supplyEndDate.length == 8) {
          final startYear = deal.supplyStartDate.substring(0, 4);
          final startMonth = deal.supplyStartDate.substring(4, 6);
          final startDay = deal.supplyStartDate.substring(6, 8);
          final endYear = deal.supplyEndDate.substring(0, 4);
          final endMonth = deal.supplyEndDate.substring(4, 6);
          final endDay = deal.supplyEndDate.substring(6, 8);
          
          startDateStr = '$startYear-$startMonth-$startDay';
          endDateStr = '$endYear-$endMonth-$endDay';
        }
      } catch (e) {
        // 파싱 실패 시 무시
      }
    }
    
    if (startDateStr == null || endDateStr == null) {
      return const SizedBox.shrink();
    }
    
    // 날짜 포맷팅 (예: "2026-01-13" -> "1/13")
    String formatDate(String dateStr) {
      try {
        final dateTime = DateTime.parse(dateStr);
        return '${dateTime.month}/${dateTime.day}';
      } catch (e) {
        return dateStr;
      }
    }
    
    final formattedStart = formatDate(startDateStr);
    final formattedEnd = formatDate(endDateStr);
    
    return Text(
      '출발 가능: $formattedStart ~ $formattedEnd',
      style: const TextStyle(
        fontSize: 11,
        color: Colors.black45,
      ),
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

