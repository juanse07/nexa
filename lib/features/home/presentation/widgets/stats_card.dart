import 'package:flutter/material.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5), // Final padding - 1px less
      decoration: BoxDecoration(
        color: Colors.white, // Neutral white background
        borderRadius: BorderRadius.circular(12), // Smaller radius
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowBlack, // 10% black - subtle shadow
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(4), // EXTREME padding
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.greyMedium, AppColors.textMuted],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 12, // EXTREME icon size
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.charcoal, // Dark grey text
              fontSize: 14, // EXTREME reduction
              fontWeight: FontWeight.bold,
              letterSpacing: 0,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600], // Medium grey for subtitle
              fontSize: 8, // EXTREME reduction
              height: 1.0, // Tight line height
            ),
          ),
        ],
      ),
    );
  }
}
