import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePageLoader {
  static const int defaultPageSize = 200;

  const FirestorePageLoader._();

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> load({
    required Query<Map<String, dynamic>> query,
    int pageSize = defaultPageSize,
    int? maxDocs,
  }) async {
    final int effectivePageSize = pageSize.clamp(1, 500).toInt();
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;

    while (true) {
      Query<Map<String, dynamic>> pageQuery = query.limit(effectivePageSize);
      if (cursor != null) {
        pageQuery = pageQuery.startAfterDocument(cursor);
      }

      final snapshot = await pageQuery.get();
      if (snapshot.docs.isEmpty) break;

      docs.addAll(snapshot.docs);
      if (maxDocs != null && docs.length >= maxDocs) {
        return docs.take(maxDocs).toList(growable: false);
      }
      if (snapshot.docs.length < effectivePageSize) break;

      cursor = snapshot.docs.last;
    }

    return docs;
  }
}
