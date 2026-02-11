import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../giftcard_rates_screen.dart';

class BranchListTab extends StatefulWidget {
  const BranchListTab({super.key});

  @override
  State<BranchListTab> createState() => _BranchListTabState();
}

class _BranchListTabState extends State<BranchListTab> {
  late final Future<Map<String, String>> _giftcardNamesFuture;

  @override
  void initState() {
    super.initState();
    _giftcardNamesFuture = _loadGiftcardNames();
  }

  Future<Map<String, String>> _loadGiftcardNames() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('giftcards').get();
      final Map<String, String> m = <String, String>{};
      for (final d in snap.docs) {
        final data = d.data();
        m[d.id] = (data['name'] as String?) ?? d.id;
      }
      return m;
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<List<String>> _loadHandledGiftcardIds({
    required String branchId,
    required Map<String, dynamic> branch,
  }) async {
    // 1) 브랜치 문서에 명시적으로 있으면 우선 사용
    final dynamic raw = branch['giftcards'] ?? branch['giftcardIds'] ?? branch['handledGiftcards'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toSet().toList();
    }

    // 2) 없으면 branches/{branchId}/giftcardRates_current 문서 목록으로 추론 (doc.id == giftcardId)
    try {
      final snap = await FirebaseFirestore.instance
          .collection('branches')
          .doc(branchId)
          .collection('giftcardRates_current')
          .get();
      return snap.docs.map((d) => d.id).where((e) => e.trim().isNotEmpty).toList();
    } catch (_) {
      return const <String>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return FutureBuilder<Map<String, String>>(
      future: _giftcardNamesFuture,
      builder: (context, giftSnap) {
        final Map<String, String> giftcardNames = giftSnap.data ?? const <String, String>{};

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('branches').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              if (snap.hasError) {
                return const Center(child: Text('지점 정보를 불러오지 못했습니다.'));
              }
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
                ),
              );
            }

            final docs = snap.data!.docs.toList();
            docs.sort((a, b) {
              final an = (a.data()['name'] as String?) ?? a.id;
              final bn = (b.data()['name'] as String?) ?? b.id;
              return an.compareTo(bn);
            });

            if (docs.isEmpty) {
              return const Center(child: Text('등록된 지점이 없습니다.'));
            }

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final branchId = doc.id;
                final branch = doc.data();

                final branchName = (branch['name'] as String?) ?? branchId;
                final address = (branch['address'] as String?) ?? '';
                final bool isVerified = (branch['verified'] as bool?) ?? false;

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
                                  if (address.trim().isNotEmpty)
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
                            const Icon(Icons.chevron_right, color: Colors.black38),
                          ],
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder<List<String>>(
                          future: _loadHandledGiftcardIds(branchId: branchId, branch: branch),
                          builder: (context, tagSnap) {
                            final ids = (tagSnap.data ?? const <String>[])
                                .where((e) => e.trim().isNotEmpty)
                                .toList();
                            if (ids.isEmpty) return const SizedBox.shrink();

                            final List<String> labels = ids
                                .map((id) => giftcardNames[id] ?? id)
                                .toSet()
                                .toList();
                            labels.sort();

                            const int maxShow = 4;
                            final List<String> shown = labels.take(maxShow).toList();
                            final int rest = labels.length - shown.length;

                            return Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final t in shown) _TagChip(text: t),
                                if (rest > 0) _TagChip(text: '+$rest'),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;

  const _TagChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1174512D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x3374512D)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF74512D),
        ),
      ),
    );
  }
}

