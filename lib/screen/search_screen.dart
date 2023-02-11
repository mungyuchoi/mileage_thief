import 'package:flutter/material.dart';

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[AwayScreen()],
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
