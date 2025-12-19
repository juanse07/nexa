import 'package:flutter/material.dart';

/// A beautiful avatar widget that shows user initials when no profile picture is available.
/// Generates a consistent gradient color based on the user's name.
class InitialsAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? firstName;
  final String? lastName;
  final String? email;
  final double radius;
  final double? fontSize;

  const InitialsAvatar({
    super.key,
    this.imageUrl,
    this.firstName,
    this.lastName,
    this.email,
    this.radius = 24,
    this.fontSize,
  });

  /// Get initials from name or email
  String get _initials {
    String initials = '';

    // Try first name + last name
    if (firstName != null && firstName!.trim().isNotEmpty) {
      initials += firstName!.trim()[0].toUpperCase();
    }
    if (lastName != null && lastName!.trim().isNotEmpty) {
      initials += lastName!.trim()[0].toUpperCase();
    }

    // If we have initials, return them
    if (initials.isNotEmpty) return initials;

    // Fall back to email
    if (email != null && email!.trim().isNotEmpty) {
      final emailPart = email!.split('@').first;
      if (emailPart.isNotEmpty) {
        initials = emailPart[0].toUpperCase();
        if (emailPart.length > 1) {
          // Try to find a second letter (after a dot or number)
          final parts = emailPart.split(RegExp(r'[._-]'));
          if (parts.length > 1 && parts[1].isNotEmpty) {
            initials += parts[1][0].toUpperCase();
          }
        }
      }
    }

    // Ultimate fallback
    return initials.isEmpty ? '?' : initials;
  }

  /// Generate a consistent gradient based on the name/email
  List<Color> get _gradientColors {
    // Use the initials or name to generate a consistent hash
    final seed = (firstName ?? '') + (lastName ?? '') + (email ?? '');
    final hash = seed.isEmpty ? 0 : seed.hashCode;

    // Beautiful gradient pairs
    const gradientPairs = [
      [Color(0xFF667EEA), Color(0xFF764BA2)], // Purple-violet
      [Color(0xFF11998E), Color(0xFF38EF7D)], // Teal-green
      [Color(0xFFFC466B), Color(0xFF3F5EFB)], // Pink-blue
      [Color(0xFFF093FB), Color(0xFFF5576C)], // Pink-coral
      [Color(0xFF4FACFE), Color(0xFF00F2FE)], // Sky blue-cyan
      [Color(0xFF43E97B), Color(0xFF38F9D7)], // Green-teal
      [Color(0xFFFA709A), Color(0xFFFEE140)], // Pink-yellow
      [Color(0xFF30CFD0), Color(0xFF330867)], // Cyan-purple
      [Color(0xFFFF9A8B), Color(0xFFFF6A88)], // Coral-pink
      [Color(0xFF667EEA), Color(0xFF43E97B)], // Purple-green
      [Color(0xFFFDA085), Color(0xFFF6D365)], // Peach-gold
      [Color(0xFF5EE7DF), Color(0xFFB490CA)], // Mint-lavender
    ];

    final index = hash.abs() % gradientPairs.length;
    return gradientPairs[index];
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final calculatedFontSize = fontSize ?? (radius * 0.8);

    if (hasImage) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(imageUrl!),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    // Show beautiful initials
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: _gradientColors[0].withValues(alpha: 0.4),
            blurRadius: radius * 0.3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: calculatedFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: _initials.length > 1 ? 1 : 0,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A convenient builder that handles the common avatar pattern with fallback
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? fullName; // Alternative to firstName/lastName
  final double radius;
  final double? fontSize;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.firstName,
    this.lastName,
    this.email,
    this.fullName,
    this.radius = 24,
    this.fontSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Parse fullName if provided
    String? parsedFirstName = firstName;
    String? parsedLastName = lastName;

    if (fullName != null && fullName!.trim().isNotEmpty && firstName == null) {
      final parts = fullName!.trim().split(' ');
      parsedFirstName = parts.first;
      if (parts.length > 1) {
        parsedLastName = parts.last;
      }
    }

    final avatar = InitialsAvatar(
      imageUrl: imageUrl,
      firstName: parsedFirstName,
      lastName: parsedLastName,
      email: email,
      radius: radius,
      fontSize: fontSize,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}
