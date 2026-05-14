class CommunityLabel {
  final String key;
  final String type;
  final String targetId;
  final String displayName;
  final String subtitle;
  final String linkValue;
  final String sourcePath;

  const CommunityLabel({
    required this.key,
    required this.type,
    required this.targetId,
    required this.displayName,
    required this.subtitle,
    required this.linkValue,
    required this.sourcePath,
  });

  factory CommunityLabel.branch({
    required String branchId,
    required String name,
  }) {
    final id = branchId.trim();
    return CommunityLabel(
      key: 'branch:$id',
      type: 'branch',
      targetId: id,
      displayName: name.trim().isEmpty ? id : name.trim(),
      subtitle: '상품권 지점',
      linkValue: 'branch:$id',
      sourcePath: 'branches/$id',
    );
  }

  factory CommunityLabel.giftcard({
    required String giftcardId,
    required String name,
  }) {
    final id = giftcardId.trim();
    return CommunityLabel(
      key: 'giftcard:$id',
      type: 'giftcard',
      targetId: id,
      displayName: name.trim().isEmpty ? id : name.trim(),
      subtitle: '상품권 시세',
      linkValue: 'giftcard-rate:$id',
      sourcePath: 'giftcards/$id',
    );
  }

  factory CommunityLabel.card({
    required String cardId,
    required String name,
    String issuerName = '',
  }) {
    final id = cardId.trim();
    final issuer = issuerName.trim();
    return CommunityLabel(
      key: 'card:$id',
      type: 'card',
      targetId: id,
      displayName: name.trim().isEmpty ? id : name.trim(),
      subtitle: issuer.isEmpty ? '카드' : issuer,
      linkValue: 'card:$id',
      sourcePath: 'cards/catalog/cardProducts/$id',
    );
  }

  factory CommunityLabel.giftcardCalculator() {
    return const CommunityLabel(
      key: 'calculator:giftcard',
      type: 'calculator',
      targetId: 'giftcard',
      displayName: '상품권 계산기',
      subtitle: '계산',
      linkValue: 'calculator:giftcard',
      sourcePath: '',
    );
  }

  factory CommunityLabel.fromMap(Map<String, dynamic> map) {
    final type = _string(map['type'] ?? map['labelType']);
    final targetId = _string(map['targetId']);
    final fallbackKey = type.isEmpty || targetId.isEmpty
        ? _string(map['key'] ?? map['labelId'])
        : '$type:$targetId';
    return CommunityLabel(
      key: _string(map['key'] ?? map['labelId'], fallback: fallbackKey),
      type: type,
      targetId: targetId,
      displayName: _string(
        map['displayName'] ?? map['labelName'],
        fallback: targetId,
      ),
      subtitle: _string(map['subtitle']),
      linkValue: _string(map['linkValue'] ?? map['deepLink']),
      sourcePath: _string(map['sourcePath']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'type': type,
      'targetId': targetId,
      'displayName': displayName,
      'subtitle': subtitle,
      'linkValue': linkValue,
      'sourcePath': sourcePath,
    };
  }

  bool get isValid =>
      key.trim().isNotEmpty &&
      type.trim().isNotEmpty &&
      targetId.trim().isNotEmpty &&
      displayName.trim().isNotEmpty &&
      linkValue.trim().isNotEmpty;

  static List<CommunityLabel> dedupe(Iterable<CommunityLabel> labels) {
    final seen = <String>{};
    final result = <CommunityLabel>[];
    for (final label in labels) {
      if (!label.isValid) continue;
      if (!seen.add(label.key)) continue;
      result.add(label);
    }
    return result;
  }

  static List<CommunityLabel> listFromMaps(Object? raw) {
    if (raw is! List) return const <CommunityLabel>[];
    return dedupe(
      raw.whereType<Map>().map(
            (map) => CommunityLabel.fromMap(
              Map<String, dynamic>.from(map),
            ),
          ),
    );
  }

  static List<CommunityLabel> listFromEntityRefs(Map<String, dynamic> refs) {
    final labels = <CommunityLabel>[];

    for (final id in _stringList(refs['branchIds'])) {
      labels.add(CommunityLabel.branch(branchId: id, name: id));
    }
    final branchId = _string(refs['branchId']);
    if (branchId.isNotEmpty) {
      labels.add(CommunityLabel.branch(branchId: branchId, name: branchId));
    }

    for (final id in _stringList(refs['giftcardIds'])) {
      labels.add(CommunityLabel.giftcard(giftcardId: id, name: id));
    }
    final giftcardId = _string(refs['giftcardId']);
    if (giftcardId.isNotEmpty) {
      labels.add(
        CommunityLabel.giftcard(giftcardId: giftcardId, name: giftcardId),
      );
    }

    for (final id in _stringList(refs['cardIds'])) {
      labels.add(CommunityLabel.card(cardId: id, name: id));
    }
    final cardId = _string(refs['cardId']);
    if (cardId.isNotEmpty) {
      labels.add(CommunityLabel.card(cardId: cardId, name: cardId));
    }

    final calculators = _stringList(refs['calculatorKinds']);
    if (calculators.contains('giftcard')) {
      labels.add(CommunityLabel.giftcardCalculator());
    }

    return dedupe(labels);
  }
}

class CommunityLabelPayload {
  final List<Map<String, dynamic>> labels;
  final List<String> labelKeys;
  final Map<String, dynamic> entityRefs;

  const CommunityLabelPayload({
    required this.labels,
    required this.labelKeys,
    required this.entityRefs,
  });

  factory CommunityLabelPayload.fromLabels(Iterable<CommunityLabel> rawLabels) {
    final labels = CommunityLabel.dedupe(rawLabels);
    final branchIds = <String>[];
    final giftcardIds = <String>[];
    final cardIds = <String>[];
    final calculatorKinds = <String>[];

    for (final label in labels) {
      switch (label.type) {
        case 'branch':
          branchIds.add(label.targetId);
          break;
        case 'giftcard':
          giftcardIds.add(label.targetId);
          break;
        case 'card':
          cardIds.add(label.targetId);
          break;
        case 'calculator':
          calculatorKinds.add(label.targetId);
          break;
      }
    }

    final entityRefs = <String, dynamic>{};
    if (branchIds.isNotEmpty) {
      entityRefs['branchIds'] = branchIds;
      entityRefs['branchId'] = branchIds.first;
    }
    if (giftcardIds.isNotEmpty) {
      entityRefs['giftcardIds'] = giftcardIds;
      entityRefs['giftcardId'] = giftcardIds.first;
    }
    if (cardIds.isNotEmpty) {
      entityRefs['cardIds'] = cardIds;
      entityRefs['cardId'] = cardIds.first;
    }
    if (calculatorKinds.isNotEmpty) {
      entityRefs['calculatorKinds'] = calculatorKinds;
    }

    return CommunityLabelPayload(
      labels: labels.map((label) => label.toMap()).toList(growable: false),
      labelKeys: labels.map((label) => label.key).toList(growable: false),
      entityRefs: entityRefs,
    );
  }
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw
      .map((value) => value.toString().trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
}
