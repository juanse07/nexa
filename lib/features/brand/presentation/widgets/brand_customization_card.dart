import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexa/features/brand/data/providers/brand_provider.dart';
import 'package:nexa/features/brand/presentation/widgets/brand_color_picker_dialog.dart';
// TODO: Restore these imports when re-enabling Pro subscription gating
// import 'package:nexa/core/di/injection.dart';
// import 'package:nexa/features/subscription/data/services/subscription_service.dart';
import 'package:nexa/features/statistics/presentation/widgets/doc_design_picker.dart';
import 'package:nexa/features/subscription/presentation/pages/subscription_paywall_page.dart';
import 'package:provider/provider.dart';

/// Card widget for brand customization, shown in Settings.
class BrandCustomizationCard extends StatefulWidget {
  const BrandCustomizationCard({super.key});

  @override
  State<BrandCustomizationCard> createState() => _BrandCustomizationCardState();
}

class _BrandCustomizationCardState extends State<BrandCustomizationCard> {
  // TODO: Restore Pro gating once Qonversion subscription is enabled.
  // For now, skip the async subscription check entirely so the card
  // renders immediately without waiting for a network call that may hang.
  final bool _isPro = true;
  final bool _checkingPro = false;

  @override
  void initState() {
    super.initState();
    // Load brand profile on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BrandProvider>().loadProfile();
    });
  }

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );

    if (picked == null || !mounted) return;

    final provider = context.read<BrandProvider>();
    final success = await provider.uploadLogo(File(picked.path));

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo uploaded and colors extracted!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to upload logo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openColorPicker(String slot, String? currentHex) {
    showDialog<void>(
      context: context,
      builder: (_) => BrandColorPickerDialog(
        slot: slot,
        currentHex: currentHex,
        onColorSelected: (String hex) {
          context.read<BrandProvider>().setEditColor(slot, hex);
        },
      ),
    );
  }

  Future<void> _saveColors() async {
    final provider = context.read<BrandProvider>();
    final success = await provider.saveColors();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Colors saved!' : (provider.error ?? 'Failed to save')),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _removeBranding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Remove Branding?'),
        content: const Text(
          'This will delete your logo and custom colors. '
          'Exported documents will revert to the default Nexa styling.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<BrandProvider>();
    final success = await provider.deleteBrandProfile();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Branding removed' : (provider.error ?? 'Failed to remove')),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_checkingPro) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _isPro ? _buildProContent(theme) : _buildLockedContent(theme),
      ),
    );
  }

  /// Locked state for non-Pro users.
  Widget _buildLockedContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.palette_outlined, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(
              'Brand Customization',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'PRO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.lock_outline, size: 32, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                'Upgrade to Pro to personalize your exported documents with your own logo and brand colors.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const SubscriptionPaywallPage()),
                  );
                },
                child: const Text('Upgrade to Pro'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onDesignSelected(BrandProvider provider, String design) {
    if (!_isPro && design != 'plain') {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const SubscriptionPaywallPage()),
      );
      return;
    }
    provider.setDocDesign(design);
  }

  /// Pro content: upload zone or brand profile display.
  Widget _buildProContent(ThemeData theme) {
    return Consumer<BrandProvider>(
      builder: (BuildContext context, BrandProvider provider, _) {
        final isLoading = provider.state == BrandLoadingState.loading;
        final isUploading = provider.state == BrandLoadingState.uploading ||
            provider.state == BrandLoadingState.extractingColors;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Brand Customization',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (isUploading)
              _buildUploadProgress(theme, provider)
            else if (!provider.hasProfile)
              _buildUploadZone(theme)
            else
              _buildBrandDisplay(theme, provider),

            // Document Style picker — always shown (works with or without logo)
            if (!isLoading && !isUploading) ...[
              const SizedBox(height: 20),
              Text(
                'Document Style',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose how exported documents look',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              DocDesignPicker(
                selected: provider.preferredDocDesign,
                isPro: _isPro,
                onSelected: (design) => _onDesignSelected(provider, design),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUploadProgress(ThemeData theme, BrandProvider provider) {
    final label = provider.state == BrandLoadingState.extractingColors
        ? 'Extracting brand colors with AI...'
        : 'Uploading logo...';
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(label, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildUploadZone(ThemeData theme) {
    return GestureDetector(
      onTap: _pickAndUploadLogo,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined, size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              'Upload Your Logo',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              'JPEG, PNG, or WebP (max 5MB)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandDisplay(ThemeData theme, BrandProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo preview
        if (provider.hasLogo) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              provider.profile!.logoHeaderUrl!,
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                height: 60,
                width: 120,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Color swatches row
        Row(
          children: [
            _buildColorSwatch(theme, 'Primary', 'primary', provider.displayPrimary),
            const SizedBox(width: 8),
            _buildColorSwatch(theme, 'Secondary', 'secondary', provider.displaySecondary),
            const SizedBox(width: 8),
            _buildColorSwatch(theme, 'Accent', 'accent', provider.displayAccent),
            const SizedBox(width: 8),
            _buildColorSwatch(theme, 'Neutral', 'neutral', provider.displayNeutral),
          ],
        ),

        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              Text(
                'AI Extracted',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
              ),
            ],
          ),
        ),

        // Save button (only when unsaved changes)
        if (provider.hasUnsavedChanges) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: provider.state == BrandLoadingState.savingColors ? null : _saveColors,
              icon: provider.state == BrandLoadingState.savingColors
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Save Colors'),
            ),
          ),
        ],

        const SizedBox(height: 12),
        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickAndUploadLogo,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Replace Logo'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: provider.state == BrandLoadingState.deleting ? null : _removeBranding,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorSwatch(ThemeData theme, String label, String slot, String? hexColor) {
    final color = _parseHex(hexColor);
    return Expanded(
      child: GestureDetector(
        onTap: () => _openColorPicker(slot, hexColor),
        child: Column(
          children: [
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: color ?? Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Color? _parseHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return null;
  final value = int.tryParse(h, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}
