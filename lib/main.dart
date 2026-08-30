import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  runApp(const SpinCounterApp());
}

class SpinCounterApp extends StatelessWidget {
  const SpinCounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C4DFF),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: '小役カウンター',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF6F1FB),
        fontFamily: 'Roboto',
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      ),
      home: const HomePage(),
    );
  }
}
