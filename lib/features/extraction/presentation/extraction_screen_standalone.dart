import 'package:flutter/material.dart';
import '../../../core/widgets/custom_sliver_app_bar.dart';

class ExtractionScreen extends StatefulWidget {
  final int initialIndex;

  const ExtractionScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<ExtractionScreen> createState() => _ExtractionScreenState();
}

class _ExtractionScreenState extends State<ExtractionScreen>
    with SingleTickerProviderStateMixin {
  int _selectedChipIndex = 0;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _selectedChipIndex = widget.initialIndex;
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            CustomSliverAppBar(
              title: 'Create Event',
              subtitle: 'Extract and manage your events',
              expandedHeight: 70.0,
              floating: true,
              snap: true,
              pinned: false,
            ),
            _buildPinnedChipSelector(),
          ];
        },
        body: _buildTabContent(),
      ),
    );
  }

  Widget _buildPinnedChipSelector() {
    final topPadding = MediaQuery.of(context).padding.top;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _ChipHeaderDelegate(
        height: 46.0,
        safeAreaPadding: topPadding,
        child: Container(
          color: Colors.white,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildCompactChip(0, Icons.upload_file, 'Upload'),
                  _buildCompactChip(1, Icons.edit, 'Manual'),
                  _buildCompactChip(2, Icons.cloud_upload, 'Multi-Upload'),
                  _buildCompactChip(3, Icons.chat, 'AI Chat'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactChip(int index, IconData icon, String label) {
    final bool isSelected = _selectedChipIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedChipIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 20 : 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedChipIndex) {
      case 0:
        return _buildUploadTab();
      case 1:
        return _buildManualTab();
      case 2:
        return _buildMultiUploadTab();
      case 3:
        return _buildAIChatTab();
      default:
        return _buildUploadTab();
    }
  }

  Widget _buildUploadTab() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.cloud_upload,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Upload Files',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Drag and drop or click to select files',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualTab() {
    return const Center(
      child: Text('Manual Entry Tab'),
    );
  }

  Widget _buildMultiUploadTab() {
    return const Center(
      child: Text('Multi-Upload Tab'),
    );
  }

  Widget _buildAIChatTab() {
    return const Center(
      child: Text('AI Chat Tab'),
    );
  }
}

class _ChipHeaderDelegate extends SliverPersistentHeaderDelegate {
  _ChipHeaderDelegate({
    required this.child,
    required this.height,
    this.safeAreaPadding = 0.0,
  });

  final Widget child;
  final double height;
  final double safeAreaPadding;

  @override
  double get minExtent => height + safeAreaPadding;

  @override
  double get maxExtent => height + safeAreaPadding;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_ChipHeaderDelegate oldDelegate) {
    return height != oldDelegate.height ||
           child != oldDelegate.child ||
           safeAreaPadding != oldDelegate.safeAreaPadding;
  }
}