import 'package:flutter/material.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: AppColors.purple,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Chat List Screen',
          style: TextStyle(fontSize: 20, color: Colors.grey),
        ),
      ),
    );
  }
}
