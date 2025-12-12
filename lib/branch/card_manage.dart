import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'card_step.dart';

class CardManagePage extends StatelessWidget {
  const CardManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('카드 관리', style: TextStyle(color: Colors.black, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CardStepPage()));
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
                  .collection('cards')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF74512D))));
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(child: Text('등록된 카드가 없습니다.', style: TextStyle(color: Colors.black54)));
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
                    final credit = (data['creditPerMileKRW'] as num?)?.toInt() ?? 0;
                    final check = (data['checkPerMileKRW'] as num?)?.toInt() ?? 0;
                    final memo = (data['memo'] as String?) ?? '';
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.credit_card, color: Color(0xFF74512D)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text('cardId: ${d.id}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('신용: $credit  |  체크: $check', style: const TextStyle(color: Colors.black87, fontSize: 12)),
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
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CardStepPage(editCardId: d.id),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.black54),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) {
                                      return AlertDialog(
                                        backgroundColor: Colors.white,
                                        title: const Text(
                                          '카드 삭제',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        content: const Text(
                                          '정말로 삭제하시겠습니까?\n기존의 상품권 구매 및 판매 이력에 문제가 있을 수 있습니다.',
                                          style: TextStyle(color: Colors.black87),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(false),
                                            child: const Text('취소', style: TextStyle(color: Colors.black)),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            child: const Text(
                                              '그래도 삭제',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ) ??
                                  false;

                              if (!confirm) return;

                              try {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .collection('cards')
                                    .doc(d.id)
                                    .delete();
                                Fluttertoast.showToast(
                                  msg: '카드가 삭제되었습니다.',
                                  gravity: ToastGravity.BOTTOM,
                                  toastLength: Toast.LENGTH_SHORT,
                                );
                              } catch (e) {
                                Fluttertoast.showToast(
                                  msg: '카드 삭제 중 오류가 발생했습니다.',
                                  gravity: ToastGravity.BOTTOM,
                                  toastLength: Toast.LENGTH_SHORT,
                                );
                              }
                            },
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


