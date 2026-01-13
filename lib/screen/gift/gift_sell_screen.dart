import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class GiftSellScreen extends StatefulWidget {
  final String? editSaleId;
  const GiftSellScreen({super.key, this.editSaleId});

  @override
  State<GiftSellScreen> createState() => _GiftSellScreenState();
}

class _GiftSellScreenState extends State<GiftSellScreen> {
  String? _selectedLotId;
  Map<String, dynamic>? _selectedLot; // lot snapshot data + id

  final TextEditingController _sellUnitController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  DateTime _sellDate = DateTime.now();

  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _openLots = [];
  Map<String, dynamic>? _existingSale;
  // 지점 선택
  List<Map<String, dynamic>> _branches = [];
  bool _branchesLoading = false;
  String? _selectedBranchId;
  bool _includeInRanking = true; // 랭킹 반영 토글 (기본값: true)

  @override
  void initState() {
    super.initState();
    _loadOpenLots();
    _loadBranches();
    _sellUnitController.addListener(_onSellUnitChanged);
    _discountController.addListener(_onDiscountChanged);
    if (widget.editSaleId != null) {
      _loadExistingSale();
    }
  }

  Future<void> _loadExistingSale() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.editSaleId == null) return;
    final saleDoc = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('sales').doc(widget.editSaleId).get();
    if (!saleDoc.exists) return;
    final sale = saleDoc.data() as Map<String, dynamic>;
    final lotId = sale['lotId'] as String?;
    Map<String, dynamic>? lot;
    if (lotId != null) {
      final lotDoc = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('lots').doc(lotId).get();
      if (lotDoc.exists) {
        lot = {'lotId': lotDoc.id, ...lotDoc.data()!};
      }
    }
    setState(() {
      _existingSale = {'id': saleDoc.id, ...sale};
      if (lot != null) {
        _openLots = [lot];
        _selectedLotId = lot['lotId'] as String?;
        _selectedLot = lot;
      }
      _selectedBranchId = sale['branchId'] as String?;
      _includeInRanking = (sale['includeInRanking'] as bool?) ?? true;
      _sellUnitController.text = ((sale['sellUnit'] as num?)?.toInt() ?? 0).toString();
      _discountController.text = ((sale['discount'] as num?)?.toDouble() ?? 0).toString();
      _qtyController.text = ((sale['qty'] as num?)?.toInt() ?? 0).toString();
      final ts = sale['sellDate'];
      if (ts is Timestamp) _sellDate = ts.toDate();
    });
  }

  Future<void> _loadOpenLots() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final lotsSnap = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('lots')
          .where('status', isEqualTo: 'open')
          .get();
      setState(() {
        _openLots = lotsSnap.docs.map((d) => {'lotId': d.id, ...d.data()}).toList();
        if (_openLots.isNotEmpty) {
          _selectedLotId = _openLots.first['lotId'] as String;
          _selectedLot = _openLots.first;
          // lot 선택 시 수량을 전체 수량으로 초기화
          final totalQty = (_selectedLot!['qty'] as int?) ?? 0;
          _qtyController.text = totalQty.toString();
        } else {
          _qtyController.text = '0';
        }
      });
    } catch (_) {}
  }

  Future<void> _loadBranches() async {
    if (_branchesLoading || _branches.isNotEmpty) return;
    setState(() { _branchesLoading = true; });
    try {
      final snap = await FirebaseFirestore.instance.collection('branches').get();
      final list = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': (data['name'] as String?) ?? d.id,
        };
      }).toList()
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      setState(() { _branches = list; });
    } catch (_) {
    } finally {
      if (mounted) setState(() { _branchesLoading = false; });
    }
  }

  void _onLotChanged(String? lotId) {
    setState(() {
      _selectedLotId = lotId;
      _selectedLot = _openLots.firstWhere((e) => e['lotId'] == lotId, orElse: () => {});
      // lot 변경 시 수량을 전체 수량으로 초기화
      if (_selectedLot != null && _selectedLot!.isNotEmpty) {
        final totalQty = (_selectedLot!['qty'] as int?) ?? 0;
        _qtyController.text = totalQty.toString();
      } else {
        _qtyController.text = '0';
      }
    });
  }

  void _onSellUnitChanged() {
    final face = (_selectedLot?['faceValue'] as int?) ?? 0;
    final unit = int.tryParse(_sellUnitController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (unit == null || face == 0) return;
    final disc = 100 * (1 - (unit / face));
    final str = disc.toStringAsFixed(2);
    if (_discountController.text != str) {
      _discountController.removeListener(_onDiscountChanged);
      _discountController.text = str;
      _discountController.addListener(_onDiscountChanged);
      setState(() {});
    }
  }

  void _onDiscountChanged() {
    final face = (_selectedLot?['faceValue'] as int?) ?? 0;
    final disc = double.tryParse(_discountController.text);
    if (disc == null || face == 0) return;
    final unit = (face * (1 - disc / 100)).round();
    final str = unit.toString();
    if (_sellUnitController.text != str) {
      _sellUnitController.removeListener(_onSellUnitChanged);
      _sellUnitController.text = str;
      _sellUnitController.addListener(_onSellUnitChanged);
      setState(() {});
    }
  }

  int _getSellQty() {
    if (widget.editSaleId != null) {
      // 수정 모드일 때는 기존 판매 수량 사용
      return (_existingSale?['qty'] as int?) ?? ((_selectedLot?['qty'] as int?) ?? 0);
    }
    // 신규 모드일 때는 입력된 수량 사용
    return int.tryParse(_qtyController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  int _sellTotal() {
    final qty = _getSellQty();
    final unit = int.tryParse(_sellUnitController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return qty * unit;
  }

  int _buyTotal() {
    final qty = _getSellQty();
    final unit = (_selectedLot?['buyUnit'] as int?) ?? 0;
    return qty * unit;
  }

  int _miles() {
    final buyTotal = _buyTotal();
    // 카드 규칙에서 어떤 값을 사용했는지 알기 위해 payType 기준으로 신용/체크 분기
    final payType = (_selectedLot?['payType'] as String?) ?? '신용';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cardId = (_selectedLot?['cardId'] as String?) ?? '';
    // 실제 규칙값 로딩은 저장 시점에 동기 조회로 간단 처리 (UI 미블로킹)
    // 여기서는 즉시 계산은 0으로, 미리보기는 저장 직전에 보정
    return 0;
  }

  Future<int> _loadRulePerMile(String uid, String cardId, String payType) async {
    final cardDoc = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('cards').doc(cardId).get();
    if (!cardDoc.exists) return 0;
    final data = cardDoc.data() as Map<String, dynamic>;
    final int val = (payType == '신용')
        ? (data['creditPerMileKRW'] as num?)?.toInt() ?? 0
        : (data['checkPerMileKRW'] as num?)?.toInt() ?? 0;
    return val;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sellDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF74512D))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _sellDate = picked);
  }

  Future<void> _save() async {
    setState(() { _error = null; });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Fluttertoast.showToast(msg: '로그인이 필요합니다.');
      return;
    }
    if (_selectedLotId == null || _selectedLot == null) {
      setState(() { _error = '판매할 구매(Lot)를 선택하세요.'; });
      return;
    }
    final sellUnit = int.tryParse(_sellUnitController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (sellUnit <= 0) {
      setState(() { _error = '판매가를 입력하세요.'; });
      return;
    }
    final sellQty = int.tryParse(_qtyController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (sellQty <= 0) {
      setState(() { _error = '수량은 1개 이상이어야 합니다.'; });
      return;
    }
    final totalQty = (_selectedLot?['qty'] as int?) ?? 0;
    if (sellQty > totalQty) {
      setState(() { _error = '판매 수량이 전체 수량보다 많을 수 없습니다.'; });
      return;
    }

    if (_saving) return;
    setState(() { _saving = true; });
    try {
      final qty = sellQty;
      final faceValue = (_selectedLot?['faceValue'] as int?) ?? 100000;
      final buyTotal = _buyTotal();
      final sellTotal = qty * sellUnit;
      final discount = 100 * (1 - (sellUnit / faceValue));

      // 카드 규칙 불러와서 마일 계산
      final milePerKRW = await _loadRulePerMile(uid, _selectedLot!['cardId'] as String, _selectedLot!['payType'] as String);
      final miles = milePerKRW == 0 ? 0 : (buyTotal / milePerKRW).round();
      final profit = sellTotal - buyTotal;
      final costPerMile = miles == 0 ? 0 : (-profit / miles);

      final salesRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('sales');
      final saleId = widget.editSaleId ?? 'sale_${DateTime.now().millisecondsSinceEpoch}';
      final payload = {
        'lotId': _selectedLotId,
        'sellDate': Timestamp.fromDate(_sellDate),
        'sellUnit': sellUnit,
        'discount': double.parse(discount.toStringAsFixed(2)),
        'sellTotal': sellTotal,
        'buyTotal': buyTotal,
        'qty': qty,
        'mileRuleUsedPerMileKRW': milePerKRW,
        'miles': miles,
        'profit': profit,
        'costPerMile': double.parse(costPerMile.toStringAsFixed(2)),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_selectedBranchId != null && _selectedBranchId!.isNotEmpty) {
        payload['branchId'] = _selectedBranchId;
      }
      payload['includeInRanking'] = _includeInRanking;
      if (widget.editSaleId == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }
      await salesRef.doc(saleId).set(payload, SetOptions(merge: true));

      if (widget.editSaleId == null) {
        // 신규 저장일 때만 lot 처리
        final lotsRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('lots');
        final originalLotRef = lotsRef.doc(_selectedLotId!);
        
        if (qty < totalQty) {
          // 부분 판매: lot 분할
          // 1. 원본 lot 업데이트: qty를 판매 수량으로 변경, status를 sold로 변경
          await originalLotRef.update({
            'qty': qty,
            'status': 'sold',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // 2. 새로운 lot 생성: 나머지 수량
          final remainingQty = totalQty - qty;
          final newLotId = 'lot_${DateTime.now().millisecondsSinceEpoch}';
          final newLotData = {
            'faceValue': (_selectedLot!['faceValue'] as int?) ?? 100000,
            'buyDate': _selectedLot!['buyDate'],
            'payType': _selectedLot!['payType'],
            'buyUnit': (_selectedLot!['buyUnit'] as int?) ?? 0,
            'discount': (_selectedLot!['discount'] as num?)?.toDouble() ?? 0,
            'qty': remainingQty,
            'cardId': _selectedLot!['cardId'],
            'status': 'open',
            'giftcardId': _selectedLot!['giftcardId'],
            'memo': _selectedLot!['memo'] ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          await lotsRef.doc(newLotId).set(newLotData);
        } else {
          // 전체 판매: 원본 lot의 status만 sold로 변경
          await originalLotRef.update({
            'status': 'sold',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // 지점 선택 시 월간 랭킹 반영
      print('[GiftSellScreen] 랭킹 업데이트 시작 - 지점: $_selectedBranchId, 토글: $_includeInRanking');
      try {
        final monthKey = '${_sellDate.year}${_sellDate.month.toString().padLeft(2, '0')}';
        print('[GiftSellScreen] monthKey: $monthKey');
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final userData = userDoc.data() as Map<String, dynamic>?;
        final displayName = (userData?['displayName'] as String?) ?? (userData?['email'] as String?) ?? '익명';
        final photoUrl = (userData?['photoURL'] as String?) ?? '';
        print('[GiftSellScreen] 사용자 정보 - uid: $uid, displayName: $displayName, saleTotal: $sellTotal');
        
        // 지점 선택 시 지점 랭킹 업데이트
        if (_selectedBranchId != null && _selectedBranchId!.isNotEmpty) {
          print('[GiftSellScreen] 지점 랭킹 업데이트 시작');
          await _updateBranchMonthlyRanking(
            branchId: _selectedBranchId!,
            monthKey: monthKey,
            uid: uid,
            displayName: displayName,
            photoUrl: photoUrl,
            saleId: saleId,
            saleTotal: sellTotal,
          );
          print('[GiftSellScreen] 지점 랭킹 업데이트 완료');
        } else {
          print('[GiftSellScreen] 지점이 선택되지 않아 지점 랭킹 업데이트 건너뜀');
        }
        
        // 랭킹 반영 토글이 켜져있으면 meta에도 저장 (지점 선택 여부와 관계없이)
        if (_includeInRanking) {
          print('[GiftSellScreen] Meta 랭킹 업데이트 시작');
          await _updateMetaMonthlyRanking(
            monthKey: monthKey,
            uid: uid,
            displayName: displayName,
            photoUrl: photoUrl,
            saleId: saleId,
            saleTotal: sellTotal,
          );
          print('[GiftSellScreen] Meta 랭킹 업데이트 완료');
        } else {
          print('[GiftSellScreen] 랭킹 반영 토글이 꺼져있어 Meta 저장 건너뜀');
        }
      } catch (e, stackTrace) {
        print('[GiftSellScreen] 랭킹 업데이트 오류: $e');
        print('[GiftSellScreen] 스택 트레이스: $stackTrace');
        // 랭킹 업데이트 실패해도 판매 저장은 성공으로 처리
      }

      Fluttertoast.showToast(msg: widget.editSaleId == null ? '판매가 저장되었습니다.' : '판매가 수정되었습니다.');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: '저장 실패: $e');
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  Future<void> _updateBranchMonthlyRanking({
    required String branchId,
    required String monthKey,
    required String uid,
    required String displayName,
    required String photoUrl,
    required String saleId,
    required int saleTotal,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('branches')
        .doc(branchId)
        .collection('rates_monthly')
        .doc(monthKey);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      List<dynamic> users = [];
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final raw = data['users'];
        if (raw is List) users = List<dynamic>.from(raw);
      }

      // sale 단위 행 삽입/수정 (중복 방지: uid + saleId)
      int index = -1;
      for (int i = 0; i < users.length; i++) {
        final e = users[i];
        if (e is Map && (e['uid'] as String?) == uid && (e['saleId'] as String?) == saleId) { index = i; break; }
      }
      final entry = {
        'uid': uid,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'saleId': saleId,
        'sellTotal': saleTotal,
      };
      if (index >= 0) {
        users[index] = entry;
      } else {
        users.add(entry);
      }

      // uid별 합산하여 Top3 산출
      final Map<String, Map<String, dynamic>> agg = {};
      for (final u in users) {
        if (u is! Map) continue;
        final String uid0 = (u['uid'] as String?) ?? '';
        if (uid0.isEmpty) continue;
        final int v = (u['sellTotal'] as num?)?.toInt() ?? 0;
        final String dn = (u['displayName'] as String?) ?? '';
        final String pu = (u['photoUrl'] as String?) ?? '';
        final Map<String, dynamic> cur = agg[uid0] ?? {'uid': uid0, 'displayName': dn, 'photoUrl': pu, 'sellTotal': 0};
        cur['sellTotal'] = ((cur['sellTotal'] as int?) ?? 0) + v;
        cur['displayName'] = dn; // 최신 정보로 업데이트
        cur['photoUrl'] = pu;
        agg[uid0] = cur;
      }
      final List<Map<String, dynamic>> ranked = agg.values.toList()
        ..sort((a, b) => ((b['sellTotal'] as int) - (a['sellTotal'] as int)));

      Map<String, dynamic>? toTop(int i) => (i < ranked.length) ? ranked[i] : null;

      final update = <String, dynamic>{
        'users': users,
        'firstUser': toTop(0),
        'secondUser': toTop(1),
        'thirdUser': toTop(2),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (snap.exists) {
        tx.update(docRef, update);
      } else {
        update['createdAt'] = FieldValue.serverTimestamp();
        tx.set(docRef, update);
      }
    });
  }

  Future<void> _updateMetaMonthlyRanking({
    required String monthKey,
    required String uid,
    required String displayName,
    required String photoUrl,
    required String saleId,
    required int saleTotal,
  }) async {
    print('[GiftSellScreen] _updateMetaMonthlyRanking 시작');
    print('[GiftSellScreen] 파라미터 - monthKey: $monthKey, uid: $uid, saleId: $saleId, saleTotal: $saleTotal');
    
    final docRef = FirebaseFirestore.instance
        .collection('meta')
        .doc('rates_monthly')
        .collection('rates_monthly')
        .doc(monthKey);
    
    print('[GiftSellScreen] Firestore 경로: meta/rates_monthly/rates_monthly/$monthKey');

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        print('[GiftSellScreen] 트랜잭션 시작');
        final snap = await tx.get(docRef);
        print('[GiftSellScreen] 문서 존재 여부: ${snap.exists}');
        
        List<dynamic> users = [];
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          final raw = data['users'];
          if (raw is List) {
            users = List<dynamic>.from(raw);
            print('[GiftSellScreen] 기존 users 개수: ${users.length}');
          }
        } else {
          print('[GiftSellScreen] 문서가 존재하지 않음 - 새로 생성');
        }

        // sale 단위 행 삽입/수정 (중복 방지: uid + saleId)
        int index = -1;
        for (int i = 0; i < users.length; i++) {
          final e = users[i];
          if (e is Map && (e['uid'] as String?) == uid && (e['saleId'] as String?) == saleId) { 
            index = i; 
            print('[GiftSellScreen] 기존 항목 발견 - 인덱스: $index');
            break; 
          }
        }
        final entry = {
          'uid': uid,
          'displayName': displayName,
          'photoUrl': photoUrl,
          'saleId': saleId,
          'sellTotal': saleTotal,
        };
        if (index >= 0) {
          users[index] = entry;
          print('[GiftSellScreen] 기존 항목 업데이트');
        } else {
          users.add(entry);
          print('[GiftSellScreen] 새 항목 추가 - 현재 users 개수: ${users.length}');
        }

        // uid별 합산하여 Top3 산출
        final Map<String, Map<String, dynamic>> agg = {};
        for (final u in users) {
          if (u is! Map) continue;
          final String uid0 = (u['uid'] as String?) ?? '';
          if (uid0.isEmpty) continue;
          final int v = (u['sellTotal'] as num?)?.toInt() ?? 0;
          final String dn = (u['displayName'] as String?) ?? '';
          final String pu = (u['photoUrl'] as String?) ?? '';
          final Map<String, dynamic> cur = agg[uid0] ?? {'uid': uid0, 'displayName': dn, 'photoUrl': pu, 'sellTotal': 0};
          cur['sellTotal'] = ((cur['sellTotal'] as int?) ?? 0) + v;
          cur['displayName'] = dn; // 최신 정보로 업데이트
          cur['photoUrl'] = pu;
          agg[uid0] = cur;
        }
        final List<Map<String, dynamic>> ranked = agg.values.toList()
          ..sort((a, b) => ((b['sellTotal'] as int) - (a['sellTotal'] as int)));
        
        print('[GiftSellScreen] 집계된 사용자 수: ${agg.length}');
        print('[GiftSellScreen] 랭킹 Top3:');
        for (int i = 0; i < ranked.length && i < 3; i++) {
          print('[GiftSellScreen]   ${i + 1}위: ${ranked[i]['displayName']} - ${ranked[i]['sellTotal']}원');
        }

        Map<String, dynamic>? toTop(int i) => (i < ranked.length) ? ranked[i] : null;

        final update = <String, dynamic>{
          'users': users,
          'firstUser': toTop(0),
          'secondUser': toTop(1),
          'thirdUser': toTop(2),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (snap.exists) {
          print('[GiftSellScreen] 문서 업데이트 실행');
          tx.update(docRef, update);
        } else {
          print('[GiftSellScreen] 문서 생성 실행');
          update['createdAt'] = FieldValue.serverTimestamp();
          tx.set(docRef, update);
        }
        print('[GiftSellScreen] 트랜잭션 커밋 준비 완료');
      });
      print('[GiftSellScreen] _updateMetaMonthlyRanking 성공');
    } catch (e, stackTrace) {
      print('[GiftSellScreen] _updateMetaMonthlyRanking 오류: $e');
      print('[GiftSellScreen] 스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(widget.editSaleId == null ? '상품권 판매' : '상품권 판매 수정', style: const TextStyle(color: Colors.black, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // EditText가 아닌 곳을 탭하면 키보드 숨기기
                  FocusScope.of(context).unfocus();
                },
                behavior: HitTestBehavior.opaque,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    const SizedBox(height: 12),
                    const Text('구매 선택(Lot)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedLotId,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black),
                      iconEnabledColor: Colors.black54,
                      items: _openLots
                          .map((l) {
                            final ts = l['buyDate'];
                            String dateLabel = '';
                            if (ts is Timestamp) {
                              final d = ts.toDate();
                              dateLabel = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                            }
                            final memo = l['memo'] as String?;
                            final memoText = (memo != null && memo.trim().isNotEmpty) ? '  $memo' : '';
                            return DropdownMenuItem<String>(
                              value: l['lotId'] as String,
                              child: Text(
                                '${l['giftcardId'] ?? ''}  ${l['buyUnit']}원 x ${l['qty']}  |  $dateLabel$memoText',
                                style: const TextStyle(color: Colors.black),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          })
                          .toList(),
                      onChanged: widget.editSaleId != null ? null : (v) => _onLotChanged(v),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF74512D), width: 1.5)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('판매일', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    OutlinedButton(
                      onPressed: _pickDate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black26),
                      ),
                      child: Text(
                        '${_sellDate.year}-${_sellDate.month.toString().padLeft(2, '0')}-${_sellDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _sellUnitController,
                            keyboardType: TextInputType.number,
                            cursorColor: const Color(0xFF74512D),
                            decoration: const InputDecoration(
                              labelText: '판매가(권당, 원)',
                              border: OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF74512D), width: 2)),
                              labelStyle: TextStyle(color: Colors.black54),
                              floatingLabelStyle: TextStyle(color: Color(0xFF74512D)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _discountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            cursorColor: const Color(0xFF74512D),
                            decoration: const InputDecoration(
                              labelText: '할인율(%)',
                              border: OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF74512D), width: 2)),
                              labelStyle: TextStyle(color: Colors.black54),
                              floatingLabelStyle: TextStyle(color: Color(0xFF74512D)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (widget.editSaleId == null && _selectedLot != null) ...[
                      const Text('수량', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        cursorColor: const Color(0xFF74512D),
                        decoration: InputDecoration(
                          labelText: '판매 수량 (최대 ${_selectedLot!['qty']}개)',
                          hintText: '0',
                          border: const OutlineInputBorder(),
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF74512D), width: 2)),
                          labelStyle: const TextStyle(color: Colors.black54),
                          floatingLabelStyle: const TextStyle(color: Color(0xFF74512D)),
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_selectedLot != null) ...[
                      Text('수량: ${_getSellQty()}'),
                      const SizedBox(height: 4),
                      Text('총 판매금액: ${_sellTotal()}원'),
                      const SizedBox(height: 4),
                      Text('총 매입금액: ${_buyTotal()}원'),
                      const SizedBox(height: 4),
                      Text('예상 손익: ${_sellTotal() - _buyTotal()}원'),
                    ],
                    const SizedBox(height: 16),
                    const Text('지점 (선택)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      value: _selectedBranchId,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black),
                      iconEnabledColor: Colors.black54,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('선택 안 함', style: TextStyle(color: Colors.black))),
                        ..._branches.map((b) => DropdownMenuItem<String?>(
                              value: b['id'] as String,
                              child: Text(b['name'] as String, style: const TextStyle(color: Colors.black)),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedBranchId = v),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF74512D), width: 1.5)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '랭킹 반영',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
                          ),
                        ),
                        Switch(
                          value: _includeInRanking,
                          onChanged: (value) => setState(() => _includeInRanking = value),
                          activeColor: const Color(0xFF74512D),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF74512D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(widget.editSaleId == null ? '저장' : '수정', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}


