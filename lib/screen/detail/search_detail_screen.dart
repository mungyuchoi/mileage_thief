import 'package:flutter/material.dart';
import 'package:mileage_thief/model/search_model.dart';

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
      body: const MyStatefulWidget(),
    );
  }
}

// stores ExpansionPanel state information
class Item {
  Item({
    required this.expandedValue,
    required this.headerValue,
    this.isExpanded = false,
  });

  String expandedValue;
  String headerValue;
  bool isExpanded;
}

List<Item> generateItems(int numberOfItems) {
  return List<Item>.generate(numberOfItems, (int index) {
    return Item(
      headerValue: 'Panel $index',
      expandedValue: 'This is item number $index',
    );
  });
}

class MyStatefulWidget extends StatefulWidget {
  const MyStatefulWidget({super.key});

  @override
  State<MyStatefulWidget> createState() => _MyStatefulWidgetState();
}

class _MyStatefulWidgetState extends State<MyStatefulWidget> {
  final List<Item> _data = generateItems(8);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.all(8),
            child: Text(
              '아시아나 | 편도 | 전체 | 4인 | 5박',

            ),
          ),
          Container(
              padding: const EdgeInsets.all(20),
              child: _buildPanel(),
              // color: Color.alphaBlend(Colors.black12, const Color(0x00ffffff))),
              color: Color(0Xffeeeeee)),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    return ExpansionPanelList(
      elevation: 0,
      expandedHeaderPadding: EdgeInsets.all(5),
      expansionCallback: (int index, bool isExpanded) {
        setState(() {
          _data[index].isExpanded = !isExpanded;
        });
      },
      children: _data.map<ExpansionPanel>((Item item) {
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
                          style: TextStyle(
                              fontFamily: 'Roboto', fontSize: 16),
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
                          child: const Text(
                            '2023.02.14(수)',
                            style: TextStyle(
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
                              const Text(
                                "3",
                                style: TextStyle(
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
                              const Text(
                                "3",
                                style: TextStyle(
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
                              const Text(
                                "3",
                                style: TextStyle(
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
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flight_takeoff_outlined),
                        Padding(padding: EdgeInsets.all(3)),
                        Text(
                          '출국일정',
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Padding(padding: EdgeInsets.all(4)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '10:50',
                          style: TextStyle(
                              color: Colors.red,
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                        Padding(padding: EdgeInsets.all(3)),
                        Text(
                          '서울/인천(ICN) 출발 (A380)',
                          style: TextStyle(
                              color: Color(0Xff6f6f6f),
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Padding(padding: EdgeInsets.all(4)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '11:40',
                          style: TextStyle(
                              color: Colors.red,
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                        Padding(padding: EdgeInsets.all(3)),
                        Text(
                          '뉴욕/존F케네디(JFK) 도착',
                          style: TextStyle(
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