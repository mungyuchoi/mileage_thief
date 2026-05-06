import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/shopping_mall_model.dart';
import '../services/shopping_mall_service.dart';

class ShoppingMallGrid extends StatefulWidget {
  const ShoppingMallGrid({super.key});

  @override
  State<ShoppingMallGrid> createState() => _ShoppingMallGridState();
}

class _ShoppingMallGridState extends State<ShoppingMallGrid> {
  final List<ShoppingMall> _malls = ShoppingMall.getShoppingMalls();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 1초마다 카운트다운 업데이트
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleMallTap(ShoppingMall mall) async {
    await _handleShoppingMallTap(mall, () => mounted);
  }

  @override
  Widget build(BuildContext context) {
    // 타이머에 의해 1초마다 rebuild되므로 각 아이템도 자동으로 업데이트됨
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _malls.length,
      itemBuilder: (context, index) {
        return _ShoppingMallItem(
          key: ValueKey(_malls[index].id),
          mall: _malls[index],
          onTap: () => _handleMallTap(_malls[index]),
        );
      },
    );
  }
}

class ShoppingMallHorizontalScroll extends StatefulWidget {
  final List<String> leadingMallIds;
  final EdgeInsetsGeometry padding;
  final double itemWidth;
  final double height;

  const ShoppingMallHorizontalScroll({
    super.key,
    this.leadingMallIds = const [],
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.itemWidth = 104,
    this.height = 132,
  });

  @override
  State<ShoppingMallHorizontalScroll> createState() =>
      _ShoppingMallHorizontalScrollState();
}

class _ShoppingMallHorizontalScrollState
    extends State<ShoppingMallHorizontalScroll> {
  late final List<ShoppingMall> _malls;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _malls = _orderedShoppingMalls(widget.leadingMallIds);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleMallTap(ShoppingMall mall) async {
    await _handleShoppingMallTap(mall, () => mounted);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        itemCount: _malls.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final mall = _malls[index];
          return SizedBox(
            width: widget.itemWidth,
            child: _ShoppingMallItem(
              key: ValueKey('horizontal_${mall.id}'),
              mall: mall,
              onTap: () => _handleMallTap(mall),
            ),
          );
        },
      ),
    );
  }
}

List<ShoppingMall> _orderedShoppingMalls(List<String> leadingMallIds) {
  final malls = ShoppingMall.getShoppingMalls();
  if (leadingMallIds.isEmpty) return malls;

  final leading = <ShoppingMall>[];
  final usedIds = <String>{};
  for (final id in leadingMallIds) {
    for (final mall in malls) {
      if (mall.id == id && usedIds.add(mall.id)) {
        leading.add(mall);
        break;
      }
    }
  }

  return [
    ...leading,
    ...malls.where((mall) => !usedIds.contains(mall.id)),
  ];
}

Future<void> _handleShoppingMallTap(
  ShoppingMall mall,
  bool Function() isMounted,
) async {
  // 카운트다운이 완료되었으면 땅콩 적립
  final earnedPeanuts = await ShoppingMallService.handleMallClick(mall.id);

  // 토스트 먼저 표시
  if (earnedPeanuts && isMounted()) {
    Fluttertoast.showToast(
      msg: '땅콩 ${mall.peanutReward}개를 모았습니다.',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.grey[800],
      textColor: Colors.white,
      fontSize: 16.0,
    );
  } else if (isMounted()) {
    final remaining = await ShoppingMallService.getRemainingTime(mall.id);
    if (remaining != null && remaining.inHours < 24) {
      final timeStr = ShoppingMallService.formatTime(remaining);
      Fluttertoast.showToast(
        msg: '땅콩 획득까지 $timeStr 남았습니다',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.grey[800],
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  // 토스트가 표시될 시간을 주기 위해 짧은 딜레이
  await Future.delayed(const Duration(milliseconds: 300));

  // 외부 브라우저로 이동
  if (!isMounted()) return;
  try {
    final uri = Uri.parse(mall.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('URL을 열 수 없습니다');
    }
  } catch (e) {
    if (isMounted()) {
      Fluttertoast.showToast(
        msg: '링크를 열 수 없습니다',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }
}

class _ShoppingMallItem extends StatefulWidget {
  final ShoppingMall mall;
  final VoidCallback onTap;

  const _ShoppingMallItem({
    super.key,
    required this.mall,
    required this.onTap,
  });

  @override
  State<_ShoppingMallItem> createState() => _ShoppingMallItemState();
}

class _ShoppingMallItemState extends State<_ShoppingMallItem> {
  String _timeText = '24:00';
  bool _isReady = true;

  @override
  void initState() {
    super.initState();
    _updateTime();
  }

  Future<void> _updateTime() async {
    final remaining =
        await ShoppingMallService.getRemainingTime(widget.mall.id);
    final isComplete =
        await ShoppingMallService.isCountdownComplete(widget.mall.id);

    if (mounted) {
      setState(() {
        if (remaining != null && !isComplete) {
          _timeText = ShoppingMallService.formatTime(remaining);
          _isReady = false;
        } else {
          _timeText = '24:00';
          _isReady = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 부모 위젯의 타이머에 의해 1초마다 rebuild되므로 시간 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTime();
    });

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.black12,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 아이콘
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  widget.mall.iconPath,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.shopping_bag, size: 32),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 이름
            Text(
              widget.mall.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // 시간
            Text(
              _timeText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _isReady ? Colors.green[600] : Colors.orange[600],
              ),
            ),
            const SizedBox(height: 2),
            // 땅콩+
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '땅콩',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '+${widget.mall.peanutReward}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
