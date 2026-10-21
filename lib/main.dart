import 'package:flutter/material.dart';

import 'home_screen.dart';

void main() {
  runApp(const BreakFreeApp());
}

class BreakFreeApp extends StatelessWidget {
  const BreakFreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BreakFree',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00C853)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}