import 'dart:async';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../const/colors.dart';
import '../model/event_model.dart';

class MainCalendar extends StatefulWidget {
  final Stream<List<Event>> eventsStream;
  final Function(DateTime selectedDate, DateTime focusedDay) onDaySelected;
  final DateTime selectedDate;
  final DateTime firstDay;
  final DateTime lastDay;

  const MainCalendar({
    Key? key,
    required this.eventsStream,
    required this.onDaySelected,
    required this.selectedDate,
    required this.firstDay,
    required this.lastDay,
  }) : super(key: key);

  @override
  State<MainCalendar> createState() => _MainCalendarState();
}

class _MainCalendarState extends State<MainCalendar> {
  List<Event> _events = [];
  late DateTime _focusedDay;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedDate;
    _subscribeToEvents();
  }

  @override
  void didUpdateWidget(covariant MainCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventsStream != widget.eventsStream) {
      _unsubscribeFromEvents();
      _subscribeToEvents();
    }
    if (oldWidget.selectedDate != widget.selectedDate) {
      _focusedDay = widget.selectedDate;
    }
  }

  @override
  void dispose() {
    _unsubscribeFromEvents();
    super.dispose();
  }

  void _subscribeToEvents() {
    _eventSubscription = widget.eventsStream.listen((events) {
      if (mounted) {
        setState(() {
          _events = events;
        });
      }
    });
  }

  void _unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  Widget build(BuildContext context) {
    final defaultBoxDeco = BoxDecoration(
      borderRadius: BorderRadius.circular(6.0),
      color: Colors.grey[200],
    );

    final defaultTextStyle = TextStyle(
      color: Colors.grey[600],
      fontWeight: FontWeight.w700,
    );

    return TableCalendar(
      // 언어를 한글로 설정 (포스팅 아래 내용 확인 -> intl 라이브러리 )
      locale: 'ko_KR',
      // 포커싱 날짜 (오늘 날짜를 기준으로 함)
      focusedDay: _focusedDay,
      // 최소 년도
      firstDay: widget.firstDay,
      // 최대 년도
      lastDay: widget.lastDay,
      daysOfWeekHeight: 25,
      headerStyle: HeaderStyle(
        // default로 설정 돼 있는 2 weeks 버튼을 없애줌 (아마 2주단위로 보기 버튼인듯?)
        formatButtonVisible: false,
        // 달력 타이틀을 센터로
        titleCentered: true,
        // 말 그대로 타이틀 텍스트 스타일링
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16.0,
        ),
      ),
      calendarStyle: CalendarStyle(
        // 오늘 날짜에 하이라이팅의 유무
        isTodayHighlighted: false,
        // 캘린더의 평일 배경 스타일링(default면 평일을 의미)
        defaultDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Color(0xFFDBDBDB)), // 연회색 테두리
        ),
        // 캘린더의 주말 배경 스타일링
        weekendDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Color(0xFFDBDBDB)), // 연회색 테두리
        ),
        // 선택한 날짜 배경 스타일링
        selectedDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Color(0xFF051667), // 진한 파랑
            width: 2.5, // 굵은 테두리
          ),
        ),
        outsideDecoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Color(0xFFDBDBDB)), // 동일 테두리
          borderRadius: BorderRadius.circular(0),
        ),
        outsideTextStyle: TextStyle(
          color: Colors.black87, // 회색 대신 일반 텍스트
          fontWeight: FontWeight.w600,
        ),
        // 텍스트 스타일링들
        defaultTextStyle: defaultTextStyle,
        weekendTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.red,
        ),
        selectedTextStyle: TextStyle(
          color: Color(0xFF051667),
          fontWeight: FontWeight.bold,
        ),
      ),
      // 원하는 날짜 클릭 시 이벤트
      onDaySelected: (selectedDate, focusedDay) {
        widget.onDaySelected(selectedDate, focusedDay);
        setState(() {
          _focusedDay = focusedDay;
        });
      },
      selectedDayPredicate: (date) =>
        date.year == widget.selectedDate.year &&
        date.month == widget.selectedDate.month &&
        date.day == widget.selectedDate.day,
      eventLoader: (day) {
        // 해당 날짜에 해당하는 이벤트 리스트 반환
        return _events.where((event) =>
          event.date.year == day.year &&
          event.date.month == day.month &&
          event.date.day == day.day
        ).toList();
      },
      calendarBuilders: CalendarBuilders(
          dowBuilder: (context, day) {
            final weekdayIndex = day.weekday;
            final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
            final label = weekdays[weekdayIndex % 7];

            final isSunday = label == '일';
            final isSaturday = label == '토';

            return Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Color(0xFFDBDBDB)),
                borderRadius: BorderRadius.circular(0),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.0, // <= 줄간격 기본값 또는 조절
                    color: isSunday
                        ? Colors.red
                        : (isSaturday ? Colors.blue : Colors.black87),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },

          outsideBuilder: (context, day, focusedDay) {
            return _buildDateCell(day, isSelected: false, isToday: false, isOutside: true);
          },
          defaultBuilder: (context, day, focusedDay) {
            return _buildDateCell(day, isSelected: false, isToday: false);
          },
          todayBuilder: (context, day, focusedDay) {
            return _buildDateCell(day, isSelected: false, isToday: true);
          },
          selectedBuilder: (context, day, focusedDay) {
            return _buildDateCell(day, isSelected: true, isToday: false);
          },
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return const SizedBox.shrink();

            List<Widget> labels = [];

            for (final event in events.cast<Event>()) {
              String label = '';
              Color bgColor = Colors.black;

              if (event.type == 'economy') {
                label = 'E';
                bgColor = Color(0xFF425EB2); // Economy
              } else if (event.type == 'business') {
                label = 'B';
                bgColor = Color(0xFF0A1863); // Business
              } else if (event.type == 'first') {
                label = 'F';
                bgColor = Color(0xFF8B1E3F); // First
              }

              labels.add(
                Container(
                  width: 13,
                  height: 13,
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }

            return Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: labels.length > 3 ? labels.sublist(0, 3) : labels,
              ),
            );
          }
      ),
    );
  }

  Widget _buildDateCell(
      DateTime day, {
        required bool isSelected,
        required bool isToday,
        bool isOutside = false, // ← 플래그 추가
      }) {
    final isSunday = day.weekday == DateTime.sunday;

    final borderColor = isSelected
        ? Color(0xFF051667)
        : Color(0xFFDBDBDB);

    final borderWidth = isSelected ? 2.5 : 1.0;

    final textColor = isSelected
        ? Color(0xFF051667)
        : (isSunday ? Colors.red : Colors.black87);

    final bgColor = isOutside
        ? Colors.grey[100]! // ← 살짝 회색 배경 (밝은 그레이)
        : Colors.white;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(0),
      ),
      padding: EdgeInsets.all(4),
      child: Stack(
        children: [
          Positioned(
            top: 2,
            left: 4,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(height: 24),
          ),
        ],
      ),
    );
  }


}