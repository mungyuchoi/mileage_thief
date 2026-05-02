import 'package:flutter/material.dart';

const String communityChatFloatingIconAsset = 'asset/icon/community_chat.png';

class CommunityChatFloatingButton extends StatelessWidget {
  const CommunityChatFloatingButton({
    super.key,
    required this.onPressed,
    required this.heroTag,
    this.tooltip = '채팅',
  });

  final VoidCallback onPressed;
  final Object heroTag;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      tooltip: tooltip,
      elevation: 8,
      backgroundColor: Colors.white.withValues(alpha: 0.90),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.92),
          width: 1.2,
        ),
      ),
      onPressed: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.asset(
          communityChatFloatingIconAsset,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
