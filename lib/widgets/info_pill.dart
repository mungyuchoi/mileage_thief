import 'package:flutter/material.dart';

class InfoPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool filled;
  final Color? fillColor;

  const InfoPill({
    super.key,
    required this.text,
    this.icon,
    this.filled = false,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveFill =
        fillColor ?? (filled ? const Color(0xFF74512D) : const Color(0x1174512D));
    final Color textColor =
        (fillColor != null || filled) ? Colors.white : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveFill,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}


