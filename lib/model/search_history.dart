class SearchHistory {
  final String departure;
  final String arrival;
  final int startYear;
  final int startMonth;
  final int endYear;
  final int endMonth;
  SearchHistory({
    required this.departure,
    required this.arrival,
    required this.startYear,
    required this.startMonth,
    required this.endYear,
    required this.endMonth,
  });

  // 동등성 비교(중복 방지용)
  @override
  bool operator ==(Object other) {
    return other is SearchHistory &&
      other.departure == departure &&
      other.arrival == arrival &&
      other.startYear == startYear &&
      other.startMonth == startMonth &&
      other.endYear == endYear &&
      other.endMonth == endMonth;
  }
  @override
  int get hashCode => Object.hash(departure, arrival, startYear, startMonth, endYear, endMonth);
} 