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
  DateTime? selectedDay;

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
            borderRadius: BorderRadius.circular(6.0),
            color: LIGHT_GREY_COLOR,
        ),
        // 캘린더의 주말 배경 스타일링
          weekendDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6.0),
            color: LIGHT_GREY_COLOR,
        ),
        // 선택한 날짜 배경 스타일링
        selectedDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: PRIMARY_COLOR,
            width: 2.0,
          ),
        ),
        outsideDecoration: BoxDecoration(
            shape: BoxShape.rectangle
        ),
        // 텍스트 스타일링들
        defaultTextStyle: defaultTextStyle,
        weekendTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.red,
        ),
        selectedTextStyle: defaultTextStyle.copyWith(color: PRIMARY_COLOR)),
      // 원하는 날짜 클릭 시 이벤트
      onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
        // 클릭 할 때 state를 변경
        setState(() {
          this.selectedDay = selectedDay;
          // 우리가 달력 내에서 전 달 날짜를 클릭 할 때 옮겨주도록 state를 변경시켜 줌
          _focusedDay = selectedDay;
        });
      },

      // selectedDayPredicate를 통해 해당 날짜가 맞는지 비교 후 true false 비교 후 반환해 줌
      selectedDayPredicate: (DateTime date) {
        if (selectedDay == null) {
          return false;
        }

        return date.year == selectedDay!.year &&
            date.month == selectedDay!.month &&
            date.day == selectedDay!.day;
      },
      eventLoader: (day) {
        // 해당 날짜에 해당하는 이벤트 리스트 반환
        return _events.where((event) =>
          event.date.year == day.year &&
          event.date.month == day.month &&
          event.date.day == day.day
        ).toList();
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          if (events.isNotEmpty) {
            final hasEconomy = events.any((e) => (e as Event).type == 'economy');
            final hasBusiness = events.any((e) => (e as Event).type == 'business');
            final hasFirst = events.any((e) => (e as Event).type == 'first');
            return Stack(
              children: [
                if (hasEconomy)
                  Positioned(
                    left: 14,
                    bottom: 7,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: economyColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (hasBusiness)
                  Positioned(
                    left: 26,
                    bottom: 7,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: businessColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (hasFirst)
                  Positioned(
                    right: 14,
                    bottom: 7,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: firstColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}