import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../const/colors.dart';
import '../models/user_point_model.dart';
import '../services/user_point_service.dart';

class ProfilePointSummary extends StatefulWidget {
  const ProfilePointSummary({
    super.key,
    required this.uid,
    required this.userProfile,
    required this.onManage,
  });

  final String uid;
  final Map<String, dynamic> userProfile;
  final VoidCallback onManage;

  @override
  State<ProfilePointSummary> createState() => _ProfilePointSummaryState();
}

class _ProfilePointSummaryState extends State<ProfilePointSummary> {
  final UserPointService _service = UserPointService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserPointBalance>>(
      stream: _service.watchBalances(widget.uid),
      builder: (context, snapshot) {
        final balances = snapshot.data ?? const <UserPointBalance>[];
        final representatives = representativePointBalances(balances);
        final loading = snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '내 대표 포인트',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  _PointIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: '포인트 관리',
                    onTap: widget.onManage,
                  ),
                  const SizedBox(width: 8),
                  _PointIconButton(
                    icon: Icons.ios_share,
                    tooltip: '공유',
                    onTap: loading
                        ? null
                        : () => _share(representatives.values.toList()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: PointCategory.values.map((category) {
                  final balance = representatives[category];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: category == PointCategory.card ? 0 : 8,
                      ),
                      child: _PointSummaryTile(
                        category: category,
                        balance: balance,
                        loading: loading,
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (!loading && representatives.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '대표 포인트를 설정해보세요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _share(List<UserPointBalance> representatives) async {
    if (representatives.isEmpty) {
      Fluttertoast.showToast(msg: '대표 포인트를 먼저 설정해주세요.');
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _PointShareCaptureDialog(
          userProfile: widget.userProfile,
          representatives: representatives,
        );
      },
    );
  }
}

class ProfilePointShareCard extends StatelessWidget {
  const ProfilePointShareCard({
    super.key,
    required this.userProfile,
    required this.representatives,
  });

  final Map<String, dynamic> userProfile;
  final List<UserPointBalance> representatives;

  @override
  Widget build(BuildContext context) {
    final byCategory = {
      for (final balance in representatives) balance.category: balance,
    };
    final displayName = (userProfile['displayName'] ?? '사용자').toString();
    final photoURL = (userProfile['photoURL'] ?? '').toString();

    return Container(
      width: 390,
      color: Colors.white,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset(
                'asset/icon/milecatch_logo.png',
                width: 126,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'MileCatch',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: McColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '내 포인트',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: McColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFFF1F1F1),
                backgroundImage:
                    photoURL.isEmpty ? null : NetworkImage(photoURL),
                child: photoURL.isEmpty
                    ? const Icon(Icons.person, size: 32, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...PointCategory.values.map((category) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SharePointRow(
                category: category,
                balance: byCategory[category],
              ),
            );
          }),
          const SizedBox(height: 4),
          Container(
            height: 1,
            color: const Color(0xFFE8E3DC),
          ),
          const SizedBox(height: 14),
          const Text(
            'MileCatch',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black45,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class PointBrandLogo extends StatelessWidget {
  const PointBrandLogo({
    super.key,
    required this.assetPath,
    required this.size,
    this.category,
    this.fallbackAssetPath,
  });

  final String assetPath;
  final double size;
  final String? category;
  final String? fallbackAssetPath;

  @override
  Widget build(BuildContext context) {
    final icon = _fallbackIcon(category);
    final fallbackPath = fallbackAssetPath;
    final fallback = fallbackPath == null || fallbackPath.isEmpty
        ? icon
        : _buildAsset(fallbackPath, icon);
    final child = _buildAsset(assetPath, fallback);
    return SizedBox(width: size, height: size, child: Center(child: child));
  }

  Widget _buildAsset(String path, Widget fallback) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => fallback,
      );
    }
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _PointShareCaptureDialog extends StatefulWidget {
  const _PointShareCaptureDialog({
    required this.userProfile,
    required this.representatives,
  });

  final Map<String, dynamic> userProfile;
  final List<UserPointBalance> representatives;

  @override
  State<_PointShareCaptureDialog> createState() =>
      _PointShareCaptureDialogState();
}

class _PointShareCaptureDialogState extends State<_PointShareCaptureDialog> {
  final GlobalKey _captureKey = GlobalKey();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureAndShare());
  }

  Future<void> _captureAndShare() async {
    if (_started) return;
    _started = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      final bytes = await _captureImageBytes();
      if (bytes == null) {
        Fluttertoast.showToast(msg: '공유 이미지를 만들지 못했습니다.');
        return;
      }
      final file = await _writeTempImage(bytes);
      await SharePlus.instance.share(
        ShareParams(
          text: '마일캐치 내 포인트',
          files: [XFile(file.path)],
        ),
      );
    } catch (_) {
      Fluttertoast.showToast(msg: '공유 중 오류가 발생했습니다.');
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<Uint8List?> _captureImageBytes() async {
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<File> _writeTempImage(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final fileName =
        'milecatch_points_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';
    final file = File('${dir.path}/$fileName');
    return file.writeAsBytes(bytes, flush: true);
  }

  @override
  Widget build(BuildContext context) {
    final previewWidth = MediaQuery.of(context).size.width - 36;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: previewWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: RepaintBoundary(
                  key: _captureKey,
                  child: ProfilePointShareCard(
                    userProfile: widget.userProfile,
                    representatives: widget.representatives,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '공유 준비 중',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PointSummaryTile extends StatelessWidget {
  const _PointSummaryTile({
    required this.category,
    required this.balance,
    required this.loading,
  });

  final String category;
  final UserPointBalance? balance;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final item = balance;
    return Container(
      height: 104,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: McColors.line),
      ),
      child: loading
          ? const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _categoryIcon(category),
                      size: 15,
                      color: _categoryColor(category),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        PointCategory.label(category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _categoryColor(category),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (item == null)
                  Expanded(
                    child: Center(
                      child: Icon(
                        Icons.add_circle_outline,
                        size: 28,
                        color: Colors.grey[500],
                      ),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      PointBrandLogo(
                        assetPath: item.assetPath,
                        fallbackAssetPath: item.fallbackAssetPath,
                        size: 25,
                        category: item.category,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.brandName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _PointAmountText(
                      amount: item.balance,
                      label: item.pointLabel,
                      amountSize: 16,
                      labelSize: 12,
                      amountWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _SharePointRow extends StatelessWidget {
  const _SharePointRow({
    required this.category,
    required this.balance,
  });

  final String category;
  final UserPointBalance? balance;

  @override
  Widget build(BuildContext context) {
    final item = balance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _categorySoftColor(category),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _categoryLineColor(category)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: item == null
                ? Icon(_categoryIcon(category), color: _categoryColor(category))
                : PointBrandLogo(
                    assetPath: item.assetPath,
                    fallbackAssetPath: item.fallbackAssetPath,
                    size: 30,
                    category: item.category,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PointCategory.label(category),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _categoryColor(category),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item?.brandName ?? '미설정',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 138),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: item == null
                  ? const Text(
                      '-',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    )
                  : _PointAmountText(
                      amount: item.balance,
                      label: item.pointLabel,
                      amountSize: 20,
                      labelSize: 13,
                      amountWeight: FontWeight.w900,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointIconButton extends StatelessWidget {
  const _PointIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: onTap == null ? const Color(0xFFF3F3F3) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? Colors.black26 : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _PointAmountText extends StatelessWidget {
  const _PointAmountText({
    required this.amount,
    required this.label,
    required this.amountSize,
    required this.labelSize,
    required this.amountWeight,
  });

  final int amount;
  final String label;
  final double amountSize;
  final double labelSize;
  final FontWeight amountWeight;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      text: TextSpan(
        children: [
          TextSpan(
            text: _formatNumber(amount),
            style: TextStyle(
              fontSize: amountSize,
              fontWeight: amountWeight,
              color: Colors.black,
              height: 1,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: TextStyle(
              fontSize: labelSize,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _fallbackIcon(String? category) {
  return Icon(
    _categoryIcon(category ?? ''),
    color: _categoryColor(category ?? ''),
    size: 22,
  );
}

IconData _categoryIcon(String category) {
  switch (category) {
    case PointCategory.airline:
      return Icons.flight_takeoff_rounded;
    case PointCategory.hotel:
      return Icons.hotel_rounded;
    case PointCategory.card:
      return Icons.credit_card_rounded;
    default:
      return Icons.stars_rounded;
  }
}

Color _categoryColor(String category) {
  switch (category) {
    case PointCategory.airline:
      return const Color(0xFF1666EF);
    case PointCategory.hotel:
      return const Color(0xFF287A74);
    case PointCategory.card:
      return const Color(0xFFDC7606);
    default:
      return McColors.accent;
  }
}

Color _categorySoftColor(String category) {
  switch (category) {
    case PointCategory.airline:
      return const Color(0xFFEAF2FF);
    case PointCategory.hotel:
      return const Color(0xFFEAF6F4);
    case PointCategory.card:
      return const Color(0xFFFFF3E6);
    default:
      return McColors.accentSoft;
  }
}

Color _categoryLineColor(String category) {
  return _categoryColor(category).withValues(alpha: 0.18);
}

String _formatNumber(int value) => NumberFormat.decimalPattern().format(value);
