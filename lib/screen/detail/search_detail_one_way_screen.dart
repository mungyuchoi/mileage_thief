import 'package:flutter/material.dart';
import 'package:mileage_thief/model/search_detail_model.dart';
import 'package:mileage_thief/model/search_model.dart';
import 'package:mileage_thief/repository/mileage_repository.dart';
import 'package:mileage_thief/util/util.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class SearchDetailScreen extends StatelessWidget {
  final SearchModel searchModel;

  const SearchDetailScreen(this.searchModel, {super.key});

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
            Container(
              margin: const EdgeInsets.all(8),
              child: Text(
                '아시아나 | 편도 | 전체 | \n출발공항: ${searchModel.departureAirport!!}) | \n도착공항: ${searchModel.arrivalAirport!!})',
              ),
            ),
            Container(
                padding: const EdgeInsets.all(20),
                // color: Color.alphaBlend(Colors.black12, const Color(0x00ffffff))),
                //color: const Color(0Xffeeeeee),
                child: FutureBuilder<List<Mileage>>(
                  future: getItems(searchModel),
                  builder: (BuildContext context,
                      AsyncSnapshot<List<Mileage>> snapshot) {
                    if(snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return MyStatefulWidget(items: snapshot.data ?? []);
                    } else if (snapshot.hasData && snapshot.data!.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("검색된 결과가 없습니다."),
                        ),
                      );
                    }
                    else {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }
}

Future<List<Mileage>> getItems(SearchModel searchModel) async {
  return await MileageRepository.getMileages(searchModel);
}

class MyStatefulWidget extends StatefulWidget {
  final List<Mileage> items;
  const MyStatefulWidget({Key? key, required this.items}) : super(key: key);

  @override
  State<MyStatefulWidget> createState() => _MyStatefulWidgetState(items: items);
}

class _MyStatefulWidgetState extends State<MyStatefulWidget> {
  final List<Mileage> _items;

  _MyStatefulWidgetState({required  List<Mileage> items}): _items = items;
  @override
  Widget build(BuildContext context) {
    return _buildPanel();
  }

  Widget _buildPanel() {

    return Column(
      children: [
        TableCalendar<Mileage>(
          locale: 'ko_KR',
          firstDay: DateTime.now(),
          lastDay: DateTime(DateTime.now().year+1),
          focusedDay: DateTime.now(),
          headerStyle: HeaderStyle(
            titleCentered: true,
            titleTextFormatter: (date, locale) =>
                DateFormat.yMMMMd(locale).format(date),
            formatButtonVisible: false,
            titleTextStyle: const TextStyle(
              fontSize: 20.0,
              color: Colors.black,
            ),
            headerPadding: const EdgeInsets.symmetric(vertical: 4.0),
            leftChevronIcon: const Icon(
              Icons.arrow_left,
              size: 40.0,
            ),
            rightChevronIcon: const Icon(
              Icons.arrow_right,
              size: 40.0,
            ),
          ),
        )
      ],
    );
      ExpansionPanelList(
      elevation: 0,
      expandedHeaderPadding: EdgeInsets.all(5),
      expansionCallback: (int index, bool isExpanded) {
        setState(() {
          _items[index].isExpanded = !isExpanded;
        });
      },
      children: _items.map<ExpansionPanel>((Mileage item) {
        return ExpansionPanel(
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              title: Container(
                height: 60,
                child: Row(
                  children: [
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          '출국',
                          style: TextStyle(fontFamily: 'Roboto', fontSize: 16),
                        ),
                        // Padding(padding: EdgeInsets.all(1)),
                        Text(
                          '좌석',
                          style: TextStyle(fontFamily: 'Roboto'),
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.all(3)),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            Util.getDepartureDate(item.departureDate),
                            style: const TextStyle(
                                color: Colors.red,
                                fontFamily: 'SsuroundAir',
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Image.asset(
                                'asset/img/letter-e.png',
                                scale: 30,
                              ),
                              const Padding(padding: EdgeInsets.all(1)),
                              Text(
                                item.economySeat,
                                style: const TextStyle(
                                    fontFamily: 'SsuroundAir',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                              const Padding(padding: EdgeInsets.all(2)),
                              Image.asset(
                                'asset/img/letter-b.png',
                                scale: 30,
                              ),
                              const Padding(padding: EdgeInsets.all(1)),
                              Text(
                                item.businessSeat,
                                style: const TextStyle(
                                    fontFamily: 'SsuroundAir',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                              const Padding(padding: EdgeInsets.all(2)),
                              Image.asset(
                                'asset/img/letter-f.png',
                                scale: 30,
                              ),
                              const Padding(padding: EdgeInsets.all(1)),
                              Text(
                                item.firstSeat,
                                style: const TextStyle(
                                    fontFamily: 'SsuroundAir',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
          body: Stack(
            children: [
              Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Container(
                  width: 10,
                  height: 100,
                  color: const Color(0Xffeeeeee),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: Container(
                  width: 10,
                  height: 100,
                  color: const Color(0Xffeeeeee),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.topCenter,
                child: Container(
                  width: 400,
                  height: 1,
                  color: const Color(0Xffeeeeee),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Container(
                  margin: const EdgeInsets.only(left: 10, top: 80),
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                      color: Color(0Xffeeeeee),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(40),
                      )),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Container(
                  margin: const EdgeInsets.only(right: 10, top: 80),
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                      color: Color(0Xffeeeeee),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                      )),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(
                    left: 35, top: 10, bottom: 10, right: 35),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flight_takeoff_outlined),
                        const Padding(padding: EdgeInsets.all(3)),
                        Text(
                          Util.getDepartureAircraft(item.aircraftType),
                          style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.all(4)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Util.getDepartureDetailDate(item.departureDate),
                          style: const TextStyle(
                              color: Colors.red,
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                        const Padding(padding: EdgeInsets.all(3)),
                        Text(
                          Util.mergeDepartureAirportCity(item.departureCity, item.departureAirport),
                          style: const TextStyle(
                              color: Color(0Xff6f6f6f),
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.all(4)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.arrivalDate,
                          style: const TextStyle(
                              color: Colors.red,
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                        const Padding(padding: EdgeInsets.all(3)),
                        Text(
                          Util.mergeDepartureAirportCity(item.arrivalCity, item.arrivalAirport),
                          style: const TextStyle(
                              color: Color(0Xff6f6f6f),
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          isExpanded: item.isExpanded,
        );
      }).toList(),
    );
  }
}
