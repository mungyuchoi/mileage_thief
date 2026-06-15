import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// 호텔 캐치 — 내가 추가한 호텔 조회 + 퀴즈 생성(앱 풀기능).
/// 데이터는 milecatch WebView와 동일한 `hotels/{id}/quizzes` 를 사용한다.
class HotelCatchService {
  HotelCatchService._();
  static final HotelCatchService instance = HotelCatchService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _fns =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  /// 내가 추가한 호텔 목록(최신순).
  Stream<List<HotelCatchHotel>> myHotels(String uid) {
    return _db
        .collection('hotels')
        .where('createdBy', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => HotelCatchHotel.fromDoc(d.id, d.data()))
            .toList());
  }

  /// 퀴즈 생성(ox|mcq|short) → Firestore write + 기여도 트리거.
  Future<void> createQuiz({
    required String hotelId,
    required String type,
    required String tag,
    required String question,
    required List<String> options,
    required Object answer,
    required String explanation,
    required String authorUid,
    required String authorNickname,
  }) async {
    await _db
        .collection('hotels')
        .doc(hotelId)
        .collection('quizzes')
        .add(<String, dynamic>{
      'type': type,
      'tag': tag,
      'question': question.trim(),
      'options': options,
      'answer': answer,
      'explanation': explanation.trim(),
      'authorUid': authorUid,
      'authorNickname': authorNickname,
      'solveCount': 0,
      'correctCount': 0,
      'rewardPerSolve': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      await _fns.httpsCallable('addHotelContrib').call(<String, dynamic>{
        'hotelId': hotelId,
        'kind': 'quiz',
      });
    } catch (_) {
      // 기여도 트리거 실패는 비차단(퀴즈 자체는 저장됨)
    }
  }

  /// 내가 이 호텔에 낸 퀴즈 목록(편집/삭제용).
  Stream<List<HotelQuizItem>> myQuizzes(String hotelId, String uid) {
    return _db
        .collection('hotels')
        .doc(hotelId)
        .collection('quizzes')
        .where('authorUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => HotelQuizItem.fromDoc(d.id, d.data()))
            .toList());
  }

  /// 퀴즈 수정(내용 필드만 — 풀이 카운트는 건드리지 않음).
  Future<void> updateQuiz({
    required String hotelId,
    required String quizId,
    required String type,
    required String tag,
    required String question,
    required List<String> options,
    required Object answer,
    required String explanation,
  }) async {
    await _db
        .collection('hotels')
        .doc(hotelId)
        .collection('quizzes')
        .doc(quizId)
        .update(<String, dynamic>{
      'type': type,
      'tag': tag,
      'question': question.trim(),
      'options': options,
      'answer': answer,
      'explanation': explanation.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 퀴즈 삭제(본인 것).
  Future<void> deleteQuiz(String hotelId, String quizId) async {
    await _db
        .collection('hotels')
        .doc(hotelId)
        .collection('quizzes')
        .doc(quizId)
        .delete();
  }
}

class HotelQuizItem {
  HotelQuizItem({
    required this.id,
    required this.type,
    required this.tag,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.solveCount,
    required this.correctCount,
  });

  final String id;
  final String type; // ox | mcq | short
  final String tag;
  final String question;
  final List<String> options;
  final Object? answer;
  final String explanation;
  final int solveCount;
  final int correctCount;

  factory HotelQuizItem.fromDoc(String id, Map<String, dynamic>? data) {
    final m = data ?? const <String, dynamic>{};
    final rawOptions = m['options'];
    return HotelQuizItem(
      id: id,
      type: (m['type'] as String?) ?? 'ox',
      tag: (m['tag'] as String?) ?? 'general',
      question: (m['question'] as String?) ?? '',
      options: rawOptions is List
          ? rawOptions.map((e) => e.toString()).toList()
          : <String>[],
      answer: m['answer'],
      explanation: (m['explanation'] as String?) ?? '',
      solveCount: (m['solveCount'] as num?)?.toInt() ?? 0,
      correctCount: (m['correctCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class HotelCatchHotel {
  HotelCatchHotel({
    required this.id,
    required this.name,
    required this.city,
    required this.brand,
  });

  final String id;
  final String name;
  final String city;
  final String brand;

  factory HotelCatchHotel.fromDoc(String id, Map<String, dynamic>? data) {
    final m = data ?? const <String, dynamic>{};
    return HotelCatchHotel(
      id: id,
      name: (m['name'] as String?) ?? '',
      city: (m['city'] as String?) ?? '',
      brand: (m['brand'] as String?) ?? 'other',
    );
  }
}
