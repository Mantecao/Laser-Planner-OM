import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const LaserPlannerApp());
}

class LaserPlannerApp extends StatelessWidget {
  const LaserPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laser Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.light,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
