import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 관리자: 쿠폰(스탬프 지급 코드) 발행 + 사용 현황 관리.
/// - 발행: createCoupon Cloud Function (관리자 권한 검증)
/// - 사용: 사용자가 세계지도 여권에서 코드 입력 → redeemCoupon (1인 1회)
/// - 전체 코드 일괄 복사로 메일/댓글 공유에 활용.
class AdminCouponManageScreen extends StatefulWidget {
  const AdminCouponManageScreen({super.key});

  @override
  State<AdminCouponManageScreen> createState() =>
      _AdminCouponManageScreenState();
}

class _AdminCouponManageScreenState extends State<AdminCouponManageScreen> {
  final _codeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '50');
  final _maxCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  bool _busy = false;

  final _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  @override
  void dispose() {
    _codeCtrl.dispose();
    _amountCtrl.dispose();
    _maxCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> _create() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    final max = int.tryParse(_maxCtrl.text.trim()) ?? 0;
    if (code.length < 3 || amount <= 0) {
      Fluttertoast.showToast(msg: '코드(3자 이상)와 스탬프 수량을 확인해주세요.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _functions.httpsCallable('createCoupon').call(<String, dynamic>{
        'code': code,
        'stampAmount': amount,
        'maxRedemptions': max,
        'memo': _memoCtrl.text.trim(),
      });
      _codeCtrl.clear();
      _maxCtrl.clear();
      _memoCtrl.clear();
      Fluttertoast.showToast(msg: '쿠폰 $code 발행 완료');
    } on FirebaseFunctionsException catch (e) {
      Fluttertoast.showToast(msg: e.message ?? '발행 실패');
    } catch (e) {
      Fluttertoast.showToast(msg: '발행 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(msg: toast);
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('coupons')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('쿠폰 관리', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          _buildForm(),
          const Divider(height: 1),
          Expanded(child: _buildList(query)),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: '쿠폰 코드',
                    hintText: '예: WELCOME50',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () =>
                    setState(() => _codeCtrl.text = _randomCode()),
                child: const Text('랜덤'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '스탬프 수량',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '총 사용한도(0=무제한)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _memoCtrl,
            decoration: const InputDecoration(
              labelText: '메모(선택)',
              hintText: '예: 6월 인스타 이벤트',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _busy ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('쿠폰 발행',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(Query<Map<String, dynamic>> query) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('목록을 불러오지 못했어요(권한 확인).'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('발행된 쿠폰이 없습니다.'));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Text('총 ${docs.length}개',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black54)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      final codes = docs
                          .map((d) => (d.data()['code'] ?? d.id).toString())
                          .join('\n');
                      _copy(codes, '코드 ${docs.length}개 복사됨');
                    },
                    icon: const Icon(Icons.copy_all, size: 18),
                    label: const Text('전체 코드 복사'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemBuilder: (context, i) => _couponTile(docs[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _couponTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final code = (d['code'] ?? doc.id).toString();
    final amount = (d['stampAmount'] ?? 0).toString();
    final used = (d['redeemedCount'] ?? 0);
    final max = (d['maxRedemptions'] ?? 0);
    final memo = (d['memo'] ?? '').toString();
    final active = d['active'] != false;
    final usage = max == 0 ? '$used회 사용' : '$used/$max 사용';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Row(
          children: [
            Text(
              code,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 16),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE7B85C),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('✦$amount',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 12)),
            ),
            if (!active) ...[
              const SizedBox(width: 6),
              const Text('중지', style: TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
        subtitle: Text(
          memo.isEmpty ? usage : '$usage · $memo',
          style: const TextStyle(fontSize: 12.5, color: Colors.black54),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 20),
          tooltip: '코드 복사',
          onPressed: () => _copy(code, '$code 복사됨'),
        ),
      ),
    );
  }
}
