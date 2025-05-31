import 'package:flutter/material.dart';
import 'package:mileage_thief/model/search_detail_model_v2.dart';
import 'package:mileage_thief/model/search_model.dart';
import 'package:mileage_thief/helper/AdHelper.dart';
import 'package:mileage_thief/repository/mileage_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mileage_thief/custom/main_calendar.dart';
import '../../model/event_model.dart';

class SearchDetailDanRoundScreen extends StatefulWidget {
  final SearchModel searchModel;
  const SearchDetailDanRoundScreen(this.searchModel, {super.key});

  @override
  State<SearchDetailDanRoundScreen> createState() => _SearchDetailDanRoundScreenState();
}

class _SearchDetailDanRoundScreenState extends State<SearchDetailDanRoundScreen> {
  // 가는날
  late DateTime selectedGoDate;
  List<MileageV2> goItems = [];
  bool isGoLoading = true;
  String? goErrorMsg;

  // 오는날
  late DateTime selectedReturnDate;
  List<MileageV2> returnItems = [];
  bool isReturnLoading = true;
  String? returnErrorMsg;

  @override
  void initState() {
    super.initState();
    selectedGoDate = DateTime.now();
    selectedReturnDate = DateTime.now().add(const Duration(days: 7));
    _loadGoData();
    _loadReturnData();
  }

  Future<void> _loadGoData() async {
    setState(() {
      isGoLoading = true;
      goErrorMsg = null;
    });
    try {
      final items = await getItems(
        widget.searchModel,
        isReturn: false,
      );
      setState(() {
        goItems = items;
        isGoLoading = false;
      });
    } catch (e) {
      setState(() {
        goErrorMsg = e.toString();
        isGoLoading = false;
      });
    }
  }

  Future<void> _loadReturnData() async {
    setState(() {
      isReturnLoading = true;
      returnErrorMsg = null;
    });
    try {
      // 출발/도착을 바꿔서 검색
      final reversedModel = SearchModel(
        isRoundTrip: widget.searchModel.isRoundTrip,
        departureAirport: widget.searchModel.arrivalAirport,
        arrivalAirport: widget.searchModel.departureAirport,
        seatClass: widget.searchModel.seatClass,
        searchDate: widget.searchModel.searchDate,
        startMonth: widget.searchModel.startMonth,
        startYear: widget.searchModel.startYear,
        endMonth: widget.searchModel.endMonth,
        endYear: widget.searchModel.endYear,
      );
      final items = await getItems(
        reversedModel,
        isReturn: true,
      );
      setState(() {
        returnItems = items;
        isReturnLoading = false;
      });
    } catch (e) {
      setState(() {
        returnErrorMsg = e.toString();
        isReturnLoading = false;
      });
    }
  }

  List<Event> _getEvents(List<MileageV2> items) {
    final events = <Event>[];
    for (final m in items) {
      final date = DateTime.tryParse(m.departureDate.substring(0,8)) ?? DateTime.now();
      if (m.hasEconomy) {
        events.add(Event(date: date, type: 'economy', color: Color(0xFF425EB2)));
      }
      if (m.hasBusiness) {
        events.add(Event(date: date, type: 'business', color: Color(0xFF0A1863)));
      }
      if (m.hasFirst) {
        events.add(Event(date: date, type: 'first', color: Color(0xFF8B1E3F)));
      }
    }
    return events;
  }

  List<MileageV2> _getSelectedItems(List<MileageV2> items, DateTime date) {
    return items.where((m) {
      if (m.departureDate.length < 8) return false;
      final depDate = DateTime(
        int.parse(m.departureDate.substring(0, 4)),
        int.parse(m.departureDate.substring(4, 6)),
        int.parse(m.departureDate.substring(6, 8)),
      );
      return depDate.year == date.year &&
             depDate.month == date.month &&
             depDate.day == date.day;
    }).toList();
  }

  String _getIata(String? airport) {
    if (airport == null) return '';
    final parts = airport.split('-');
    return parts.isNotEmpty ? parts.last.trim() : airport;
  }

  void _launchMarketURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw '마켓을 열 수 없습니다: $url';
    }
  }

  Widget _legendMarker(String label, Color color) {
    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goSelectedItems = _getSelectedItems(goItems, selectedGoDate);
    final returnSelectedItems = _getSelectedItems(returnItems, selectedReturnDate);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF00256B),
        title: const Text(
          '검색하기',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          color: Colors.white,
          icon: const Icon(Icons.arrow_back_ios_sharp),
          iconSize: 20,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 앱 바로가기 (상단)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '대한항공 | 왕복 | ${widget.searchModel.seatClass} | \n출발공항: ${widget.searchModel.departureAirport!!}) | \n도착공항: ${widget.searchModel.arrivalAirport!!}) | '
                              '\n'
                              '\n검색 기간: ${widget.searchModel.startYear}년 ${widget.searchModel.startMonth}월 ~ ${widget.searchModel.endYear}년 ${widget.searchModel.endMonth}월',
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        child: IconButton(
                          onPressed: () {
                            _launchMarketURL(AdHelper.danMarketUrl);
                          },
                          icon: Image.asset(
                            'asset/img/app_dan.png',
                          ),
                        ),
                      ),
                      const Text(
                        '대한항공 앱으로 이동',
                        style: TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              // 가는날
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '가는날',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A1863)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Color(0xFF0A1863)),
                    tooltip: '범례',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.white,
                          title: const Text('좌석 정보', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _legendMarker('E', Color(0xFF425EB2)),
                                  Text('일반석'),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  _legendMarker('B', Color(0xFF0A1863)),
                                  Text('비즈니스'),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  _legendMarker('F', Color(0xFF8B1E3F)),
                                  Text('일등석'),
                                ],
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('닫기'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              Text(
                '${_getIata(widget.searchModel.departureAirport)} - ${_getIata(widget.searchModel.arrivalAirport)}',
                style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              MainCalendar(
                key: ValueKey('go_${selectedGoDate.toIso8601String()}'),
                eventsStream: Stream.value(_getEvents(goItems)),
                selectedDate: selectedGoDate,
                firstDay: DateTime(
                  int.parse(widget.searchModel.startYear ?? DateTime.now().year.toString()),
                  int.parse(widget.searchModel.startMonth ?? DateTime.now().month.toString()),
                  1,
                ),
                lastDay: DateTime(
                  int.parse(widget.searchModel.endYear ?? DateTime.now().year.toString()),
                  int.parse(widget.searchModel.endMonth ?? DateTime.now().month.toString()),
                  31,
                ),
                onDaySelected: (date, focusedDay) {
                  setState(() {
                    selectedGoDate = date;
                  });
                },
              ),
              if (isGoLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (goErrorMsg != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('에러 발생: ', style: TextStyle(color: Colors.red)),
                )
              else ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Color(0xFF425EB2),
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: Text(
                    '선택된 날짜: ${selectedGoDate.year}년 ${selectedGoDate.month}월 ${selectedGoDate.day}일',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (goSelectedItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Text('해당 날짜의 좌석 정보가 없습니다.', style: TextStyle(color: Colors.grey)),
                  ),
                for (final m in goSelectedItems) ...[
                  if (m.hasEconomy)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '이코노미  세금: ${m.economyAmount}  마일리지: ${m.economyMileage}',
                        style: const TextStyle(color: Color(0xFF425EB2), fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  if (m.hasBusiness)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '비즈니스  세금: ${m.businessAmount}  마일리지: ${m.businessMileage}',
                        style: const TextStyle(color: Color(0xFF0A1863), fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  if (m.hasFirst)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '퍼스트  세금: ${m.firstAmount}  마일리지: ${m.firstMileage}',
                        style: const TextStyle(color: Color(0xFF8B1E3F), fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                ],
              ],

              const SizedBox(height: 32),

              // 오는날
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '오는날',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A1863)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Color(0xFF0A1863)),
                    tooltip: '범례',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.white,
                          title: const Text('좌석 정보', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _legendMarker('E', Color(0xFF425EB2)),
                                  Text('일반석'),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  _legendMarker('B', Color(0xFF0A1863)),
                                  Text('비즈니스'),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  _legendMarker('F', Color(0xFF8B1E3F)),
                                  Text('일등석'),
                                ],
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('닫기'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              Text(
                '${_getIata(widget.searchModel.arrivalAirport)} - ${_getIata(widget.searchModel.departureAirport)}',
                style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              MainCalendar(
                key: ValueKey('return_${selectedReturnDate.toIso8601String()}'),
                eventsStream: Stream.value(_getEvents(returnItems)),
                selectedDate: selectedReturnDate,
                firstDay: DateTime(
                  int.parse(widget.searchModel.startYear ?? DateTime.now().year.toString()),
                  int.parse(widget.searchModel.startMonth ?? DateTime.now().month.toString()),
                  1,
                ),
                lastDay: DateTime(
                  int.parse(widget.searchModel.endYear ?? DateTime.now().year.toString()),
                  int.parse(widget.searchModel.endMonth ?? DateTime.now().month.toString()),
                  31,
                ),
                onDaySelected: (date, focusedDay) {
                  setState(() {
                    selectedReturnDate = date;
                  });
                },
              ),
              if (isReturnLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (returnErrorMsg != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('에러 발생: ', style: TextStyle(color: Colors.red)),
                )
              else ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Color(0xFF425EB2),
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: Text(
                    '선택된 날짜: ${selectedReturnDate.year}년 ${selectedReturnDate.month}월 ${selectedReturnDate.day}일',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (returnSelectedItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Text('해당 날짜의 좌석 정보가 없습니다.', style: TextStyle(color: Colors.grey)),
                  ),
                for (final m in returnSelectedItems) ...[
                  if (m.hasEconomy)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '이코노미  세금: ${m.economyAmount}  마일리지: ${m.economyMileage}',
                        style: const TextStyle(color: Color(0xFF425EB2), fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  if (m.hasBusiness)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '비즈니스  세금: ${m.businessAmount}  마일리지: ${m.businessMileage}',
                        style: const TextStyle(color: Color(0xFF0A1863), fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  if (m.hasFirst)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '퍼스트  세금: ${m.firstAmount}  마일리지: ${m.firstMileage}',
                        style: const TextStyle(color: Color(0xFF8B1E3F), fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                ],
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// 기존 getItems를 재사용하되, 왕복일 때 출발/도착만 바꿔서 사용
Future<List<MileageV2>> getItems(SearchModel searchModel, {bool isReturn = false}) async {
  return await MileageRepository.getDanMileagesV2(searchModel);
}
