import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/point_award_index_model.dart';

class PointAwardIndexService {
  PointAwardIndexService._();

  static final PointAwardIndexService instance = PointAwardIndexService._();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<PointAwardIndexItem>> watchItems({
    required String? programId,
    required int nights,
    required PointAwardIndexSort sort,
  }) {
    final indexId = _indexId(programId: programId, nights: nights, sort: sort);
    return _firestore
        .collection('pointAwardIndexes')
        .doc(indexId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        debugPrint('[PointAwardIndexService] missing index=$indexId');
        return const <PointAwardIndexItem>[];
      }

      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['status'] != 'active' || data['stale'] == true) {
        return const <PointAwardIndexItem>[];
      }

      final indexUpdatedAt = _asDateTime(data['updatedAt']);
      final items = asPointAwardIndexItemMaps(data['items'])
          .map((item) => PointAwardIndexItem.fromMap(
                item,
                indexUpdatedAt: indexUpdatedAt,
              ))
          .where((item) =>
              item.name.isNotEmpty &&
              item.pointsTotal > 0 &&
              item.cashTotalKrw > 0)
          .toList(growable: false);

      debugPrint(
        '[PointAwardIndexService] index=$indexId docs=1 items=${items.length}',
      );
      return List<PointAwardIndexItem>.unmodifiable(items);
    }).handleError((Object error, StackTrace stackTrace) {
      debugPrint('[PointAwardIndexService] index=$indexId error: $error');
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  String _indexId({
    required String? programId,
    required int nights,
    required PointAwardIndexSort sort,
  }) {
    final scope = (programId == null || programId.isEmpty) ? 'all' : programId;
    return '${scope}_n${nights}_${sort.name}';
  }
}

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}
