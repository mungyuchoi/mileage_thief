import 'package:flutter/material.dart';
import 'package:mileage_thief/model/search_detail_model_v2.dart';
import 'package:mileage_thief/model/search_model.dart';
import 'package:mileage_thief/helper/AdHelper.dart';
import 'package:mileage_thief/repository/mileage_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mileage_thief/custom/main_calendar.dart';

import '../../model/event_model.dart';

class SearchDetailDanScreen extends StatefulWidget {
  final SearchModel searchModel;

  const SearchDetailDanScreen(this.searchModel, {super.key});

  @override
  State<SearchDetailDanScreen> createState() => _SearchDetailDanScreenState();
}

class _SearchDetailDanScreenState extends State<SearchDetailDanScreen> {
  late DateTime selectedDate;
  List<MileageV2> allItems = [];
  bool isLoading = true;
  String? errorMsg;

  List<Event> get events {
    final events = <Event>[];
    for (final m in allItems) {
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

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      final items = await getItems(widget.searchModel);
      setState(() {
        allItems = items;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMsg = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 선택된 날짜에 해당하는 MileageV2 리스트 추출
    final selectedItems = allItems.where((m) {
      if (m.departureDate.length < 8) return false;
      final depDate = DateTime(
        int.parse(m.departureDate.substring(0, 4)),
        int.parse(m.departureDate.substring(4, 6)),
        int.parse(m.departureDate.substring(6, 8)),
      );
      return depDate.year == selectedDate.year &&
             depDate.month == selectedDate.month &&
             depDate.day == selectedDate.day;
    }).toList();

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  margin: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '대한항공 | 편도 | ${widget.searchModel.seatClass} | \n출발공항: ${widget.searchModel.departureAirport!!}) | \n도착공항: ${widget.searchModel.arrivalAirport!!}) | '
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
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '가는날: ' + _getIata(widget.searchModel.departureAirport) + ' - ' + _getIata(widget.searchModel.arrivalAirport),
                    style: const TextStyle(
                      color: Color(0xFF0A1863),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
            ),
            // MainCalendar는 항상 표시
            MainCalendar(
              key: ValueKey(selectedDate),
              eventsStream: Stream.value(events),
              selectedDate: selectedDate,
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
                  selectedDate = date;
                });
              },
            ),
            // 아래 정보 영역만 로딩/에러/데이터 표시
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMsg != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('에러 발생: ', style: TextStyle(color: Colors.red)),
              )
            else ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Color(0xFF425EB2),
                  borderRadius: BorderRadius.circular(0),
                ),
                child: Text(
                  '선택된 날짜: ${selectedDate.year}년 ${selectedDate.month}월 ${selectedDate.day}일',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (selectedItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: Text('해당 날짜의 좌석 정보가 없습니다.', style: TextStyle(color: Colors.grey)),
                ),
              for (final m in selectedItems)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.07),
                    border: Border.all(color: Colors.black26, width: 1.1),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.04),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _launchMarketURL(String asianaMarketUrl) async {
    if (await canLaunch(asianaMarketUrl)) {
      await launch(asianaMarketUrl);
    } else {
      throw '마켓을 열 수 없습니다: $asianaMarketUrl';
    }
  }

  String _getIata(String? airport) {
    if (airport == null) return '';
    final parts = airport.split('-');
    return parts.isNotEmpty ? parts.last.trim() : airport;
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
}

Future<List<MileageV2>> getItems(SearchModel searchModel) async {
  return await MileageRepository.getDanMileagesV2(searchModel);
}
