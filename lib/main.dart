import 'package:flutter/material.dart';

import 'maps_screen.dart';

void main() {
  runApp(const Bai07MapsApp());
}

class Bai07MapsApp extends StatelessWidget {
  const Bai07MapsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bài 07 - Google Maps',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
