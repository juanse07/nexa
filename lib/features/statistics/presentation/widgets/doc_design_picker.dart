import 'package:flutter/material.dart';

/// Visual picker for document design templates (Plain, Classic, Executive).
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
    _DesignInfo(
      key: 'plain',
      label: 'Plain',
      proOnly: false,
    ),
    _DesignInfo(
      key: 'classic',
      label: 'Classic',
      proOnly: true,
    ),
    _DesignInfo(
      key: 'executive',
      label: 'Executive',
      proOnly: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _designs.map((d) {
        final isSelected = selected == d.key;
        final locked = d.proOnly && !isPro;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: d.key != 'executive' ? 10 : 0,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: locked ? null : () => onSelected(d.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 120,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF212C4A).withOpacity(0.05)
                      : locked
                          ? Colors.grey.shade100
                          : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF212C4A)
                        : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    // Mini preview + label
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _DesignPreview(designKey: d.key),
                        const SizedBox(height: 8),
                        Text(
                          d.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: locked
                                ? Colors.grey.shade400
                                : isSelected
                                    ? const Color(0xFF212C4A)
                                    : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    // Selected checkmark
                    if (isSelected)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.check_circle,
                          color: Color(0xFF212C4A),
                          size: 18,
                        ),
                      ),
                    // PRO badge + lock for non-Pro
                    if (locked)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock,
                                size: 10,
                                color: Colors.amber.shade800,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 9,
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
      width: 60,
      height: 50,
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
    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
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
    }
  }

  void _paintPlain(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    // Simple gray lines representing rows
    for (var i = 0; i < 5; i++) {
      final y = 10.0 + i * 8.0;
      canvas.drawLine(Offset(6, y), Offset(size.width - 6, y), linePaint);
    }
  }

  void _paintClassic(Canvas canvas, Size size) {
    // Full-bleed colored header
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 12),
      Paint()..color = const Color(0xFF212C4A),
    );
    // Accent bar
    canvas.drawRect(
      Rect.fromLTWH(0, 12, size.width, 2),
      Paint()..color = const Color(0xFF3b82f6),
    );
    // Zebra rows
    for (var i = 0; i < 4; i++) {
      final y = 18.0 + i * 8.0;
      if (i % 2 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(4, y, size.width - 8, 7),
          Paint()..color = const Color(0xFFF8FAFC),
        );
      }
      canvas.drawLine(
        Offset(4, y + 7),
        Offset(size.width - 4, y + 7),
        Paint()
          ..color = Colors.grey.shade200
          ..strokeWidth = 0.5,
      );
    }
  }

  void _paintExecutive(Canvas canvas, Size size) {
    // Thin colored accent line at top
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 3),
      Paint()..color = const Color(0xFF3b82f6),
    );
    // Title area (white with primary text represented by a dark line)
    canvas.drawRect(
      Rect.fromLTWH(8, 7, 30, 3),
      Paint()..color = const Color(0xFF212C4A),
    );
    // Gray header row
    canvas.drawRect(
      Rect.fromLTWH(4, 16, size.width - 8, 7),
      Paint()..color = const Color(0xFFF1F5F9),
    );
    // Clean rows with subtle separators
    for (var i = 0; i < 3; i++) {
      final y = 27.0 + i * 8.0;
      canvas.drawLine(
        Offset(4, y),
        Offset(size.width - 4, y),
        Paint()
          ..color = Colors.grey.shade200
          ..strokeWidth = 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
