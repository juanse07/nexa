import 'package:flutter/material.dart';
import '../../data/models/statistics_models.dart';

/// Staff leaderboard showing top performers
class StaffLeaderboard extends StatelessWidget {
  final List<TopPerformer> topPerformers;
  final String periodLabel;

  const StaffLeaderboard({
    super.key,
    required this.topPerformers,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (topPerformers.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.emoji_events, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No data for this period',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Performers',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Based on shifts completed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Leaderboard list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topPerformers.length.clamp(0, 5),
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final performer = topPerformers[index];
              return _LeaderboardItem(
                rank: index + 1,
                performer: performer,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeaderboardItem extends StatelessWidget {
  final int rank;
  final TopPerformer performer;

  const _LeaderboardItem({
    required this.rank,
    required this.performer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Rank badge
          _RankBadge(rank: rank),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: performer.picture.isNotEmpty
                ? NetworkImage(performer.picture)
                : null,
            child: performer.picture.isEmpty
                ? Text(
                    performer.name.isNotEmpty ? performer.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Name and stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  performer.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${performer.shiftsCompleted} shifts • ${performer.hoursWorked.toStringAsFixed(0)}h',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Punctuality score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getPunctualityColor(performer.punctualityScore).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: _getPunctualityColor(performer.punctualityScore),
                ),
                const SizedBox(width: 4),
                Text(
                  '${performer.punctualityScore}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getPunctualityColor(performer.punctualityScore),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPunctualityColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (rank) {
      case 1:
        backgroundColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFF59E0B);
        break;
      case 2:
        backgroundColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF6B7280);
        break;
      case 3:
        backgroundColor = const Color(0xFFFED7AA);
        textColor = const Color(0xFFEA580C);
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
