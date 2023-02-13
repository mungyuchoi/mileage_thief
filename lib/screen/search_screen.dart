import 'package:flutter/material.dart';
import 'package:mileage_thief/screen/detail/search_detail_screen.dart';
import '../custom/CustomDropdownButton2.dart';
import '../model/search_model.dart';

class SearchScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _SearchScreenState();
}

const double width = 150.0;
const double height = 50.0;
const double loginAlign = -1;
const double signInAlign = 1;
const Color selectedColor = Colors.white;
const Color normalColor = Colors.white;

class _SearchScreenState extends State<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            '마일리지 도둑',
            style: TextStyle(color: Colors.black),
          ),
          leading: Image.asset(
            'asset/img/airplane.png',
            scale: 2,
          ),
          backgroundColor: Colors.white,
          elevation: 1,
        ),
        body: const SingleChildScrollView(
          child: AirportScreen(),
        ));
  }
}

class AirportScreen extends StatefulWidget {
  const AirportScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _AirportScreenState();
}

class _AirportScreenState extends State<AirportScreen> {
  double xAlign = 5.0;
  Color loginColor = Colors.black;
  Color signInColor = Colors.black;
  final List<String> dateItems = [
    "전체",
    "1박2일",
    "2박3일",
    "3박4일",
    "4박5일",
    "5박6일",
    "6박7일",
    "7박8일",
    "8박9일",
    "9박10일",
    "10박11일",
    "11박12일",
    "12박13일",
    "13박14일",
    "14박15일",
    "15박16일",
    "16박17일",
    "17박18일",
    "18박19일",
    "19박20일",
    "20박21일",
    "21박22일",
    "22박23일",
    "23박24일",
    "24박25일",
    "25박26일",
    "26박27일",
    "27박28일",
    "28박29일",
    "29박30일",
  ];
  final List<String> classItems = ["전체", "이코노미", "비즈니스", "퍼스트"];
  final List<String> airportItems = ["서울/인천-ICN", "뉴욕/존F케네디-JFK"];
  String? dateSelectedValue;
  String? classSelectedValue;
  String? departureSelectedValue;
  String? arrivalSelectedValue;

  @override
  void initState() {
    super.initState();
    xAlign = loginAlign;
    loginColor = selectedColor;
    signInColor = normalColor;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: width,
          height: height,
          margin: const EdgeInsets.only(top: 30),
          decoration: const BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.all(
              Radius.circular(50.0),
            ),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: Alignment(xAlign, 0),
                duration: Duration(milliseconds: 300),
                child: Container(
                  width: width * 0.5,
                  height: height,
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.all(
                      Radius.circular(50.0),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    xAlign = loginAlign;
                    loginColor = selectedColor;
                    signInColor = normalColor;
                  });
                },
                child: Align(
                  alignment: Alignment(-1, 0),
                  child: Container(
                    width: width * 0.5,
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: Text(
                      '왕복',
                      style: TextStyle(
                        color: loginColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    xAlign = signInAlign;
                    signInColor = selectedColor;
                    loginColor = normalColor;
                  });
                },
                child: Align(
                  alignment: Alignment(1, 0),
                  child: Container(
                    width: width * 0.5,
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: Text(
                      '편도',
                      style: TextStyle(
                        color: signInColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
            padding: const EdgeInsets.all(15),
            width: MediaQuery
                .of(context)
                .size
                .width,
            height: MediaQuery
                .of(context)
                .size
                .height,
            child: ListView(
              padding: const EdgeInsets.all(4),
              children: <Widget>[
                const Divider(
                  color: Colors.black,
                  thickness: 2,
                ),
                const Padding(padding: EdgeInsets.all(8)),
                Row(
                  children: [
                    Expanded(
                      child: CustomDropdownButton2(
                        hint: '어디서 가나요?',
                        dropdownItems: airportItems,
                        hintAlignment: Alignment.center,
                        value: departureSelectedValue,
                        onChanged: (value) {
                          setState(() {
                            departureSelectedValue = value;
                          });
                        },
                      ),
                    ),
                    const Padding(padding: EdgeInsets.all(4)),
                    const Icon(
                      Icons.double_arrow_rounded,
                    ),
                    const Padding(padding: EdgeInsets.all(4)),
                    Expanded(
                      child: CustomDropdownButton2(
                        hint: '어디로 가나요?',
                        hintAlignment: Alignment.center,
                        dropdownItems: airportItems,
                        value: arrivalSelectedValue,
                        onChanged: (value) {
                          setState(() {
                            arrivalSelectedValue = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.all(8)),
                const Divider(
                  color: Colors.black,
                  thickness: 2,
                ),
                const Padding(padding: EdgeInsets.all(8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text('클래스'),
                        const Padding(padding: EdgeInsets.all(4)),
                        CustomDropdownButton2(
                          buttonWidth: 90,
                          dropdownWidth: 100,
                          valueAlignment: Alignment.center,
                          hint: '전체',
                          dropdownItems: classItems,
                          value: classSelectedValue,
                          onChanged: (value) {
                            setState(() {
                              classSelectedValue = value;
                            });
                          },
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('검색박수'),
                        const Padding(padding: EdgeInsets.all(4)),
                        CustomDropdownButton2(
                          buttonWidth: 100,
                          dropdownWidth: 100,
                          valueAlignment: Alignment.center,
                          hint: '전체',
                          dropdownItems: dateItems,
                          value: dateSelectedValue,
                          onChanged: (value) {
                            setState(() {
                              dateSelectedValue = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.all(8)),
                const Divider(
                  color: Colors.black,
                  thickness: 2,
                ),
                const Padding(padding: EdgeInsets.all(8)),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                SearchDetailScreen(
                                    SearchModel(isRoundTrip: xAlign == -1.0
                                        ? true
                                        : false,
                                        departureAirport: departureSelectedValue,
                                        arrivalAirport: arrivalSelectedValue,
                                        seatClass: classSelectedValue,
                                        searchDate: dateSelectedValue)
                                )));
                  },
                  style: TextButton.styleFrom(
                      primary: Colors.white,
                      backgroundColor: Colors.black54,
                      minimumSize: const Size.fromHeight(56.0)),
                  child: const Text(
                    "검색하기",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            )),
      ],
    );
  }
}
