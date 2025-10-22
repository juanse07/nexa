import 'package:flutter/material.dart';

class HoursScreen extends StatelessWidget {
  const HoursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Hours'),
        backgroundColor: const Color(0xFF7A3AFB),
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Hours Tracking Screen',
          style: TextStyle(fontSize: 20, color: Colors.grey),
        ),
      ),
    );
  }
}