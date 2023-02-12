import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';

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
        body: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[AwayScreen(), AirportScreen()],
          ),
        ));
  }
}

class AwayScreen extends StatefulWidget {
  const AwayScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _AwayScreenState();
}

class _AwayScreenState extends State<AwayScreen> {
  double xAlign = 5.0;
  Color loginColor = Colors.black;
  Color signInColor = Colors.black;

  @override
  void initState() {
    super.initState();
    xAlign = loginAlign;
    loginColor = selectedColor;
    signInColor = normalColor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class AirportScreen extends StatefulWidget {
  const AirportScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _AirportScreenState();
}

class _AirportScreenState extends State<AirportScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(15),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: ListView(
          padding: EdgeInsets.all(4),
          children: <Widget>[
            Divider(),
            Row(
              children: [
                Expanded(
                    child: DropdownSearch<String>(
                  items: const ["서울/인천\nICN", "뉴욕/존F케네디\nJFK"],
                )),
                Padding(padding: EdgeInsets.all(4)),
                Icon(
                  Icons.double_arrow_rounded,
                ),
                Expanded(
                    child: DropdownSearch<String>(
                  items: const ["서울/인천\nICN", "뉴욕/존F케네디\nJFK"],
                )),
              ],
            ),
            Padding(padding: EdgeInsets.all(8)),
            Divider(),
            ElevatedButton(
              onPressed: () {},
              child: Text("검색하기", style: TextStyle(fontSize: 18),),
              style: TextButton.styleFrom(
                  primary: Colors.white, backgroundColor: Colors.black54,
              minimumSize: Size.fromHeight(56.0)),
            ),
          ],
        ));
  }
}
