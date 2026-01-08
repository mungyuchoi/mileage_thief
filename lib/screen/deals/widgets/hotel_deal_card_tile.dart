import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/hotel_deal_card_model.dart';
import '../../../milecatch_rich_editor/src/constants/color_constants.dart';

class HotelDealCardTile extends StatelessWidget {
  final HotelDealCardModel deal;
  final bool isSaved;
  final VoidCallback? onToggleSaved;
  final VoidCallback onTap;

  const HotelDealCardTile({
    super.key,
    required this.deal,
    required this.isSaved,
    required this.onToggleSaved,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('#,###');
    final priceText = '${number.format(deal.totalPrice)}원';

    return SizedBox(
      width: 210,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 130,
                        width: double.infinity,
                        child: Image.network(
                          deal.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined, color: Colors.black38),
                            ),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ColorConstants.milecatchBrown,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _HeartButton(
                          isSaved: isSaved,
                          onPressed: onToggleSaved,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Text(
                    deal.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        deal.reviewScore > 0 ? deal.reviewScore.toStringAsFixed(1) : '-',
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        deal.reviewCount > 0 ? '(${number.format(deal.reviewCount)})' : '',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const Spacer(),
                      if (deal.hasFreeCancellation)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '무료취소',
                            style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (deal.discountPct > 0)
                        Text(
                          '${deal.discountPct}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.red[600],
                          ),
                        ),
                      if (deal.discountPct > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          priceText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  final bool isSaved;
  final VoidCallback? onPressed;

  const _HeartButton({
    required this.isSaved,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.25),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            isSaved ? Icons.favorite : Icons.favorite_border,
            size: 18,
            color: isSaved ? Colors.red[300] : Colors.white,
          ),
        ),
      ),
    );
  }
}


