import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nexa/services/terminology_provider.dart';

/// A TerminologyProvider that doesn't read SharedPreferences (safe for tests)
class TestTerminologyProvider extends TerminologyProvider {
  TestTerminologyProvider() : super();
}

/// Wraps a widget with MaterialApp + TerminologyProvider for widget tests
Widget buildTestApp(
  Widget child, {
  TerminologyProvider? terminologyProvider,
  Size screenSize = const Size(500, 1000),
}) {
  return MediaQuery(
    data: MediaQueryData(size: screenSize),
    child: ChangeNotifierProvider<TerminologyProvider>(
      create: (_) => terminologyProvider ?? TestTerminologyProvider(),
      child: MaterialApp(
        home: child,
      ),
    ),
  );
}
