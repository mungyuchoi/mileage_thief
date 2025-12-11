import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 지점별 이벤트 관리 화면
/// - branches/{branchId}/events 컬렉션을 리스트로 보여주고
/// - 각 이벤트의 isActive를 스위치로 토글
/// - 우측 상단 + 버튼으로 이벤트 추가 다이얼로그 표시
class BranchEventManageScreen extends StatefulWidget {
  final String branchId;
  final String branchName;

  const BranchEventManageScreen({
    super.key,
    required this.branchId,
    required this.branchName,
  });

  @override
  State<BranchEventManageScreen> createState() =>
      _BranchEventManageScreenState();
}

class _BranchEventManageScreenState extends State<BranchEventManageScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _confirmAndDeleteEvent(
    DocumentReference<Map<String, dynamic>> ref,
    String name,
  ) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '이벤트 삭제',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '"$name" 이벤트를 삭제하시겠습니까?',
            style: const TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    try {
      await ref.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이벤트가 삭제되었습니다.'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('이벤트 삭제 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이벤트 삭제 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 이벤트 편집 다이얼로그
  Future<void> _showEditEventDialog(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final TextEditingController nameController = TextEditingController(
      text: (data['name'] as String?) ?? '',
    );
    final TextEditingController passwordController = TextEditingController(
      text: (data['password'] as String?) ?? '',
    );
    final TextEditingController peanutController = TextEditingController(
      text: (data['peanutCount'] as int?)?.toString() ?? '',
    );

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '이벤트 수정',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: '이벤트명',
                    labelStyle: TextStyle(color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: '이벤트 비밀번호',
                    labelStyle: TextStyle(color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: peanutController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: '땅콩 개수 (최대 100개)',
                    labelStyle: TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                '저장',
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

    if (result != true) return;

    final String name = nameController.text.trim();
    final String password = passwordController.text.trim();
    final String peanutText = peanutController.text.trim();

    if (name.isEmpty || password.isEmpty || peanutText.isEmpty) {
      Fluttertoast.showToast(msg: '이벤트명, 비밀번호, 땅콩 개수를 모두 입력해주세요.');
      return;
    }

    final int? peanutCount = int.tryParse(peanutText);
    if (peanutCount == null || peanutCount <= 0 || peanutCount > 100) {
      Fluttertoast.showToast(msg: '땅콩 개수는 1~100 사이의 숫자만 가능합니다.');
      return;
    }

    try {
      await ref.update(<String, dynamic>{
        'name': name,
        'password': password,
        'peanutCount': peanutCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이벤트가 수정되었습니다.'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('이벤트 수정 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이벤트 수정 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCreateEventDialog() async {
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }

    final TextEditingController nameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController peanutController = TextEditingController();

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '이벤트 추가',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: '이벤트명',
                    labelStyle: TextStyle(color: Colors.black54),
                    hintText: '예) 중앙상품권 5월 이벤트',
                    hintStyle: TextStyle(color: Colors.black38),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: '이벤트 비밀번호',
                    labelStyle: TextStyle(color: Colors.black54),
                    hintText: '참여 시 입력할 비밀번호',
                    hintStyle: TextStyle(color: Colors.black38),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: peanutController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: '땅콩 개수 (최대 100개)',
                    labelStyle: TextStyle(color: Colors.black54),
                    hintText: '1~100 사이 숫자를 입력하세요.',
                    hintStyle: TextStyle(color: Colors.black38),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                '추가',
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

    if (result != true) return;

    final String name = nameController.text.trim();
    final String password = passwordController.text.trim();
    final String peanutText = peanutController.text.trim();

    if (name.isEmpty || password.isEmpty || peanutText.isEmpty) {
      Fluttertoast.showToast(msg: '이벤트명, 비밀번호, 땅콩 개수를 모두 입력해주세요.');
      return;
    }

    final int? peanutCount = int.tryParse(peanutText);
    if (peanutCount == null || peanutCount <= 0 || peanutCount > 100) {
      Fluttertoast.showToast(msg: '땅콩 개수는 1~100 사이의 숫자만 가능합니다.');
      return;
    }

    try {
      final DocumentReference<Map<String, dynamic>> eventRef =
          FirebaseFirestore.instance
              .collection('branches')
              .doc(widget.branchId)
              .collection('events')
              .doc();

      await eventRef.set(<String, dynamic>{
        'name': name,
        'password': password,
        'peanutCount': peanutCount,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'branchId': widget.branchId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이벤트가 추가되었습니다.'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('이벤트 생성 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이벤트 생성 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            '이벤트 관리',
            style: TextStyle(color: Colors.black, fontSize: 16),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            '로그인이 필요합니다.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '이벤트 관리',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateEventDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('branches')
            .doc(widget.branchId)
            .collection('events')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF74512D)),
              ),
            );
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                '등록된 이벤트가 없습니다.',
                style: TextStyle(color: Colors.black54),
              ),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              snap.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              final d = docs[index];
              final Map<String, dynamic> data = d.data();
              final String name = (data['name'] as String?) ?? d.id;
              final int peanut =
                  (data['peanutCount'] as int?) ?? 0;
              final bool isActive =
                  (data['isActive'] == null) || (data['isActive'] == true);
              final Timestamp? createdAtTs =
                  data['createdAt'] as Timestamp?;
              final String createdAtStr = createdAtTs == null
                  ? ''
                  : DateTime.fromMillisecondsSinceEpoch(
                          createdAtTs.millisecondsSinceEpoch)
                      .toLocal()
                      .toString()
                      .split('.')
                      .first;

              return Container(
                padding: const EdgeInsets.all(12),
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
                    const Icon(Icons.event_note, color: Color(0xFF74512D)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '비밀번호: ${(data['password'] as String?) ?? ''}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '지급 땅콩: $peanut개',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                          if (createdAtStr.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '생성일: $createdAtStr',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 20,
                                color: Colors.black54,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  _showEditEventDialog(d.reference, data),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.black54,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmAndDeleteEvent(
                                d.reference,
                                name,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '활성화',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                        ),
                        Switch(
                          value: isActive,
                          activeColor: const Color(0xFF74512D),
                          onChanged: (bool value) async {
                            try {
                              await d.reference.update(
                                <String, dynamic>{'isActive': value},
                              );
                            } catch (e) {
                              debugPrint('이벤트 활성화 토글 오류: $e');
                              Fluttertoast.showToast(
                                msg: '이벤트 상태 변경 중 오류가 발생했습니다.',
                              );
                            }
                          },
                        ),
                      ],
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


