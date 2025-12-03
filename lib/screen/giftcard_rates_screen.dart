import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final giftcardId = doc.id;
            final name = (data['name'] as String?) ?? giftcardId;
            // Firestore에 logoUrl 이 있을 수도 있고, asset 으로만 관리할 수도 있음.
            // 우선 giftcardId 기준 asset 매핑을 시도하고, 없으면 앱 아이콘으로 대체.
            final assetPath =
                _assetForGiftcard(giftcardId) ?? 'asset/img/app_icon.png';
            final logoUrl = data['logoUrl'] as String?;

            final num? bestSellPrice = data['bestSellPrice'] as num?;
            final num? worstSellPrice = data['worstSellPrice'] as num?;
            final num? bestBuyPrice = data['bestBuyPrice'] as num?;
            final num? worstBuyPrice = data['worstBuyPrice'] as num?;

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
                                  fit: BoxFit.contain, // 영역 안에서 전체가 보이도록
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
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '팔 때 (사용자가 지점에 판매)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '최대: ${_fmtPrice(bestSellPrice)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      '최소: ${_fmtPrice(worstSellPrice)}',
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
                                    const Text(
                                      '살 때 (사용자가 지점에서 매입)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '최소: ${_fmtPrice(bestBuyPrice)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      '최대: ${_fmtPrice(worstBuyPrice)}',
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
      });
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(giftcardName),
      ),
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

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = rows[index];
              final String branchId = row['branchId'] as String;
              final Map<String, dynamic> branch =
                  (row['branch'] as Map<String, dynamic>) ?? {};
              final Map<String, dynamic> data =
                  (row['rate'] as Map<String, dynamic>) ?? {};

              final branchName =
                  (branch['name'] as String?) ?? (branchId.isNotEmpty ? branchId : '알 수 없음');

              final sellPrice = data['sellPrice_general'] as num?;
              final buyPrice = data['buyPrice_general'] as num?;
              final sellRate = data['sellFeeRate_general'] as num?;
              final buyRate = data['buyDiscountRate_general'] as num?;

              return ListTile(
                onTap: () {
                  if (branchId == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BranchRatesDetailPage(
                        branchId: branchId!,
                        branchName: branchName,
                      ),
                    ),
                  );
                },
                title: Text(branchName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '팔 때: ${_fmtPrice(sellPrice)}'
                      '${sellRate != null ? ' (${sellRate.toStringAsFixed(2)}%)' : ''}',
                    ),
                    Text(
                      '살 때: ${_fmtPrice(buyPrice)}'
                      '${buyRate != null ? ' (${buyRate.toStringAsFixed(2)}%)' : ''}',
                    ),
                  ],
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black38),
              );
            },
          );
        },
      ),
    );
  }
}

/// 3단계: 특정 지점 선택 시, 지점 정보 + 이 지점의 모든 상품권 시세
class BranchRatesDetailPage extends StatelessWidget {
  final String branchId;
  final String branchName;

  const BranchRatesDetailPage({
    super.key,
    required this.branchId,
    required this.branchName,
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
        title: Text(branchName),
      ),
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

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    baseDateLabel,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
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
                        if (address != null) ...[
                          const Text(
                            '주소',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(address),
                          const SizedBox(height: 8),
                        ],
                        if (phone != null) ...[
                          const Text(
                            '연락처',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(phone),
                          const SizedBox(height: 8),
                        ],
                        if (openingHours != null) ...[
                          const Text(
                            '영업시간',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
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
                          const Text(
                            '안내사항',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(notice),
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
    final sellRate = data['sellFeeRate_general'] as num?;
    final buyRate = data['buyDiscountRate_general'] as num?;

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


