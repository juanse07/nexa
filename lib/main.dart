import 'package:flutter/material.dart';

void main() => runApp(const NexaApp());

class NexaApp extends StatelessWidget {
  const NexaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Nexa',
      home: Scaffold(
        body: Center(
          child: Text('Nexa', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
