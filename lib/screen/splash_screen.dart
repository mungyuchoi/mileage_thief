import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mileage_thief/const/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _splashDuration = Duration(milliseconds: 1300);

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _routeTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    final entranceCurve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(entranceCurve);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(entranceCurve);

    _controller.forward();
    _routeTimer = Timer(_splashDuration, _route);
  }

  void _route() {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image(
                      image: AssetImage('asset/img/app_icon.png'),
                      width: 112,
                      height: 112,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: 28),
                    _SplashCopy(
                      text: '놓치던 여행의 기회를',
                      color: McColors.ink,
                    ),
                    SizedBox(height: 4),
                    _SplashCopy(
                      text: '먼저 캐치하다',
                      color: McColors.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashCopy extends StatelessWidget {
  const _SplashCopy({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontFamily: 'Ssuround',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.22,
        ),
      ),
    );
  }
}
