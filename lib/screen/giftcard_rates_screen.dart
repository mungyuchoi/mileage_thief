import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'branch/branch_detail_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

// 추천 대시보드 땅콩 안내 다이얼로그 "다시 보지 않기" 플래그
const String _kRecommendPeanutDialogDontShowKey =
    'giftcard_recommend_peanut_dialog_dont_show';

/// 추천 대시보드용 상품권 선택 다이얼로그
Future<List<String>?> _showGiftcardSelectDialog(BuildContext context) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('giftcards')
        .orderBy('sortOrder', descending: false)
        .get();

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
        snap.docs;
    if (docs.isEmpty) return const <String>[];

    final List<String> ids = docs.map((d) => d.id).toList();
    final Map<String, String> names = {
      for (final d in docs)
        d.id: (d.data()['name'] as String?) ?? d.id.toUpperCase()
    };

    // 기본: 아무것도 선택되지 않은 상태
    final Set<String> selected = <String>{};

    final List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
            return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              scrollable: false,
              backgroundColor: Colors.white,
              title: const Text(
                '상품권 선택',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '추천을 보고 싶은 상품권을 선택해주세요.',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 260,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final id in ids)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                names[id] ?? id,
                                style: const TextStyle(color: Colors.black),
                              ),
                              value: selected.contains(id),
                              activeColor: const Color(0xFF74512D),
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    selected.add(id);
                                  } else {
                                    selected.remove(id);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '선택한 상품권: ${selected.length}개 · 예상 땅콩 소모: ${selected.length * 3}개',
                        style: const TextStyle(
                          color: Color(0xFF74512D),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
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
                  onPressed: () {
                    if (selected.isEmpty) {
                      Fluttertoast.showToast(
                          msg: '최소 1개 이상의 상품권을 선택해주세요.');
                      return;
                    }
                    Navigator.of(context).pop(selected.toList());
                  },
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

    return result;
  } catch (_) {
    Fluttertoast.showToast(msg: '상품권 목록을 불러오지 못했습니다.');
    return null;
  }
}

/// 추천 대시보드 진입 전 땅콩 20개 확인 및 차감
Future<bool> _confirmAndSpendPeanutsForRecommend(
    BuildContext context, {
  int amount = 20,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(msg: '땅콩이 부족합니다.');
      return false;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final int peanuts =
        (doc.data()?['peanutCount'] as num?)?.toInt() ?? 0;
    if (peanuts < amount) {
      Fluttertoast.showToast(msg: '땅콩이 부족합니다.');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final bool dontShowDialog =
        prefs.getBool(_kRecommendPeanutDialogDontShowKey) ?? false;

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
                  '추천 대시보드',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '해당 기능을 사용할 때마다 땅콩 $amount개가 소모됩니다.',
                      style:
                          const TextStyle(color: Colors.black, fontSize: 14),
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
                    onPressed: () =>
                        Navigator.of(context).pop(null),
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
        // 취소
        return false;
      }

      proceed = true;
      if (dontShowNext == true) {
        await prefs.setBool(
            _kRecommendPeanutDialogDontShowKey, true);
      }
    } else {
      proceed = true;
    }

    if (!proceed) return false;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'peanutCount': FieldValue.increment(-amount)});

    Fluttertoast.showToast(msg: '땅콩 $amount개가 사용되었습니다.');
    return true;
  } catch (_) {
    Fluttertoast.showToast(msg: '처리 중 오류가 발생했습니다.');
    return false;
  }
}

// 액면가(faceValue) 기준으로 퍼센트 계산 (기본 10만 원)
double? _calcRateFromPrice(num? price, {num faceValue = 100000}) {
  if (price == null) return null;
  final double face = faceValue.toDouble();
  if (face == 0) return null;
  final double p = price.toDouble();
  return ((face - p) / face) * 100.0;
}

/// 시세 카드에서 사용하는 설명 아이콘 라벨
class _RateLabel extends StatelessWidget {
  final String label;
  final String description;

  const _RateLabel({required this.label, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Colors.white,
                title: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(
                  description,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          child: Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x1174512D),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '!',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF74512D),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 상품권 탭 > "시세" 탭 진입용 메인 위젯
/// 1단계: giftcards 컬렉션 기반 브랜드별 요약 시세 목록
class GiftcardRatesTab extends StatelessWidget {
  const GiftcardRatesTab({super.key});

  NumberFormat get _won => NumberFormat('#,###');

  String _fmtPrice(num? v) => v == null ? '-' : '${_won.format(v)}원';

  /// giftcardId -> asset 경로 매핑
  String? _assetForGiftcard(String id) {
    switch (id) {
      case 'costco':
        return 'asset/img/costco.png';
      case 'eland':
        return 'asset/img/eland.png';
      case 'galleria':
        return 'asset/img/galleria.png';
      case 'hyundai':
        return 'asset/img/hyundai.png';
      case 'lotte':
        return 'asset/img/lotte.png';
      case 'samsung':
        return 'asset/img/samsung.png';
      case 'shinsegae':
        return 'asset/img/shinsegae.png';
      // 금강/농협/AK/CJ 개별 아이콘
      case 'kumkang':
        return 'asset/img/kumkang.png';
      case 'nh':
      case 'nonghyup':
      case '농협':
        return 'asset/img/nh.jpg';
      case 'ak':
        return 'asset/img/ak.jpg';
      case 'cj':
      case 'cjgift':
        return 'asset/img/cj.png';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('giftcards')
          .orderBy('sortOrder', descending: false)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return const Center(child: Text('시세를 불러오지 못했습니다.'));
          }
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('등록된 상품권이 없습니다.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 1,
          separatorBuilder: (context, index) =>
              index == 0 ? const SizedBox(height: 16) : const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _RecommendEntryCard();
            }

            final doc = docs[index - 1];
            final data = doc.data();
            final giftcardId = doc.id;
            final name = (data['name'] as String?) ?? giftcardId;
            // Firestore에 logoUrl 이 있을 수도 있고, asset 으로만 관리할 수도 있음.
            // 우선 giftcardId 기준 asset 매핑을 시도하고, 없으면 앱 아이콘으로 대체.
            final assetPath =
                _assetForGiftcard(giftcardId) ?? 'asset/img/app_icon.png';
            final bool isNhLogo =
                giftcardId == 'nh' || giftcardId == 'nonghyup' || giftcardId == '농협';
            final logoUrl = data['logoUrl'] as String?;

            final num? bestSellPrice = data['bestSellPrice'] as num?;
            final num? worstSellPrice = data['worstSellPrice'] as num?;
            final num? bestBuyPrice = data['bestBuyPrice'] as num?;
            final num? worstBuyPrice = data['worstBuyPrice'] as num?;

            final double? bestSellRate = _calcRateFromPrice(bestSellPrice);
            final double? worstSellRate = _calcRateFromPrice(worstSellPrice);
            final double? bestBuyRate = _calcRateFromPrice(bestBuyPrice);
            final double? worstBuyRate = _calcRateFromPrice(worstBuyPrice);

            return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GiftcardBrandRatesPage(
                      giftcardId: giftcardId,
                      giftcardName: name,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (assetPath.isNotEmpty || (logoUrl != null && logoUrl.isNotEmpty)) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 40,
                          height: 40,
                          color: Colors.white,
                          child: assetPath != null
                              ? Image.asset(
                                  assetPath,
                                  // NH 로고는 너무 작게 보여서 박스를 가득 채우도록 확대
                                  fit: isNhLogo
                                      ? BoxFit.cover
                                      : BoxFit.contain, // 기본은 영역 안에서 전체가 보이도록
                                )
                              : Image.network(
                                  logoUrl!,
                                  fit: BoxFit.contain, // 영역 안에서 전체가 보이도록
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _RateLabel(
                                      label: '팔 때',
                                      description: '사용자가 지점에 상품권을 파는 경우 (지점이 금액을 지급합니다).',
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '최대: ${_fmtPrice(bestSellPrice)}'
                                      '${bestSellRate != null ? ' (${bestSellRate.toStringAsFixed(2)}%)' : ''}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      '최소: ${_fmtPrice(worstSellPrice)}'
                                      '${worstSellRate != null ? ' (${worstSellRate.toStringAsFixed(2)}%)' : ''}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _RateLabel(
                                      label: '살 때',
                                      description: '사용자가 지점에서 상품권을 사는 경우 (사용자가 금액을 지불합니다).',
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '최소: ${_fmtPrice(bestBuyPrice)}'
                                      '${bestBuyRate != null ? ' (${bestBuyRate.toStringAsFixed(2)}%)' : ''}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      '최대: ${_fmtPrice(worstBuyPrice)}'
                                      '${worstBuyRate != null ? ' (${worstBuyRate.toStringAsFixed(2)}%)' : ''}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black38),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 추천 대시보드 진입용 카드
class _RecommendEntryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        // 1) 상품권 선택 다이얼로그
        final List<String>? selectedIds =
            await _showGiftcardSelectDialog(context);
        if (selectedIds == null || selectedIds.isEmpty) return;

        // 2) 땅콩 확인 및 차감 (선택 개수 * 3개)
        final int cost = selectedIds.length * 3;
        final bool ok =
            await _confirmAndSpendPeanutsForRecommend(context, amount: cost);
        if (!ok) return;
        if (!context.mounted) return;

        // 3) 추천 대시보드로 이동
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                GiftcardRecommendDashboardPage(selectedGiftcardIds: selectedIds),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF74512D),
              Color(0xFFB38A60),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Color(0xFF74512D),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '오늘 어디에 팔면 제일 이득일까?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '선택한 상품권 기준 Top 2 지점을 한 눈에 비교해보세요.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

/// 2단계: 특정 브랜드 선택 시, 지점별 현재 시세 리스트
class GiftcardBrandRatesPage extends StatelessWidget {
  final String giftcardId;
  final String giftcardName;

  const GiftcardBrandRatesPage({
    super.key,
    required this.giftcardId,
    required this.giftcardName,
  });

  NumberFormat get _won => NumberFormat('#,###');

  String _fmtPrice(num? v) => v == null ? '-' : '${_won.format(v)}원';

  Future<List<Map<String, dynamic>>> _load() async {
    // collectionGroup 인덱스/권한 이슈를 피하기 위해
    // 지점 목록을 먼저 읽고 각 지점의 giftcardRates_current/{giftcardId} 문서를 조회한다.
    final branchesSnap =
        await FirebaseFirestore.instance.collection('branches').get();

    final List<Map<String, dynamic>> rows = [];

    for (final branchDoc in branchesSnap.docs) {
      final branchId = branchDoc.id;
      final branchData = branchDoc.data();
      final bool isVerified = (branchData['verified'] as bool?) ?? false;

      final rateDoc = await branchDoc.reference
          .collection('giftcardRates_current')
          .doc(giftcardId)
          .get();

      if (!rateDoc.exists) continue;
      final rateData = rateDoc.data();
      if (rateData == null) continue;

      rows.add({
        'branchId': branchId,
        'branch': branchData,
        'rate': rateData,
        'verified': isVerified,
      });
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(giftcardName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: const Color.fromRGBO(242, 242, 247, 1.0),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return const Center(child: Text('시세를 불러오지 못했습니다.'));
            }
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
              ),
            );
          }

          final rows = snapshot.data!;

          if (rows.isEmpty) {
            return const Center(child: Text('해당 상품권을 취급하는 지점이 없습니다.'));
          }

          rows.sort((a, b) {
            final sa = (a['rate']?['sellPrice_general'] as num?) ?? 0;
            final sb = (b['rate']?['sellPrice_general'] as num?) ?? 0;
            return sb.compareTo(sa);
          });

          final double bottomInset = MediaQuery.of(context).padding.bottom;

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final row = rows[index];
              final String branchId = row['branchId'] as String;
              final Map<String, dynamic> branch =
                  (row['branch'] as Map<String, dynamic>) ?? {};
              final Map<String, dynamic> data =
                  (row['rate'] as Map<String, dynamic>) ?? {};
              final bool isVerified = (row['verified'] as bool?) ?? false;

              final branchName =
                  (branch['name'] as String?) ?? (branchId.isNotEmpty ? branchId : '알 수 없음');
              final address = branch['address'] as String?;

              final sellPrice = data['sellPrice_general'] as num?;
              final buyPrice = data['buyPrice_general'] as num?;
              final double? sellRate = _calcRateFromPrice(sellPrice);
              final double? buyRate = _calcRateFromPrice(buyPrice);

              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BranchRatesDetailPage(
                        branchId: branchId,
                        branchName: branchName,
                        isVerified: isVerified,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0x1174512D),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.storefront_outlined,
                              size: 18,
                              color: Color(0xFF74512D),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        branchName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isVerified) ...[
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: Image.asset(
                                          'asset/img/verified.jpg',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (address != null && address.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Colors.black38),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.south_west,
                                  size: 16,
                                  color: Color(0xFF1E88E5),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '팔 때',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        '${_fmtPrice(sellPrice)}'
                                        '${sellRate != null ? ' (${sellRate.toStringAsFixed(2)}%)' : ''}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.north_east,
                                  size: 16,
                                  color: Color(0xFFD81B60),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '살 때',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        '${_fmtPrice(buyPrice)}'
                                        '${buyRate != null ? ' (${buyRate.toStringAsFixed(2)}%)' : ''}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GiftcardRecommendDashboardPage extends StatefulWidget {
  final List<String>? selectedGiftcardIds;

  const GiftcardRecommendDashboardPage({super.key, this.selectedGiftcardIds});

  @override
  State<GiftcardRecommendDashboardPage> createState() =>
      _GiftcardRecommendDashboardPageState();
}

class _GiftcardRecommendDashboardPageState
    extends State<GiftcardRecommendDashboardPage> {
  bool _loading = true;
  String? _error;
  Position? _position;
  List<_RecommendItem> _items = <_RecommendItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) 현재 위치 시도
      Position? pos;
      try {
        final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
          }
        }
      } catch (_) {
        // 위치 실패는 치명적이지 않으므로 무시
      }

      // 2) 지점 + 현재 시세 로드
      final branchesSnap =
          await FirebaseFirestore.instance.collection('branches').get();

      final Map<String, Map<String, dynamic>> giftcards =
          <String, Map<String, dynamic>>{};

      final Map<String, List<_RecommendRow>> perGiftcard =
          <String, List<_RecommendRow>>{};

      for (final branchDoc in branchesSnap.docs) {
        final String branchId = branchDoc.id;
        final Map<String, dynamic> branchData = branchDoc.data();

        final ratesSnap = await branchDoc.reference
            .collection('giftcardRates_current')
            .get();

        for (final rate in ratesSnap.docs) {
          final Map<String, dynamic> rateData = rate.data();
          final String giftcardId =
              (rateData['giftcardId'] as String?) ?? rate.id;
          final num? sellPrice = rateData['sellPrice_general'] as num?;
          if (sellPrice == null) continue;

          double? distanceKm;
          if (pos != null) {
            final double? lat = (branchData['latitude'] as num?)?.toDouble();
            final double? lng = (branchData['longitude'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              final double d = Geolocator.distanceBetween(
                    pos.latitude,
                    pos.longitude,
                    lat,
                    lng,
                  ) /
                  1000.0;
              distanceKm = d;
            }
          }

          perGiftcard.putIfAbsent(giftcardId, () => <_RecommendRow>[]).add(
                _RecommendRow(
                  branchId: branchId,
                  branch: branchData,
                  rate: rateData,
                  sellPrice: sellPrice.toDouble(),
                  distanceKm: distanceKm,
                ),
              );
        }
      }

      // 3) giftcards 메타 로드 (이름/로고)
      final giftsSnap =
          await FirebaseFirestore.instance.collection('giftcards').get();
      for (final doc in giftsSnap.docs) {
        giftcards[doc.id] = doc.data();
      }

      // 4) 각 상품권별 Top2 선정
      final List<_RecommendItem> items = <_RecommendItem>[];
      final Set<String>? filter =
          widget.selectedGiftcardIds == null ||
                  widget.selectedGiftcardIds!.isEmpty
              ? null
              : widget.selectedGiftcardIds!.toSet();

      perGiftcard.forEach((giftcardId, rows) {
        if (filter != null && !filter.contains(giftcardId)) return;
        if (rows.isEmpty) return;
        rows.sort((a, b) {
          final int cmp = b.sellPrice.compareTo(a.sellPrice);
          if (cmp != 0) return cmp;
          final double da = a.distanceKm ?? double.infinity;
          final double db = b.distanceKm ?? double.infinity;
          return da.compareTo(db);
        });

        final branchRows = rows.take(2).toList();
        final Map<String, dynamic> giftMeta =
            giftcards[giftcardId] ?? <String, dynamic>{};
        items.add(
          _RecommendItem(
            giftcardId: giftcardId,
            giftName:
                (giftMeta['name'] as String?) ?? giftcardId.toUpperCase(),
            logoUrl: giftMeta['logoUrl'] as String?,
            rows: branchRows,
          ),
        );
      });

      setState(() {
        _position = pos;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '추천 정보를 불러오지 못했습니다.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('추천 대시보드'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: const Color.fromRGBO(242, 242, 247, 1.0),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
              ),
            )
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text('추천할 지점이 없습니다.'),
                    )
                  : Builder(
                      builder: (context) {
                        final double bottomInset =
                            MediaQuery.of(context).padding.bottom;
                        return ListView.builder(
                          padding:
                              EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
                          itemCount: _items.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    '선택한 상품권별로 오늘 팔 때 가장 많이 쳐주는 지점 2곳을 추천해드려요.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '가격이 같다면 내 위치에서 더 가까운 지점이 먼저 보여집니다.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                ],
                              );
                            }
                            final _RecommendItem item =
                                _items[index - 1];
                            return _RecommendCard(
                              item: item,
                              position: _position,
                            );
                          },
                        );
                      },
                    ),
    );
  }
}

class _RecommendRow {
  final String branchId;
  final Map<String, dynamic> branch;
  final Map<String, dynamic> rate;
  final double sellPrice;
  final double? distanceKm;

  _RecommendRow({
    required this.branchId,
    required this.branch,
    required this.rate,
    required this.sellPrice,
    required this.distanceKm,
  });
}

class _RecommendItem {
  final String giftcardId;
  final String giftName;
  final String? logoUrl;
  final List<_RecommendRow> rows;

  _RecommendItem({
    required this.giftcardId,
    required this.giftName,
    required this.logoUrl,
    required this.rows,
  });
}

class _RecommendCard extends StatelessWidget {
  final _RecommendItem item;
  final Position? position;

  const _RecommendCard({required this.item, required this.position});

  String _fmtWon(double v) => NumberFormat('#,###').format(v);

  String? _assetForGiftcard(String id) {
    switch (id) {
      case 'costco':
        return 'asset/img/costco.png';
      case 'eland':
        return 'asset/img/eland.png';
      case 'galleria':
        return 'asset/img/galleria.png';
      case 'hyundai':
        return 'asset/img/hyundai.png';
      case 'lotte':
        return 'asset/img/lotte.png';
      case 'samsung':
        return 'asset/img/samsung.png';
      case 'shinsegae':
        return 'asset/img/shinsegae.png';
      case 'kumkang':
        return 'asset/img/kumkang.png';
      case 'nh':
      case 'nonghyup':
      case '농협':
        return 'asset/img/nh.jpg';
      case 'ak':
        return 'asset/img/ak.jpg';
      case 'cj':
      case 'cjgift':
        return 'asset/img/cj.png';
      default:
        return 'asset/img/app_icon.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? assetPath = _assetForGiftcard(item.giftcardId);
    final bool isNhLogo = item.giftcardId == 'nh' ||
        item.giftcardId == 'nonghyup' ||
        item.giftcardId == '농협';

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GiftcardBrandRatesPage(
              giftcardId: item.giftcardId,
              giftcardName: item.giftName,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (assetPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 36,
                      height: 36,
                      color: Colors.white,
                      child: Image.asset(
                        assetPath,
                        fit: isNhLogo ? BoxFit.cover : BoxFit.contain,
                      ),
                    ),
                  ),
                if (assetPath != null) const SizedBox(width: 10),
                Text(
                  item.giftName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < item.rows.length; i++)
              _buildRow(context, item.rows[i], rank: i + 1),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, _RecommendRow row,
      {required int rank}) {
    final String branchName =
        (row.branch['name'] as String?) ?? row.branchId;
    final double? sellRate = _calcRateFromPrice(row.sellPrice);
    final double? distanceKm = row.distanceKm;

    return Padding(
      padding: EdgeInsets.only(top: rank == 1 ? 0 : 8),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BranchRatesDetailPage(
                branchId: row.branchId,
                branchName: branchName,
                isVerified: (row.branch['verified'] as bool?) ?? false,
              ),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank == 1
                    ? const Color(0xFFFFD54F)
                    : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: rank == 1 ? Colors.black : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branchName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '팔 때 ${_fmtWon(row.sellPrice)}원',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (sellRate != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(${sellRate.toStringAsFixed(2)}%)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (distanceKm != null)
                    Text(
                      '~ ${distanceKm.toStringAsFixed(1)}km',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3단계: 특정 지점 선택 시, 지점 정보 + 이 지점의 모든 상품권 시세
class BranchRatesDetailPage extends StatelessWidget {
  final String branchId;
  final String branchName;
  final bool isVerified;

  const BranchRatesDetailPage({
    super.key,
    required this.branchId,
    required this.branchName,
    this.isVerified = false,
  });

  NumberFormat get _won => NumberFormat('#,###');

  String _fmtPrice(num? v) => v == null ? '-' : '${_won.format(v)}원';

  Future<Map<String, dynamic>> _load() async {
    final branchDoc = await FirebaseFirestore.instance
        .collection('branches')
        .doc(branchId)
        .get();
    final ratesSnap = await FirebaseFirestore.instance
        .collection('branches')
        .doc(branchId)
        .collection('giftcardRates_current')
        .get();
    final giftcardsSnap =
        await FirebaseFirestore.instance.collection('giftcards').get();

    final Map<String, Map<String, dynamic>> giftcards = {
      for (final d in giftcardsSnap.docs) d.id: d.data(),
    };

    return {
      'branch': branchDoc.data(),
      'rates': ratesSnap.docs,
      'giftcards': giftcards,
    };
  }

  Future<String?> _latestDailyId() async {
    final today = DateTime.now();
    final todayId =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';

    final dailyCol = FirebaseFirestore.instance
        .collection('branches')
        .doc(branchId)
        .collection('rates_daily');

    final todayDoc = await dailyCol.doc(todayId).get();
    if (todayDoc.exists) return todayId;

    final latestSnap = await dailyCol
        .orderBy(FieldPath.documentId, descending: true)
        .limit(1)
        .get();

    if (latestSnap.docs.isEmpty) return null;
    return latestSnap.docs.first.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                branchName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 20,
                height: 20,
                child: Image.asset(
                  'asset/img/verified.jpg',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (isVerified)
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BranchDetailScreen(
                      branchId: branchId,
                      branchName: branchName,
                    ),
                  ),
                );
              },
              child: const Text(
                '리뷰 쓰기',
                style: TextStyle(
                  color: Color(0xFF74512D),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      backgroundColor: const Color.fromRGBO(242, 242, 247, 1.0),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return const Center(child: Text('지점 정보를 불러오지 못했습니다.'));
            }
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
              ),
            );
          }

          final branch = snapshot.data!['branch'] as Map<String, dynamic>?;
          final List<QueryDocumentSnapshot<Map<String, dynamic>>> rateDocs =
              List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  snapshot.data!['rates'] as List);
          final giftcards =
              snapshot.data!['giftcards'] as Map<String, Map<String, dynamic>>;

          final address = branch?['address'] as String?;
          final phone = branch?['phone'] as String?;
          final notice = branch?['notice'] as String?;
          final openingHours = branch?['openingHours'] as Map<String, dynamic>?;
          final url = branch?['url'] as String?;

          return FutureBuilder<String?>(
            future: _latestDailyId(),
            builder: (context, latestIdSnap) {
              final String baseDateLabel;
              if (latestIdSnap.connectionState == ConnectionState.waiting) {
                baseDateLabel = '기준일 확인 중...';
              } else if (latestIdSnap.data != null) {
                final id = latestIdSnap.data!;
                baseDateLabel =
                    '기준일: ${id.substring(0, 4)}-${id.substring(4, 6)}-${id.substring(6, 8)}';
              } else {
                baseDateLabel = '기준일 정보 없음';
              }

              final double bottomInset = MediaQuery.of(context).padding.bottom;

              return ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
                children: [
                  Text(
                    baseDateLabel,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branchName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (address != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.place_outlined,
                                size: 18,
                                color: Colors.black54,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '주소',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(address),
                          const SizedBox(height: 8),
                          ],
                        if (phone != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.phone_outlined,
                                size: 18,
                                color: Colors.black54,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '연락처',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(phone),
                          const SizedBox(height: 8),
                        ],
                        if (openingHours != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.access_time_outlined,
                                size: 18,
                                color: Colors.black54,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '영업시간',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            openingHours.entries
                                .map((e) => '${e.key}: ${e.value}')
                                .join('\n'),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (notice != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Colors.black54,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '안내사항',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(notice),
                          const SizedBox(height: 8),
                        ],
                        if (url != null && url.trim().isNotEmpty) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.language,
                                size: 18,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'URL',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.tryParse(url.trim());
                              if (uri != null) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            child: Text(
                              url.trim(),
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '이 지점에서 취급하는 상품권',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '상품권',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '팔 때',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '살 때',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final doc in rateDocs)
                          _buildBranchRateRow(doc, giftcards),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBranchRateRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, Map<String, dynamic>> giftcards,
  ) {
    final data = doc.data();
    final giftcardId = data['giftcardId'] as String? ?? doc.id;
    final giftcard = giftcards[giftcardId];
    final giftName = (giftcard?['name'] as String?) ?? giftcardId;

    final sellPrice = data['sellPrice_general'] as num?;
    final buyPrice = data['buyPrice_general'] as num?;
    final double? sellRate = _calcRateFromPrice(sellPrice);
    final double? buyRate = _calcRateFromPrice(buyPrice);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(giftName)),
          Expanded(
            flex: 2,
            child: Text(
              '${_fmtPrice(sellPrice)}'
              '${sellRate != null ? ' (${sellRate.toStringAsFixed(2)}%)' : ''}',
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${_fmtPrice(buyPrice)}'
              '${buyRate != null ? ' (${buyRate.toStringAsFixed(2)}%)' : ''}',
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}


