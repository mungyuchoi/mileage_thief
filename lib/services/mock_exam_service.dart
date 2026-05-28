import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/mock_exam_model.dart';

class MockExamService {
  MockExamService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> get _root =>
      _firestore.collection('mockExam').doc('main');

  CollectionReference<Map<String, dynamic>> get _examsRef =>
      _root.collection('exams');

  CollectionReference<Map<String, dynamic>> _userAttemptsRef(String uid) =>
      _root.collection('users').doc(uid).collection('attempts');

  CollectionReference<Map<String, dynamic>> _userProgressRef(String uid) =>
      _root.collection('users').doc(uid).collection('progress');

  Future<bool> isAdminUser(User? user) async {
    if (user == null) return false;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final roles = doc.data()?['roles'];
    if (roles is List) {
      return roles.any((role) {
        final value = role.toString().trim();
        return value == 'admin' || value == 'owner';
      });
    }
    if (roles is Map) {
      return roles['admin'] == true || roles['owner'] == true;
    }
    if (roles is String) {
      final value = roles.trim();
      return value == 'admin' || value == 'owner';
    }
    return false;
  }

  Future<List<MockExam>> loadExams({required bool includeDraft}) async {
    final query = includeDraft
        ? _examsRef
        : _examsRef.where('status', whereIn: ['published', 'locked']);
    final snapshot = await query.get();
    final exams = snapshot.docs
        .map(MockExam.fromFirestore)
        .where((exam) =>
            exam.isPublished || exam.isLocked || (includeDraft && exam.isDraft))
        .toList(growable: false);
    exams.sort((a, b) => a.roundNo.compareTo(b.roundNo));
    return exams;
  }

  Future<MockExam?> loadExam(String examId) async {
    final doc = await _examsRef.doc(examId).get();
    if (!doc.exists) return null;
    return MockExam.fromFirestore(doc);
  }

  Future<List<MockExamQuestion>> loadQuestions(String examId) async {
    final snapshot = await _examsRef
        .doc(examId)
        .collection('questions')
        .orderBy('order')
        .get();
    return snapshot.docs
        .map(MockExamQuestion.fromFirestore)
        .toList(growable: false);
  }

  Future<Map<String, MockExamProgress>> loadProgressMap(String uid) async {
    final snapshot = await _userProgressRef(uid).get();
    return {
      for (final doc in snapshot.docs)
        doc.id: MockExamProgress.fromFirestore(doc),
    };
  }

  Future<MockExamProgress?> loadProgress({
    required String uid,
    required String examId,
  }) async {
    final doc = await _userProgressRef(uid).doc(examId).get();
    if (!doc.exists) return null;
    return MockExamProgress.fromFirestore(doc);
  }

  Future<String> startMockExam(String examId) async {
    final callable = _functions.httpsCallable('startMockExam');
    final result = await callable.call<Map<String, dynamic>>({
      'examId': examId,
    });
    final data = Map<String, dynamic>.from(result.data);
    return data['attemptId']?.toString() ?? '';
  }

  Future<MockExamSubmitResult> submitMockExam({
    required String examId,
    required String attemptId,
    required Map<String, String> selectedAnswers,
  }) async {
    final callable = _functions.httpsCallable(
      'submitMockExam',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 40)),
    );
    final result = await callable.call<Map<String, dynamic>>({
      'examId': examId,
      'attemptId': attemptId,
      'answers': selectedAnswers.entries
          .map((entry) => {
                'questionId': entry.key,
                'selectedChoiceId': entry.value,
              })
          .toList(growable: false),
    });
    final submitData = Map<String, dynamic>.from(result.data);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: '로그인이 필요합니다.',
      );
    }

    final attempt = await loadAttempt(uid: user.uid, attemptId: attemptId);
    if (attempt == null) {
      throw FirebaseFunctionsException(
        code: 'not-found',
        message: '응시 결과를 찾을 수 없습니다.',
      );
    }
    return MockExamSubmitResult(
      attempt: attempt,
      peanutRewardGranted: submitData['peanutRewardGranted'] == true,
      peanutRewardAmount: _asInt(submitData['peanutRewardAmount']),
    );
  }

  Future<bool> grantShareRetry({
    required String examId,
    required String attemptId,
    required String shareUrl,
  }) async {
    final callable = _functions.httpsCallable('grantMockExamShareRetry');
    final result = await callable.call<Map<String, dynamic>>({
      'examId': examId,
      'attemptId': attemptId,
      'shareUrl': shareUrl,
    });
    final data = Map<String, dynamic>.from(result.data);
    return data['granted'] == true;
  }

  Future<void> purchaseRetryWithPeanuts({
    required String examId,
    required String attemptId,
  }) async {
    final callable =
        _functions.httpsCallable('purchaseMockExamRetryWithPeanuts');
    await callable.call<Map<String, dynamic>>({
      'examId': examId,
      'attemptId': attemptId,
    });
  }

  Future<void> updateExamStatus({
    required String examId,
    required String status,
  }) async {
    final callable = _functions.httpsCallable('updateMockExamStatus');
    await callable.call<Map<String, dynamic>>({
      'examId': examId,
      'status': status,
    });
  }

  Future<MockExamAttempt?> loadAttempt({
    required String uid,
    required String attemptId,
  }) async {
    final doc = await _userAttemptsRef(uid).doc(attemptId).get();
    if (!doc.exists) return null;
    return MockExamAttempt.fromFirestore(doc);
  }

  Future<List<MockExamLeaderboardEntry>> loadLeaderboard({
    required String examId,
    int limit = 100,
  }) async {
    final snapshot = await _root
        .collection('leaderboards')
        .doc(examId)
        .collection('periods')
        .doc('all')
        .collection('entries')
        .orderBy('score', descending: true)
        .limit(limit)
        .get();
    final entries = snapshot.docs
        .map(MockExamLeaderboardEntry.fromFirestore)
        .toList(growable: false);
    entries.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      final durationCompare = a.durationSeconds.compareTo(b.durationSeconds);
      if (durationCompare != 0) return durationCompare;
      final aSubmitted = a.submittedAt?.millisecondsSinceEpoch ?? 0;
      final bSubmitted = b.submittedAt?.millisecondsSinceEpoch ?? 0;
      return aSubmitted.compareTo(bSubmitted);
    });
    return entries;
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class MockExamSubmitResult {
  final MockExamAttempt attempt;
  final bool peanutRewardGranted;
  final int peanutRewardAmount;

  const MockExamSubmitResult({
    required this.attempt,
    required this.peanutRewardGranted,
    required this.peanutRewardAmount,
  });
}
