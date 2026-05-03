import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class CardTransactionService {
  CardTransactionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _userCardsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('cards');

  CollectionReference<Map<String, dynamic>> _transactionsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('cardTransactions');

  CollectionReference<Map<String, dynamic>> _overridesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('cardOverrides');

  Future<CardDashboardData> loadDashboardData({
    required String uid,
    DateTime? month,
  }) async {
    final monthStart = _monthStart(month ?? DateTime.now());
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1);

    final results = await Future.wait([
      _userCardsRef(uid).orderBy('name').get(),
      _transactionsRef(uid)
          .where('occurredAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('occurredAt', isLessThan: Timestamp.fromDate(monthEnd))
          .get(),
    ]);

    final cardsSnapshot = results[0];
    final transactionsSnapshot = results[1];

    final cards = cardsSnapshot.docs
        .map(UserCardRecord.fromFirestore)
        .toList(growable: false);
    final transactions = transactionsSnapshot.docs
        .map(CardTransactionRecord.fromFirestore)
        .where((transaction) => transaction.isActive)
        .toList();

    transactions.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return CardDashboardData(
      monthStart: monthStart,
      monthEnd: monthEnd,
      cards: cards,
      transactions: transactions,
    );
  }

  Future<void> syncGiftLotsForMonth({
    required String uid,
    DateTime? month,
  }) async {
    final monthStart = _monthStart(month ?? DateTime.now());
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1);
    final lotsSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('lots')
        .where('buyDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('buyDate', isLessThan: Timestamp.fromDate(monthEnd))
        .get();

    for (final lot in lotsSnapshot.docs) {
      await upsertGiftLotTransaction(
        uid: uid,
        lotId: lot.id,
        lotData: lot.data(),
      );
    }
  }

  Future<void> upsertGiftLotTransaction({
    required String uid,
    required String lotId,
    required Map<String, dynamic> lotData,
  }) async {
    final cardId = _asString(lotData['cardId']);
    final buyUnit = _asInt(lotData['buyUnit']);
    final qty = _asInt(lotData['qty']);
    final amount = buyUnit * qty;

    if (cardId.isEmpty || amount <= 0) {
      await deleteGiftLotTransaction(uid: uid, lotId: lotId);
      return;
    }

    final occurredAt = _asDate(lotData['buyDate']) ?? DateTime.now();
    final mileRule = _asInt(lotData['mileRuleUsedPerMileKRW']);
    final storedMiles = _asInt(lotData['miles']);
    final defaultMiles = storedMiles > 0
        ? storedMiles
        : (mileRule > 0 ? (amount / mileRule).round() : 0);

    final transactionRef = _transactionsRef(uid).doc('gift_lot_$lotId');
    final existing = await transactionRef.get();
    final existingData = existing.data() ?? const <String, dynamic>{};
    final existingPerformance = _map(existingData['performance']);
    final existingReward = _map(existingData['reward']);
    final performanceOverridden = existingPerformance['overridden'] == true;
    final rewardOverridden = existingReward['overridden'] == true;

    final performanceEligible =
        performanceOverridden ? existingPerformance['eligible'] == true : true;
    final rewardEligible = rewardOverridden
        ? existingReward['eligible'] == true
        : defaultMiles > 0;
    final rewardRule = rewardOverridden
        ? _asInt(existingReward['mileRuleUsedPerMileKRW'])
        : mileRule;
    final rewardMiles =
        rewardEligible && rewardRule > 0 ? (amount / rewardRule).round() : 0;

    await transactionRef.set({
      'cardId': cardId,
      'source': 'gift_lot',
      'occurredAt': Timestamp.fromDate(occurredAt),
      'amountKRW': amount,
      'merchantName': '상품권 구매',
      'category': 'giftcard',
      'status': 'posted',
      'linkedGiftLotId': lotId,
      'rawSourceKey': 'users/$uid/lots/$lotId',
      'performance': {
        'eligible': performanceEligible,
        'amountKRW': performanceEligible ? amount : 0,
        'reasonCodes': performanceEligible ? <String>[] : ['user_excluded'],
        'overridden': performanceOverridden,
      },
      'reward': {
        'eligible': rewardEligible,
        'miles': rewardMiles,
        'mileRuleUsedPerMileKRW': rewardRule,
        'reasonCodes': rewardEligible ? <String>[] : ['no_mile_rule'],
        'overridden': rewardOverridden,
      },
      'needsReview': false,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteGiftLotTransaction({
    required String uid,
    required String lotId,
  }) {
    return _transactionsRef(uid).doc('gift_lot_$lotId').delete();
  }

  Future<void> createManualTransaction({
    required String uid,
    required String cardId,
    required DateTime occurredAt,
    required int amountKRW,
    required String merchantName,
    required String category,
    required bool performanceEligible,
    required bool rewardEligible,
    required int mileRuleUsedPerMileKRW,
  }) async {
    final transactionId = 'manual_${DateTime.now().millisecondsSinceEpoch}';
    final miles = rewardEligible && mileRuleUsedPerMileKRW > 0
        ? (amountKRW / mileRuleUsedPerMileKRW).round()
        : 0;

    await _transactionsRef(uid).doc(transactionId).set({
      'cardId': cardId,
      'source': 'manual',
      'occurredAt': Timestamp.fromDate(occurredAt),
      'amountKRW': amountKRW,
      'merchantName':
          merchantName.trim().isEmpty ? '수동 입력' : merchantName.trim(),
      'category': category.trim().isEmpty ? 'general' : category.trim(),
      'status': 'posted',
      'rawSourceKey': transactionId,
      'performance': {
        'eligible': performanceEligible,
        'amountKRW': performanceEligible ? amountKRW : 0,
        'reasonCodes': performanceEligible ? <String>[] : ['user_excluded'],
        'overridden': true,
      },
      'reward': {
        'eligible': rewardEligible,
        'miles': miles,
        'mileRuleUsedPerMileKRW': mileRuleUsedPerMileKRW,
        'reasonCodes': rewardEligible ? <String>[] : ['user_excluded'],
        'overridden': true,
      },
      'needsReview': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveTransactionOverride({
    required String uid,
    required CardTransactionRecord transaction,
    required bool performanceEligible,
    required bool rewardEligible,
    required int mileRuleUsedPerMileKRW,
    required bool applyToFuture,
    String memo = '',
  }) async {
    final miles = rewardEligible && mileRuleUsedPerMileKRW > 0
        ? (transaction.amountKRW / mileRuleUsedPerMileKRW).round()
        : 0;
    final reasonCodes = <String>[];
    if (!performanceEligible || !rewardEligible) {
      reasonCodes.add('user_excluded');
    }

    final batch = _firestore.batch();
    final transactionRef = _transactionsRef(uid).doc(transaction.id);
    batch.set(
      transactionRef,
      {
        'performance': {
          'eligible': performanceEligible,
          'amountKRW': performanceEligible ? transaction.amountKRW : 0,
          'reasonCodes': performanceEligible ? <String>[] : reasonCodes,
          'overridden': true,
        },
        'reward': {
          'eligible': rewardEligible,
          'miles': miles,
          'mileRuleUsedPerMileKRW': mileRuleUsedPerMileKRW,
          'reasonCodes': rewardEligible ? <String>[] : reasonCodes,
          'overridden': true,
        },
        'needsReview': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final overrideRef = _overridesRef(uid).doc('transaction_${transaction.id}');
    batch.set(
      overrideRef,
      {
        'cardId': transaction.cardId,
        'scope': 'transaction',
        'transactionId': transaction.id,
        'merchantName': transaction.merchantName,
        'category': transaction.category,
        'performanceEligible': performanceEligible,
        'rewardEligible': rewardEligible,
        'mileRuleUsedPerMileKRW': mileRuleUsedPerMileKRW,
        'applyToFuture': applyToFuture,
        'memo': memo.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (applyToFuture) {
      final merchantOverrideId =
          'merchant_${_stableIdSegment('${transaction.cardId}_${transaction.merchantName}')}';
      batch.set(
        _overridesRef(uid).doc(merchantOverrideId),
        {
          'cardId': transaction.cardId,
          'scope': 'merchant',
          'merchantName': transaction.merchantName,
          'category': transaction.category,
          'performanceEligible': performanceEligible,
          'rewardEligible': rewardEligible,
          'mileRuleUsedPerMileKRW': mileRuleUsedPerMileKRW,
          'applyToFuture': true,
          'memo': memo.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static DateTime _monthStart(DateTime date) => DateTime(date.year, date.month);
}

abstract class CardTransactionConnector {
  String get source;
}

class GiftLotConnector implements CardTransactionConnector {
  GiftLotConnector(this.service);

  final CardTransactionService service;

  @override
  String get source => 'gift_lot';

  Future<void> syncLot({
    required String uid,
    required String lotId,
    required Map<String, dynamic> lotData,
  }) {
    return service.upsertGiftLotTransaction(
      uid: uid,
      lotId: lotId,
      lotData: lotData,
    );
  }
}

class ManualConnector implements CardTransactionConnector {
  ManualConnector(this.service);

  final CardTransactionService service;

  @override
  String get source => 'manual';
}

class MyDataConnector implements CardTransactionConnector {
  const MyDataConnector();

  @override
  String get source => 'mydata';
}

class CardDashboardData {
  CardDashboardData({
    required this.monthStart,
    required this.monthEnd,
    required this.cards,
    required this.transactions,
  });

  final DateTime monthStart;
  final DateTime monthEnd;
  final List<UserCardRecord> cards;
  final List<CardTransactionRecord> transactions;

  CardDashboardSummary get summary {
    final performanceAmount = transactions.fold<int>(
      0,
      (total, transaction) => total + transaction.performanceAmountKRW,
    );
    final rewardMiles = transactions.fold<int>(
      0,
      (total, transaction) => total + transaction.rewardMiles,
    );
    final excludedAmount = transactions.fold<int>(
      0,
      (total, transaction) =>
          total + (transaction.performanceEligible ? 0 : transaction.amountKRW),
    );
    final needsReviewCount =
        transactions.where((transaction) => transaction.needsReview).length;

    return CardDashboardSummary(
      cardCount: cards.length,
      performanceAmountKRW: performanceAmount,
      rewardMiles: rewardMiles,
      excludedAmountKRW: excludedAmount,
      needsReviewCount: needsReviewCount,
    );
  }

  List<CardDashboardCardSummary> get cardSummaries {
    return cards.map((card) {
      final cardTransactions = transactions
          .where((transaction) => transaction.cardId == card.id)
          .toList(growable: false);
      final performanceAmount = cardTransactions.fold<int>(
        0,
        (total, transaction) => total + transaction.performanceAmountKRW,
      );
      final rewardMiles = cardTransactions.fold<int>(
        0,
        (total, transaction) => total + transaction.rewardMiles,
      );
      final excludedAmount = cardTransactions.fold<int>(
        0,
        (total, transaction) =>
            total +
            (transaction.performanceEligible ? 0 : transaction.amountKRW),
      );
      final targetSpend = card.targetSpendKRW;
      final progress = targetSpend <= 0
          ? 0.0
          : math.min(1.0, performanceAmount / targetSpend);

      return CardDashboardCardSummary(
        card: card,
        transactions: cardTransactions,
        performanceAmountKRW: performanceAmount,
        rewardMiles: rewardMiles,
        excludedAmountKRW: excludedAmount,
        targetSpendKRW: targetSpend,
        remainingSpendKRW: math.max(0, targetSpend - performanceAmount),
        progress: progress,
        needsReviewCount: cardTransactions
            .where((transaction) => transaction.needsReview)
            .length,
      );
    }).toList(growable: false);
  }
}

class CardDashboardSummary {
  const CardDashboardSummary({
    required this.cardCount,
    required this.performanceAmountKRW,
    required this.rewardMiles,
    required this.excludedAmountKRW,
    required this.needsReviewCount,
  });

  final int cardCount;
  final int performanceAmountKRW;
  final int rewardMiles;
  final int excludedAmountKRW;
  final int needsReviewCount;
}

class CardDashboardCardSummary {
  const CardDashboardCardSummary({
    required this.card,
    required this.transactions,
    required this.performanceAmountKRW,
    required this.rewardMiles,
    required this.excludedAmountKRW,
    required this.targetSpendKRW,
    required this.remainingSpendKRW,
    required this.progress,
    required this.needsReviewCount,
  });

  final UserCardRecord card;
  final List<CardTransactionRecord> transactions;
  final int performanceAmountKRW;
  final int rewardMiles;
  final int excludedAmountKRW;
  final int targetSpendKRW;
  final int remainingSpendKRW;
  final double progress;
  final int needsReviewCount;
}

class UserCardRecord {
  const UserCardRecord({
    required this.id,
    required this.name,
    required this.creditPerMileKRW,
    required this.checkPerMileKRW,
    required this.targetSpendKRW,
    required this.raw,
    this.catalogCardId,
    this.statementCycle,
  });

  final String id;
  final String name;
  final int creditPerMileKRW;
  final int checkPerMileKRW;
  final int targetSpendKRW;
  final String? catalogCardId;
  final String? statementCycle;
  final Map<String, dynamic> raw;

  factory UserCardRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UserCardRecord(
      id: doc.id,
      name: _asString(data['name']).isEmpty ? doc.id : _asString(data['name']),
      creditPerMileKRW: _asInt(data['creditPerMileKRW']),
      checkPerMileKRW: _asInt(data['checkPerMileKRW']),
      targetSpendKRW:
          _asInt(data['targetSpendKRW'] ?? data['monthlyTargetSpendKRW']),
      catalogCardId: _nullableString(data['catalogCardId']),
      statementCycle: _nullableString(data['statementCycle']),
      raw: data,
    );
  }

  int get defaultMileRuleKRW {
    if (creditPerMileKRW > 0) return creditPerMileKRW;
    if (checkPerMileKRW > 0) return checkPerMileKRW;
    return 0;
  }
}

class CardTransactionRecord {
  const CardTransactionRecord({
    required this.id,
    required this.cardId,
    required this.source,
    required this.occurredAt,
    required this.amountKRW,
    required this.merchantName,
    required this.category,
    required this.status,
    required this.performanceEligible,
    required this.performanceAmountKRW,
    required this.performanceOverridden,
    required this.rewardEligible,
    required this.rewardMiles,
    required this.rewardMileRuleKRW,
    required this.rewardOverridden,
    required this.needsReview,
    required this.raw,
    this.linkedGiftLotId,
    this.rawSourceKey,
  });

  final String id;
  final String cardId;
  final String source;
  final DateTime occurredAt;
  final int amountKRW;
  final String merchantName;
  final String category;
  final String status;
  final bool performanceEligible;
  final int performanceAmountKRW;
  final bool performanceOverridden;
  final bool rewardEligible;
  final int rewardMiles;
  final int rewardMileRuleKRW;
  final bool rewardOverridden;
  final bool needsReview;
  final String? linkedGiftLotId;
  final String? rawSourceKey;
  final Map<String, dynamic> raw;

  factory CardTransactionRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final performance = _map(data['performance']);
    final reward = _map(data['reward']);
    final amount = _asInt(data['amountKRW']);
    final performanceEligible = performance['eligible'] != false;
    final rewardEligible = reward['eligible'] != false;

    return CardTransactionRecord(
      id: doc.id,
      cardId: _asString(data['cardId']),
      source: _asString(data['source']).isEmpty
          ? 'manual'
          : _asString(data['source']),
      occurredAt:
          _asDate(data['occurredAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      amountKRW: amount,
      merchantName: _asString(data['merchantName']).isEmpty
          ? '거래처 미입력'
          : _asString(data['merchantName']),
      category: _asString(data['category']).isEmpty
          ? 'general'
          : _asString(data['category']),
      status: _asString(data['status']).isEmpty
          ? 'posted'
          : _asString(data['status']),
      performanceEligible: performanceEligible,
      performanceAmountKRW: performanceEligible
          ? _asInt(performance['amountKRW']).clamp(0, amount).toInt()
          : 0,
      performanceOverridden: performance['overridden'] == true,
      rewardEligible: rewardEligible,
      rewardMiles: rewardEligible ? _asInt(reward['miles']) : 0,
      rewardMileRuleKRW: _asInt(reward['mileRuleUsedPerMileKRW']),
      rewardOverridden: reward['overridden'] == true,
      needsReview: data['needsReview'] == true,
      linkedGiftLotId: _nullableString(data['linkedGiftLotId']),
      rawSourceKey: _nullableString(data['rawSourceKey']),
      raw: data,
    );
  }

  bool get isActive => status != 'deleted' && status != 'canceled';
}

String _asString(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String? _nullableString(dynamic value) {
  final text = _asString(value);
  return text.isEmpty ? null : text;
}

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
}

DateTime? _asDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String _stableIdSegment(String value) {
  final trimmed = value.trim().toLowerCase();
  if (trimmed.isEmpty) return 'unknown';
  return trimmed.codeUnits
      .take(64)
      .map((unit) => unit.toRadixString(16).padLeft(4, '0'))
      .join();
}
