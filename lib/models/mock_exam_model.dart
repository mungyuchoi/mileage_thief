import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

Map<String, int> _asIntMap(dynamic value) {
  if (value is! Map) return const <String, int>{};
  return value.map<String, int>(
    (key, item) => MapEntry(key.toString(), _asInt(item)),
  );
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

class MockExam {
  final String id;
  final String title;
  final String description;
  final String status;
  final int roundNo;
  final int questionCount;
  final int totalScore;
  final int timeLimitSeconds;
  final List<String> categories;

  const MockExam({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.roundNo,
    required this.questionCount,
    required this.totalScore,
    required this.timeLimitSeconds,
    required this.categories,
  });

  bool get isDraft => status == 'draft';
  bool get isPublished => status == 'published';
  bool get isLocked => status == 'locked';

  factory MockExam.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return MockExam(
      id: doc.id,
      title: _asString(data['title'], '마일고사'),
      description: _asString(data['description']),
      status: _asString(data['status'], 'draft'),
      roundNo: _asInt(data['roundNo']),
      questionCount: _asInt(data['questionCount']),
      totalScore: _asInt(data['totalScore'], 100),
      timeLimitSeconds: _asInt(data['timeLimitSeconds'], 600),
      categories: _asStringList(data['categories']),
    );
  }
}

class MockExamChoice {
  final String id;
  final String text;

  const MockExamChoice({
    required this.id,
    required this.text,
  });

  factory MockExamChoice.fromMap(Map<String, dynamic> data) {
    return MockExamChoice(
      id: _asString(data['id']),
      text: _asString(data['text']),
    );
  }
}

class MockExamQuestion {
  final String id;
  final String category;
  final int order;
  final int score;
  final String difficulty;
  final String question;
  final String? imageUrl;
  final List<MockExamChoice> choices;
  final List<String> tags;

  const MockExamQuestion({
    required this.id,
    required this.category,
    required this.order,
    required this.score,
    required this.difficulty,
    required this.question,
    required this.imageUrl,
    required this.choices,
    required this.tags,
  });

  factory MockExamQuestion.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawChoices = data['choices'];
    return MockExamQuestion(
      id: doc.id,
      category: _asString(data['category']),
      order: _asInt(data['order']),
      score: _asInt(data['score'], 5),
      difficulty: _asString(data['difficulty'], 'normal'),
      question: _asString(data['question']),
      imageUrl: _asString(data['imageUrl']).isEmpty
          ? null
          : _asString(data['imageUrl']),
      choices: rawChoices is List
          ? rawChoices
              .whereType<Map>()
              .map((item) => MockExamChoice.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const <MockExamChoice>[],
      tags: _asStringList(data['tags']),
    );
  }

  String choiceText(String? choiceId) {
    if (choiceId == null || choiceId.isEmpty) return '미응답';
    for (final choice in choices) {
      if (choice.id == choiceId) return choice.text;
    }
    return choiceId;
  }
}

class MockExamProgress {
  final String examId;
  final bool completed;
  final int attemptCount;
  final int bestScore;
  final int bestDurationSeconds;
  final String? bestAttemptId;
  final int retryTickets;
  final int retryTicketsUsed;
  final bool shareRewardGranted;
  final DateTime? lastSubmittedAt;

  const MockExamProgress({
    required this.examId,
    required this.completed,
    required this.attemptCount,
    required this.bestScore,
    required this.bestDurationSeconds,
    required this.bestAttemptId,
    required this.retryTickets,
    required this.retryTicketsUsed,
    required this.shareRewardGranted,
    required this.lastSubmittedAt,
  });

  bool get canRetry => retryTickets > 0;

  factory MockExamProgress.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return MockExamProgress(
      examId: _asString(data['examId'], doc.id),
      completed: data['completed'] == true,
      attemptCount: _asInt(data['attemptCount']),
      bestScore: _asInt(data['bestScore']),
      bestDurationSeconds: _asInt(data['bestDurationSeconds']),
      bestAttemptId: _asString(data['bestAttemptId']).isEmpty
          ? null
          : _asString(data['bestAttemptId']),
      retryTickets: _asInt(data['retryTickets']),
      retryTicketsUsed: _asInt(data['retryTicketsUsed']),
      shareRewardGranted: data['shareRewardGranted'] == true,
      lastSubmittedAt: _asDateTime(data['lastSubmittedAt']),
    );
  }
}

class MockExamAttemptAnswer {
  final String questionId;
  final String? selectedChoiceId;
  final String? correctChoiceId;
  final String answerText;
  final bool isCorrect;
  final int score;
  final String category;
  final String explanation;

  const MockExamAttemptAnswer({
    required this.questionId,
    required this.selectedChoiceId,
    required this.correctChoiceId,
    required this.answerText,
    required this.isCorrect,
    required this.score,
    required this.category,
    required this.explanation,
  });

  factory MockExamAttemptAnswer.fromMap(Map<String, dynamic> data) {
    final selected = _asString(data['selectedChoiceId']);
    final correct = _asString(data['correctChoiceId']);
    return MockExamAttemptAnswer(
      questionId: _asString(data['questionId']),
      selectedChoiceId: selected.isEmpty ? null : selected,
      correctChoiceId: correct.isEmpty ? null : correct,
      answerText: _asString(data['answerText']),
      isCorrect: data['isCorrect'] == true,
      score: _asInt(data['score']),
      category: _asString(data['category']),
      explanation: _asString(data['explanation']),
    );
  }
}

class MockExamAttempt {
  final String id;
  final String examId;
  final int roundNo;
  final String status;
  final int score;
  final int totalScore;
  final int correctCount;
  final int questionCount;
  final int durationSeconds;
  final Map<String, int> categoryScores;
  final List<MockExamAttemptAnswer> answers;
  final bool isBestAttempt;
  final DateTime? startedAt;
  final DateTime? submittedAt;

  const MockExamAttempt({
    required this.id,
    required this.examId,
    required this.roundNo,
    required this.status,
    required this.score,
    required this.totalScore,
    required this.correctCount,
    required this.questionCount,
    required this.durationSeconds,
    required this.categoryScores,
    required this.answers,
    required this.isBestAttempt,
    required this.startedAt,
    required this.submittedAt,
  });

  factory MockExamAttempt.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawAnswers = data['answers'];
    return MockExamAttempt(
      id: doc.id,
      examId: _asString(data['examId']),
      roundNo: _asInt(data['roundNo']),
      status: _asString(data['status']),
      score: _asInt(data['score']),
      totalScore: _asInt(data['totalScore'], 100),
      correctCount: _asInt(data['correctCount']),
      questionCount: _asInt(data['questionCount']),
      durationSeconds: _asInt(data['durationSeconds']),
      categoryScores: _asIntMap(data['categoryScores']),
      answers: rawAnswers is List
          ? rawAnswers
              .whereType<Map>()
              .map((item) => MockExamAttemptAnswer.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const <MockExamAttemptAnswer>[],
      isBestAttempt: data['isBestAttempt'] == true,
      startedAt: _asDateTime(data['startedAt']),
      submittedAt: _asDateTime(data['submittedAt']),
    );
  }
}

class MockExamLeaderboardEntry {
  final String uid;
  final String displayName;
  final String photoUrl;
  final int score;
  final int durationSeconds;
  final String attemptId;
  final DateTime? submittedAt;

  const MockExamLeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.score,
    required this.durationSeconds,
    required this.attemptId,
    required this.submittedAt,
  });

  factory MockExamLeaderboardEntry.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return MockExamLeaderboardEntry(
      uid: _asString(data['uid'], doc.id),
      displayName: _asString(data['displayName'], '익명'),
      photoUrl: _asString(data['photoUrl']),
      score: _asInt(data['score']),
      durationSeconds: _asInt(data['durationSeconds']),
      attemptId: _asString(data['attemptId']),
      submittedAt: _asDateTime(data['submittedAt']),
    );
  }
}
