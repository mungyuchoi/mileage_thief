import 'package:flutter/material.dart';
import 'package:mileage_thief/model/search_detail_model_v2.dart';
import 'package:mileage_thief/model/search_model.dart';
import 'package:mileage_thief/helper/AdHelper.dart';
import 'package:mileage_thief/repository/mileage_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mileage_thief/util/util.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mileage_thief/custom/main_calendar.dart';

import '../../model/event_model.dart';

class SearchDetailDanScreen extends StatelessWidget {
  final SearchModel searchModel;

  const SearchDetailDanScreen(this.searchModel, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black54,
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
                        '대한항공 | 편도 | ${searchModel.seatClass} | \n출발공항: ${searchModel.departureAirport!!}) | \n도착공항: ${searchModel.arrivalAirport!!}) | '
                        '\n\n성수기에는 마일리지가 50% 추가됩니다.' +
                            '\n검색 기간: ${searchModel.startYear}년 ${searchModel.startMonth}월 ~ ${searchModel.endYear}년 ${searchModel.endMonth}월',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 16),
                Icon(Icons.circle, color: Color(0xFF1976D2), size: 14),
                const SizedBox(width: 4),
                const Text('Economy', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Icon(Icons.circle, color: Color(0xFFFFB300), size: 14),
                const SizedBox(width: 4),
                const Text('Business', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Icon(Icons.circle, color: Color(0xFF8B1E3F), size: 14),
                const SizedBox(width: 4),
                const Text('First', style: TextStyle(fontSize: 12)),
              ],
            ),
            FutureBuilder<List<MileageV2>>(
              future: getItems(searchModel),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('에러 발생: \\${snapshot.error}'));
                }
                final items = snapshot.data ?? [];
                // 날짜별 Event 리스트 생성
                final List<Event> events = [];
                for (final m in items) {
                  final date = DateTime.tryParse(m.departureDate.substring(0,8)) ?? DateTime.now();
                  if (m.hasEconomy) {
                    events.add(Event(date: date, type: 'economy', color: Colors.blue));
                  }
                  if (m.hasBusiness) {
                    events.add(Event(date: date, type: 'business', color: Colors.green));
                  }
                  if (m.hasFirst) {
                    events.add(Event(date: date, type: 'first', color: Colors.red));
                  }
                }
                return MainCalendar(
                  eventsStream: Stream.value(events),
                  selectedDate: DateTime.now(),
                  firstDay: DateTime(
                    int.parse(searchModel.startYear ?? DateTime.now().year.toString()),
                    int.parse(searchModel.startMonth ?? DateTime.now().month.toString()),
                    1,
                  ),
                  lastDay: DateTime(
                    int.parse(searchModel.endYear ?? DateTime.now().year.toString()),
                    int.parse(searchModel.endMonth ?? DateTime.now().month.toString()),
                    31,
                  ),
                  onDaySelected: (selectedDate, focusedDay) {
                    // 날짜 선택 시 원하는 동작 구현
                  },
                );
              },
            ),
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
}

Future<List<MileageV2>> getItems(SearchModel searchModel) async {
  return await MileageRepository.getDanMileagesV2(searchModel);
}
