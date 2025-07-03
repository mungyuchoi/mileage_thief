import 'package:flutter/material.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    // 즉시 이동하거나 0.5초 후 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startTimer();
    });
  }

  startTimer() {
    var duration = const Duration(milliseconds: 500); // 0.5초로 단축
    return Timer(duration, route);
  }

  route() {
    Navigator.pushReplacementNamed(context, '/'); // 메인 화면으로 이동
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: content(),
    );
  }

  Widget content() {
    return Center(
      child: Container(
        child: Lottie.network(
          'https://assets8.lottiefiles.com/packages/lf20_z4w1m9cg.json',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
          // 네트워크 지연 방지를 위한 설정
          repeat: false,
          animate: true,
        ),
      ),
    );
  }
}