import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

// Import the existing services and widgets
import '../services/chat_event_service.dart';
import '../services/event_service.dart';
import '../services/extraction_service.dart';
import '../services/file_processor_service.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/image_preview_card.dart';
import '../widgets/document_preview_card.dart';
import '../widgets/event_confirmation_card.dart';
import '../widgets/batch_event_dialog.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

// This is a preview of the animated build method structure for ai_chat_screen.dart
// Copy the relevant parts back to the main file

class AnimatedBuildMethodPreview extends StatelessWidget {
  const AnimatedBuildMethodPreview({super.key});

  @override
  Widget build(BuildContext context) {
    // This shows the new structure for the build method
    // with scroll animations implemented

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Handle scroll for input animation
        // _handleScrollNotification(notification);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        body: Stack(
          children: [
            // Main content with floating app bar
            CustomScrollView(
              // controller: _scrollController,
              slivers: [
                // Floating app bar that hides on scroll
                SliverAppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  floating: true,    // Reappears on any upward scroll
                  snap: true,        // Snaps to full height quickly
                  pinned: false,     // Doesn't stay visible when collapsed
                  expandedHeight: 56.0,
                  title: const Text(
                    'AI Chat',
                    style: TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  iconTheme: const IconThemeData(color: AppColors.charcoal),
                ),

                // Info banner with AI provider toggle
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade50,
                          Colors.cyan.shade50,
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Tell me about your event and I\'ll help you plan it!',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                        // AI Provider toggle would go here
                      ],
                    ),
                  ),
                ),

                // Event banner if has event data
                // This would be conditionally shown

                // Messages list
                SliverFillRemaining(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 100, // Extra padding for input area
                    ),
                    // itemCount: messages.length,
                    itemBuilder: (context, index) {
                      // Message widget building logic
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: const Text('Message placeholder'),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Loading indicator overlay (if loading)
            // Positioned(...)

            // Animated bottom input area
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.8), // 80% hidden
                  end: Offset.zero,             // Fully visible
                ).animate(
                  CurvedAnimation(
                    parent: AnimationController(
                      duration: const Duration(milliseconds: 250),
                      vsync: NavigatorState(), // This is just for preview
                    )..forward(),
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Visual hint bar when partially hidden
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Input widget would go here
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Center(
                          child: Text('Chat input placeholder'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/*
Key changes to implement in ai_chat_screen.dart:

1. Add to State class:
   - with TickerProviderStateMixin
   - AnimationController _inputAnimationController
   - Animation<Offset> _inputSlideAnimation
   - Scroll tracking variables

2. Initialize in initState:
   - Set up animation controllers
   - Configure slide animation

3. Build method structure:
   - Wrap with NotificationListener
   - Use Stack for layered layout
   - CustomScrollView with SliverAppBar
   - Positioned SlideTransition for input

4. Scroll handling:
   - Velocity-based detection
   - Auto-show timer after 2 seconds
   - Always show when at bottom

5. Features:
   - Floating app bar (hides on scroll down, shows on up)
   - Sliding input (partial hide on scroll, full show on tap/up)
   - Smooth 250ms animations
   - Haptic feedback on transitions
*/
