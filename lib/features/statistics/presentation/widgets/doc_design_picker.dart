import 'package:flutter/material.dart';

/// Visual picker for document design templates (Plain, Classic, Executive, Modern).
class DocDesignPicker extends StatelessWidget {
  final String selected;
  final bool isPro;
  final ValueChanged<String> onSelected;

  const DocDesignPicker({
    super.key,
    required this.selected,
    required this.isPro,
    required this.onSelected,
  });

  static const _designs = [
    _DesignInfo(key: 'plain', label: 'Plain', proOnly: false),
    _DesignInfo(key: 'classic', label: 'Classic', proOnly: true),
    _DesignInfo(key: 'executive', label: 'Executive', proOnly: true),
    _DesignInfo(key: 'modern', label: 'Modern', proOnly: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _designs.map((d) {
        final isSelected = selected == d.key;
        final locked = d.proOnly && !isPro;
        final isLast = d.key == 'modern';

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: locked ? null : () => onSelected(d.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 110,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1a1a1a).withOpacity(0.04)
                      : locked
                          ? Colors.grey.shade50
                          : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1a1a1a)
                        : Colors.grey.shade200,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _DesignPreview(designKey: d.key),
                        const SizedBox(height: 6),
                        Text(
                          d.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: locked
                                ? Colors.grey.shade400
                                : isSelected
                                    ? const Color(0xFF1a1a1a)
                                    : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    if (isSelected)
                      const Positioned(
                        top: 5,
                        right: 5,
                        child: Icon(
                          Icons.check_circle,
                          color: Color(0xFF1a1a1a),
                          size: 16,
                        ),
                      ),
                    if (locked)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock,
                                size: 9,
                                color: Colors.amber.shade800,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DesignInfo {
  final String key;
  final String label;
  final bool proOnly;

  const _DesignInfo({
    required this.key,
    required this.label,
    required this.proOnly,
  });
}

/// Mini visual preview of each design style.
class _DesignPreview extends StatelessWidget {
  final String designKey;

  const _DesignPreview({required this.designKey});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 44,
      child: CustomPaint(
        painter: _DesignPreviewPainter(designKey),
      ),
    );
  }
}

class _DesignPreviewPainter extends CustomPainter {
  final String designKey;

  _DesignPreviewPainter(this.designKey);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // White background with subtle border
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    switch (designKey) {
      case 'plain':
        _paintPlain(canvas, size);
      case 'classic':
        _paintClassic(canvas, size);
      case 'executive':
        _paintExecutive(canvas, size);
      case 'modern':
        _paintModern(canvas, size);
    }
  }

  void _paintPlain(Canvas canvas, Size size) {
    // Pure minimal — just thin grey lines
    final linePaint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 0.3;

    // Thin title line
    canvas.drawRect(
      Rect.fromLTWH(6, 6, 20, 2),
      Paint()..color = const Color(0xFF000000),
    );
    // Horizontal lines (rows)
    for (var i = 0; i < 5; i++) {
      final y = 14.0 + i * 6.0;
      canvas.drawLine(Offset(6, y), Offset(size.width - 6, y), linePaint);
    }
  }

  void _paintClassic(Canvas canvas, Size size) {
    // White header area with brand-colored title text (dark line)
    canvas.drawRect(
      Rect.fromLTWH(6, 5, 22, 2.5),
      Paint()..color = const Color(0xFF1a1a1a),
    );
    // Thin accent line
    canvas.drawRect(
      Rect.fromLTWH(6, 10, size.width - 12, 1),
      Paint()..color = const Color(0xFF3b82f6),
    );
    // Light grey header row
    canvas.drawRect(
      Rect.fromLTWH(6, 14, size.width - 12, 5),
      Paint()..color = const Color(0xFFFAFAFA),
    );
    canvas.drawLine(
      Offset(6, 19),
      Offset(size.width - 6, 19),
      Paint()
        ..color = const Color(0xFFD1D5DB)
        ..strokeWidth = 0.3,
    );
    // Subtle zebra rows
    for (var i = 0; i < 3; i++) {
      final y = 21.0 + i * 7.0;
      if (i % 2 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(6, y, size.width - 12, 6),
          Paint()..color = const Color(0xFFFAFBFC),
        );
      }
      canvas.drawLine(
        Offset(6, y + 6),
        Offset(size.width - 6, y + 6),
        Paint()
          ..color = const Color(0xFFE5E7EB)
          ..strokeWidth = 0.3,
      );
    }
  }

  void _paintExecutive(Canvas canvas, Size size) {
    // Thin accent line at very top
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 2),
      Paint()..color = const Color(0xFF3b82f6),
    );
    // Title text (brand color represented)
    canvas.drawRect(
      Rect.fromLTWH(6, 7, 24, 2.5),
      Paint()..color = const Color(0xFF1a1a1a),
    );
    // Subtitle
    canvas.drawRect(
      Rect.fromLTWH(6, 11, 16, 1.5),
      Paint()..color = const Color(0xFF9CA3AF),
    );
    // Clean rows with very subtle separators
    for (var i = 0; i < 4; i++) {
      final y = 18.0 + i * 6.5;
      canvas.drawLine(
        Offset(6, y),
        Offset(size.width - 6, y),
        Paint()
          ..color = const Color(0xFFE5E7EB)
          ..strokeWidth = 0.3,
      );
    }
  }

  void _paintModern(Canvas canvas, Size size) {
    // Title — pure black
    canvas.drawRect(
      Rect.fromLTWH(6, 5, 20, 2.5),
      Paint()..color = const Color(0xFF000000),
    );
    // Rounded summary card
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 11, size.width - 12, 8),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFF7F7F8),
    );
    // Ghost header labels (very light)
    canvas.drawRect(
      Rect.fromLTWH(6, 23, 10, 1.5),
      Paint()..color = const Color(0xFF9CA3AF),
    );
    canvas.drawRect(
      Rect.fromLTWH(20, 23, 10, 1.5),
      Paint()..color = const Color(0xFF9CA3AF),
    );
    canvas.drawRect(
      Rect.fromLTWH(34, 23, 10, 1.5),
      Paint()..color = const Color(0xFF9CA3AF),
    );
    // Rows with barely-there lines
    for (var i = 0; i < 3; i++) {
      final y = 28.0 + i * 5.5;
      if (i % 2 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(6, y, size.width - 12, 5),
          Paint()..color = const Color(0xFFFAFAFB),
        );
      }
      canvas.drawLine(
        Offset(6, y + 5),
        Offset(size.width - 6, y + 5),
        Paint()
          ..color = const Color(0xFFF0F0F0)
          ..strokeWidth = 0.3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
