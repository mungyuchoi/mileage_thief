import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final isPriceDown = discountPercent != null && discountPercent < 0;

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleBooking(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 번호, 목적지, 국기
                Row(
                  children: [
                    // 번호
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ColorConstants.milecatchBrown.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: ColorConstants.milecatchBrown,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 국기
                    DealImageUtils.getCountryFlag(deal.countryCode, width: 24, height: 24),
                    const SizedBox(width: 8),
                    // 목적지
                    Expanded(
                      child: Text(
                        deal.destCity,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    // 가격 변동 아이콘
                    if (isPriceDown)
                      Icon(
                        Icons.arrow_downward,
                        color: Colors.red[400],
                        size: 20,
                      )
                    else if (discountPercent != null && discountPercent > 0)
                      Icon(
                        Icons.arrow_upward,
                        color: Colors.blue[400],
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // 여행 기간 및 날짜
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ColorConstants.milecatchBrown.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${deal.travelDays}일',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ColorConstants.milecatchBrown,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (deal.availableDates.isNotEmpty)
                      Expanded(
                        child: Text(
                          '${deal.availableDates.first.departure} - ${deal.availableDates.first.returnDate}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // 가격 및 할인율
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 할인율
                    if (discountPercent != null && discountPercent < 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          '${discountPercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      )
                    else
                      const SizedBox(),
                    // 가격
                    Text(
                      deal.priceDisplay.isNotEmpty 
                          ? deal.priceDisplay 
                          : '${deal.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ColorConstants.milecatchBrown,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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

