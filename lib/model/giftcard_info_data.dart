class GiftcardInfoData {
  final List<Map<String, dynamic>> lots;
  final List<Map<String, dynamic>> sales;

  /// cardId -> {name, credit, check}
  final Map<String, Map<String, dynamic>> cards;

  /// giftcardId -> name
  final Map<String, String> giftcardNames;

  /// branchId -> name
  final Map<String, String> branchNames;

  /// whereToBuyId -> name
  final Map<String, String> whereToBuyNames;

  const GiftcardInfoData({
    required this.lots,
    required this.sales,
    required this.cards,
    required this.giftcardNames,
    required this.branchNames,
    required this.whereToBuyNames,
  });
}


