import 'package:intl/intl.dart';

/// 상품권 대시보드 기간 타입
/// - month: 특정 월
/// - year: 특정 연도 전체
/// - all: 전체 기간
enum DashboardPeriodType { month, year, all }

class GiftcardPeriodRange {
  final DateTime? start;
  final DateTime? end;
  const GiftcardPeriodRange({required this.start, required this.end});
}

GiftcardPeriodRange getGiftcardPeriodRange({
  required DashboardPeriodType periodType,
  required DateTime selectedMonth,
  required int selectedYear,
}) {
  switch (periodType) {
    case DashboardPeriodType.month:
      final start = DateTime(selectedMonth.year, selectedMonth.month);
      final end = DateTime(selectedMonth.year, selectedMonth.month + 1);
      return GiftcardPeriodRange(start: start, end: end);
    case DashboardPeriodType.year:
      final start = DateTime(selectedYear, 1, 1);
      final end = DateTime(selectedYear + 1, 1, 1);
      return GiftcardPeriodRange(start: start, end: end);
    case DashboardPeriodType.all:
      return const GiftcardPeriodRange(start: null, end: null);
  }
}

String giftcardPeriodTitleText({
  required DashboardPeriodType periodType,
  required DateTime selectedMonth,
  required int selectedYear,
}) {
  switch (periodType) {
    case DashboardPeriodType.all:
      return '전체 기간';
    case DashboardPeriodType.year:
      return '${selectedYear}년도 전체';
    case DashboardPeriodType.month:
      final m = selectedMonth.month.toString().padLeft(2, '0');
      return '${selectedMonth.year}년도 $m월';
  }
}

String giftcardPeriodFilterLabel({
  required DashboardPeriodType periodType,
  required DateTime selectedMonth,
  required int selectedYear,
}) {
  switch (periodType) {
    case DashboardPeriodType.all:
      return '전체';
    case DashboardPeriodType.year:
      return '$selectedYear년';
    case DashboardPeriodType.month:
      final m = selectedMonth.month.toString().padLeft(2, '0');
      return '${selectedMonth.year}-$m';
  }
}

String giftcardYmd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);


