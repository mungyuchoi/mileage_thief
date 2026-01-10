import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/giftcard_info_data.dart';
import '../model/giftcard_period.dart';

class GiftcardService {
  static Future<GiftcardInfoData> loadInfoData({
    required String uid,
    required DashboardPeriodType periodType,
    required DateTime selectedMonth,
    required int selectedYear,
  }) async {
    final range = getGiftcardPeriodRange(
      periodType: periodType,
      selectedMonth: selectedMonth,
      selectedYear: selectedYear,
    );
    final DateTime? start = range.start;
    final DateTime? end = range.end;

    // lots는 항상 buyDate 기준으로 기간 필터
    final CollectionReference<Map<String, dynamic>> lotsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('lots');

    Query<Map<String, dynamic>> lotsQuery = lotsRef;
    if (start != null && end != null) {
      lotsQuery = lotsQuery
          .where('buyDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('buyDate', isLessThan: Timestamp.fromDate(end))
          .orderBy('buyDate');
    } else {
      lotsQuery = lotsQuery.orderBy('buyDate');
    }

    final QuerySnapshot<Map<String, dynamic>> lotsSnap = await lotsQuery.get();

    // 매입월 기준 대시보드를 위해:
    // - 선택한 기간에 매입한 lot 들만 lots 에 포함
    // - sales 는 "그 lotId 들과 연결된 판매" + "선택한 기간에 판매된 판매" 모두 포함
    //   (일간 탭에서 판매일 기준으로도 표시하기 위해)
    final CollectionReference<Map<String, dynamic>> salesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sales');

    List<QueryDocumentSnapshot<Map<String, dynamic>>> saleDocs = [];
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> saleById = {};

    if (periodType == DashboardPeriodType.all) {
      final QuerySnapshot<Map<String, dynamic>> salesSnap =
          await salesRef.orderBy('sellDate').get();
      saleDocs = salesSnap.docs;
    } else {
      // 1) lotId 기준으로 연결된 판매 조회 (대시보드/내역용)
      final lotIds = lotsSnap.docs.map((d) => d.id).toList();
      if (lotIds.isNotEmpty) {
        // Firestore whereIn 은 최대 10개까지만 지원하므로 10개 단위로 나누어 조회
        for (int i = 0; i < lotIds.length; i += 10) {
          final int endIndex =
              (i + 10 < lotIds.length) ? i + 10 : lotIds.length;
          final List<String> chunk = lotIds.sublist(i, endIndex);
          final QuerySnapshot<Map<String, dynamic>> snap =
              await salesRef.where('lotId', whereIn: chunk).get();
          for (final d in snap.docs) {
            saleById[d.id] = d;
          }
        }
      }

      // 2) 판매일 기준으로도 판매 조회 (일간/내역용)
      final QuerySnapshot<Map<String, dynamic>> salesByDateSnap = await salesRef
          .where('sellDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start!))
          .where('sellDate', isLessThan: Timestamp.fromDate(end!))
          .orderBy('sellDate')
          .get();
      for (final d in salesByDateSnap.docs) {
        saleById[d.id] = d;
      }

      saleDocs = saleById.values.toList();
    }

    final cardsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cards')
        .get();
    final giftsSnap = await FirebaseFirestore.instance.collection('giftcards').get();
    final branchesSnap =
        await FirebaseFirestore.instance.collection('branches').get();
    final whereToBuySnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('where_to_buy')
        .get();

    final lots = lotsSnap.docs
        .map<Map<String, dynamic>>(
          (d) => <String, dynamic>{'id': d.id, ...d.data()},
        )
        .toList();
    final sales = saleDocs
        .map<Map<String, dynamic>>(
          (d) => <String, dynamic>{'id': d.id, ...d.data()},
        )
        .toList();

    final cards = {
      for (final d in cardsSnap.docs)
        d.id: {
          'name': d.data()['name'],
          'credit': ((d.data()['creditPerMileKRW'] as num?)?.toInt()) ?? 0,
          'check': ((d.data()['checkPerMileKRW'] as num?)?.toInt()) ?? 0,
        }
    };
    final giftcardNames = {
      for (final d in giftsSnap.docs)
        d.id: (d.data()['name'] as String?) ?? d.id
    };
    final branchNames = {
      for (final d in branchesSnap.docs)
        d.id: (d.data()['name'] as String?) ?? d.id
    };
    final whereToBuyNames = {
      for (final d in whereToBuySnap.docs)
        d.id: (d.data()['name'] as String?) ?? d.id
    };

    return GiftcardInfoData(
      lots: lots,
      sales: sales,
      cards: cards,
      giftcardNames: giftcardNames,
      branchNames: branchNames,
      whereToBuyNames: whereToBuyNames,
    );
  }
}


