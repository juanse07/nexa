import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa/features/chat/presentation/conversations_screen.dart';

void main() {
  group('ConversationsScreen Widget Tests', () {
    Widget buildScreen() {
      return const MaterialApp(
        home: ConversationsScreen(),
      );
    }

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('renders Chats title', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(
        find.textContaining('Chat').evaluate().isNotEmpty ||
            find.textContaining('Message').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('is a StatefulWidget or StatelessWidget', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(ConversationsScreen), findsOneWidget);
    });

    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders AppBar', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.byType(AppBar), findsWidgets);
    });
  });
}
