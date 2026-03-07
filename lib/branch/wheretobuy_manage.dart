import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'wheretobuy_step.dart';

class WhereToBuyManagePage extends StatelessWidget {
  const WhereToBuyManagePage({super.key});

  Future<void> _deleteWhereToBuy({
    required BuildContext context,
    required String uid,
    required String whereToBuyId,
    required String whereToBuyName,
  }) async {
    bool hasLinkedLot = false;
    try {
      final linkedLots = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('lots')
          .where('whereToBuyId', isEqualTo: whereToBuyId)
          .limit(1)
          .get();
      hasLinkedLot = linkedLots.docs.isNotEmpty;
    } catch (_) {
      // 조회 실패 시에도 삭제는 사용자 확인 후 가능하도록 둔다.
    }

    if (!context.mounted) return;

    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              '구매처 삭제',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            content: Text(
              hasLinkedLot
                  ? '"$whereToBuyName" 구매처를 사용하는 구매 내역이 있습니다.\n삭제하면 기존 구매 내역에는 ID만 남을 수 있습니다.\n그래도 삭제하시겠습니까?'
                  : '"$whereToBuyName" 구매처를 삭제하시겠습니까?',
              style: const TextStyle(color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('취소', style: TextStyle(color: Colors.black)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  '삭제',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('where_to_buy')
          .doc(whereToBuyId)
          .delete();
      Fluttertoast.showToast(msg: '구매처가 삭제되었습니다.');
    } catch (_) {
      Fluttertoast.showToast(msg: '구매처 삭제 중 오류가 발생했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('구매처 관리', style: TextStyle(color: Colors.black, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const WhereToBuyStepPage()));
            },
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('로그인이 필요합니다.', style: TextStyle(color: Colors.black54)))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('where_to_buy')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF74512D))));
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(child: Text('등록된 구매처가 없습니다.', style: TextStyle(color: Colors.black54)));
                }
                final docs = snap.data!.docs;
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();
                    final name = (data['name'] as String?) ?? d.id;
                    final memo = (data['memo'] as String?) ?? '';
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront, color: Color(0xFF74512D)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text('whereToBuyId: ${d.id}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                if (memo.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(memo, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.black54),
                            onPressed: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => WhereToBuyStepPage(editWhereToBuyId: d.id)));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.black54),
                            tooltip: '삭제',
                            onPressed: () => _deleteWhereToBuy(
                              context: context,
                              uid: uid,
                              whereToBuyId: d.id,
                              whereToBuyName: name,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
