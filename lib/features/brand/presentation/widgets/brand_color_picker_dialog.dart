import 'package:flutter/material.dart';

/// A simple brand color picker dialog with hex input and preset swatches.
class BrandColorPickerDialog extends StatefulWidget {
  const BrandColorPickerDialog({
    required this.slot,
    required this.currentHex,
    required this.onColorSelected,
    super.key,
  });

  final String slot;
  final String? currentHex;
  final ValueChanged<String> onColorSelected;

  @override
  State<BrandColorPickerDialog> createState() => _BrandColorPickerDialogState();
}

class _BrandColorPickerDialogState extends State<BrandColorPickerDialog> {
  late TextEditingController _hexController;
  Color? _previewColor;

  // Brand-friendly color presets
  static const _presets = [
    // Dark / Primary options
    '#1e293b', '#0f172a', '#1a1a2e', '#16213e', '#0d1b2a',
    '#1b1b1b', '#2d3436', '#2c3e50', '#34495e', '#4a4a4a',
    // Blue / Accent options
    '#3b82f6', '#2563eb', '#1d4ed8', '#0ea5e9', '#06b6d4',
    // Green options
    '#10b981', '#059669', '#22c55e', '#16a34a',
    // Red / Warm options
    '#ef4444', '#dc2626', '#f97316', '#f59e0b',
    // Purple options
    '#8b5cf6', '#7c3aed', '#a855f7', '#6366f1',
    // Light / Neutral options
    '#f8fafc', '#f1f5f9', '#e2e8f0', '#fef3c7', '#ecfdf5',
    '#fce7f3', '#ede9fe', '#fff7ed',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.currentHex ?? '#1e293b';
    _hexController = TextEditingController(text: initial);
    _previewColor = _parseHex(initial);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color? _parseHex(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return null;
    final value = int.tryParse(h, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  void _selectColor(String hex) {
    setState(() {
      _hexController.text = hex;
      _previewColor = _parseHex(hex);
    });
  }

  void _onHexChanged(String value) {
    String hex = value;
    if (!hex.startsWith('#')) hex = '#$hex';
    if (hex.length == 7) {
      final color = _parseHex(hex);
      if (color != null) {
        setState(() {
          _previewColor = color;
        });
      }
    }
  }

  void _confirm() {
    String hex = _hexController.text.trim();
    if (!hex.startsWith('#')) hex = '#$hex';
    if (hex.length == 7 && _parseHex(hex) != null) {
      widget.onColorSelected(hex.toLowerCase());
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotLabel = widget.slot[0].toUpperCase() + widget.slot.substring(1);

    return AlertDialog(
      title: Text('$slotLabel Color'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview
            Container(
              height: 48,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _previewColor ?? Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
            ),
            const SizedBox(height: 12),

            // Hex input
            TextField(
              controller: _hexController,
              onChanged: _onHexChanged,
              decoration: const InputDecoration(
                labelText: 'Hex Color',
                hintText: '#1e293b',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.color_lens_outlined),
              ),
              maxLength: 7,
            ),
            const SizedBox(height: 8),

            // Preset swatches
            Text(
              'Presets',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 140,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: _presets.length,
                itemBuilder: (BuildContext context, int i) {
                  final hex = _presets[i];
                  final color = _parseHex(hex)!;
                  final isSelected = _hexController.text.toLowerCase() == hex;
                  return GestureDetector(
                    onTap: () => _selectColor(hex),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : Border.all(color: Colors.black12),
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)]
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _confirm, child: const Text('Apply')),
      ],
    );
  }
}
