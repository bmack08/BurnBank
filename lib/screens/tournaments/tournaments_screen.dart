// lib/screens/tournaments/tournaments_screen.dart
import 'package:flutter/material.dart';

class TournamentsScreen extends StatelessWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
      ),
      body: const Center(
        child: Text('Tournaments Coming Soon!'),
      ),
    );
  }
}
