import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../models/point_hotel_model.dart';
import '../services/point_hotel_like_service.dart';

class PointHotelFavoriteButton extends StatelessWidget {
  final PointHotel hotel;
  final double size;
  final Color color;
  final Color selectedColor;
  final List<Shadow>? shadows;
  final EdgeInsetsGeometry padding;
  final double minTouchSize;
  final double? splashRadius;

  const PointHotelFavoriteButton({
    super.key,
    required this.hotel,
    this.size = 30,
    this.color = Colors.white,
    Color? selectedColor,
    this.shadows,
    this.padding = EdgeInsets.zero,
    this.minTouchSize = 40,
    this.splashRadius,
  }) : selectedColor = selectedColor ?? color;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || hotel.id.isEmpty) {
      return _buildButton(
        liked: false,
        onPressed: () {
          Fluttertoast.showToast(msg: '로그인이 필요합니다.');
        },
      );
    }

    return StreamBuilder<bool>(
      stream: PointHotelLikeService.instance.watchLiked(
        uid: user.uid,
        hotelId: hotel.id,
      ),
      builder: (context, snapshot) {
        final liked = snapshot.data ?? false;
        return _buildButton(
          liked: liked,
          onPressed: () async {
            try {
              await PointHotelLikeService.instance.setLiked(
                uid: user.uid,
                hotel: hotel,
                liked: !liked,
              );
            } catch (_) {
              Fluttertoast.showToast(msg: '호텔 좋아요를 저장하지 못했습니다.');
            }
          },
        );
      },
    );
  }

  Widget _buildButton({
    required bool liked,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: liked ? '호텔 좋아요 해제' : '호텔 좋아요',
      onPressed: onPressed,
      padding: padding,
      splashRadius: splashRadius,
      constraints: BoxConstraints(
        minWidth: minTouchSize,
        minHeight: minTouchSize,
      ),
      icon: Icon(
        liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: liked ? selectedColor : color,
        size: size,
        shadows: shadows,
      ),
    );
  }
}
