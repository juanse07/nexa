import 'package:flutter/material.dart';

import 'features/extraction/presentation/extraction_screen.dart';

class NexaApp extends StatelessWidget {
  const NexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Nexa', home: ExtractionScreen());
  }
}
