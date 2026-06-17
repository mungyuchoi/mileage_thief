import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

/// 커뮤니티/가이드 탭과 동일한 cache-first(2단) 전략을 위한 공용 유틸.
///
/// 1) Firestore 디스크 캐시(Source.cache)에서 즉시 읽어 네트워크 대기를 없앤다.
/// 2) 캐시에 데이터가 있으면 서버에서 최신본을 백그라운드로 받아 갱신한다.
/// 3) 캐시가 없으면(콜드 스타트 첫 진입) 서버에서 받아 그대로 표시한다.

typedef _QSnap = QuerySnapshot<Map<String, dynamic>>;
typedef _DSnap = DocumentSnapshot<Map<String, dynamic>>;

/// 쿼리를 캐시 우선으로 조회한다.
/// 캐시에 결과가 있으면 캐시 스냅샷을, 없으면 서버 스냅샷을 반환한다.
Future<_QSnap> cacheFirstGet(Query<Map<String, dynamic>> query) async {
  try {
    final cacheSnap = await query.get(const GetOptions(source: Source.cache));
    if (cacheSnap.docs.isNotEmpty) {
      return cacheSnap;
    }
  } catch (_) {
    // 캐시에 해당 쿼리 결과가 없음 — 서버 로드로 진행.
  }
  return query.get(const GetOptions(source: Source.server));
}

/// 단일 문서를 캐시 우선으로 조회한다.
/// 캐시에 존재하면 캐시 스냅샷을, 없으면 서버 스냅샷을 반환한다.
Future<_DSnap> cacheFirstGetDoc(
    DocumentReference<Map<String, dynamic>> ref) async {
  try {
    final cacheSnap = await ref.get(const GetOptions(source: Source.cache));
    if (cacheSnap.exists) {
      return cacheSnap;
    }
  } catch (_) {
    // 캐시에 문서 없음 — 서버 로드로 진행.
  }
  return ref.get(const GetOptions(source: Source.server));
}

/// FutureBuilder 형태로 cache-first 2단 로딩을 제공하는 위젯.
///
/// 디스크 캐시 결과를 즉시 그린 뒤, 캐시가 있었던 경우 서버 결과로
/// 한 번 더 화면을 갱신한다. StatelessWidget의 단순 FutureBuilder를
/// 손쉽게 cache-first로 바꿀 때 사용한다.
class CacheFirstQuery extends StatefulWidget {
  final Query<Map<String, dynamic>> query;
  final AsyncWidgetBuilder<_QSnap> builder;

  const CacheFirstQuery({
    super.key,
    required this.query,
    required this.builder,
  });

  @override
  State<CacheFirstQuery> createState() => _CacheFirstQueryState();
}

class _CacheFirstQueryState extends State<CacheFirstQuery> {
  late Future<_QSnap> _future;
  bool _refreshInFlight = false;

  @override
  void initState() {
    super.initState();
    _future = _loadCacheFirst();
  }

  @override
  void didUpdateWidget(covariant CacheFirstQuery oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 쿼리 대상이 바뀌면 다시 로드한다.
    if (oldWidget.query != widget.query) {
      _future = _loadCacheFirst();
    }
  }

  Future<_QSnap> _loadCacheFirst() async {
    try {
      final cacheSnap =
          await widget.query.get(const GetOptions(source: Source.cache));
      if (cacheSnap.docs.isNotEmpty) {
        unawaited(_refreshFromServer());
        return cacheSnap;
      }
    } catch (_) {
      // 캐시에 결과 없음 — 서버 로드로 진행.
    }
    return widget.query.get(const GetOptions(source: Source.server));
  }

  Future<void> _refreshFromServer() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final fresh =
          await widget.query.get(const GetOptions(source: Source.server));
      if (!mounted) return;
      setState(() => _future = Future.value(fresh));
    } catch (_) {
      // 캐시가 이미 화면에 있으므로 백그라운드 갱신 실패는 조용히 무시한다.
    } finally {
      _refreshInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_QSnap>(
      future: _future,
      builder: widget.builder,
    );
  }
}
