import 'package:flutter/material.dart';
import 'package:mileage_thief/screen/search_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mileage_thief/screen/splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MaterialApp(
    theme: ThemeData(
      fontFamily: 'Ohsquareair',
    ),
    routes: {
      '/': (context) => SplashScreen(),
      '/search': (context) => SearchScreen(),
    },
  ));
}
