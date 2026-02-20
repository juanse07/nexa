import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/features/auth/data/services/phone_auth_service.dart';
import 'package:nexa/features/users/data/services/manager_service.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/services/file_upload_service.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';
import 'package:nexa/shared/widgets/caricature_generator_sheet.dart';
import 'package:nexa/shared/widgets/initials_avatar.dart';

class ManagerProfilePage extends StatefulWidget {
  const ManagerProfilePage({super.key});

  @override
  State<ManagerProfilePage> createState() => _ManagerProfilePageState();
}

class _ManagerProfilePageState extends State<ManagerProfilePage> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _appIdCtrl = TextEditingController();
  final _pictureCtrl = TextEditingController();

  late final ManagerService _service;
  late final FileUploadService _uploadService;
  final _imagePicker = ImagePicker();
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  bool _reverting = false;
  bool _linkingPhone = false;
  String? _error;

  /// The loaded profile data (for displaying auth info).
  ManagerProfile? _profile;

  /// The original (pre-caricature) picture URL from the backend.
  String? _originalPicture;

  /// Caricature history from backend (last 10, newest last).
  List<CaricatureHistoryItem> _caricatureHistory = [];

  @override
  void initState() {
    super.initState();
    final api = GetIt.I<ApiClient>();
    final storage = GetIt.I<FlutterSecureStorage>();
    _service = ManagerService(api, storage);
    _uploadService = FileUploadService(api);
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await _service.getMe();
      setState(() {
        _firstNameCtrl.text = me.firstName ?? '';
        _lastNameCtrl.text = me.lastName ?? '';
        _appIdCtrl.text = me.appId ?? '';
        _pictureCtrl.text = me.picture ?? '';
        _originalPicture = me.originalPicture;
        _caricatureHistory = me.caricatureHistory;
        _profile = me;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context)!.failedToLoadProfile;
        _loading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _uploading = true);

      String url;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        url = await _uploadService.uploadProfilePictureBytes(bytes, picked.name);
      } else {
        url = await _uploadService.uploadProfilePicture(File(picked.path));
      }

      setState(() {
        _pictureCtrl.text = url;
        _uploading = false;
      });
    } catch (e) {
      setState(() {
        _uploading = false;
        _error = '${AppLocalizations.of(context)!.failedToUploadImage}: $e';
      });
    }
  }

  /// Accept a caricature and save it immediately with the isCaricature flag.
  Future<void> _acceptCaricature(String caricatureUrl) async {
    setState(() {
      _pictureCtrl.text = caricatureUrl;
      _saving = true;
      _error = null;
    });

    try {
      final updated = await _service.updateMe(
        firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
        appId: _appIdCtrl.text.trim().isEmpty ? null : _appIdCtrl.text.trim(),
        picture: caricatureUrl,
        isCaricature: true,
      );
      if (!mounted) return;
      // Reload profile to get updated history
      final me = await _service.getMe();
      if (!mounted) return;
      setState(() {
        _originalPicture = updated.originalPicture;
        _caricatureHistory = me.caricatureHistory;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.newLookSaved)),
      );
    } catch (e) {
      setState(() => _error = '${AppLocalizations.of(context)!.failedToSave}: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Reuse a caricature from history as the current profile picture.
  Future<void> _reuseCaricature(CaricatureHistoryItem item) async {
    setState(() {
      _pictureCtrl.text = item.url;
      _saving = true;
      _error = null;
    });

    try {
      final updated = await _service.updateMe(
        firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
        appId: _appIdCtrl.text.trim().isEmpty ? null : _appIdCtrl.text.trim(),
        picture: item.url,
        isCaricature: true,
      );
      if (!mounted) return;
      setState(() {
        _originalPicture = updated.originalPicture;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.profilePictureUpdated)),
      );
    } catch (e) {
      setState(() => _error = '${AppLocalizations.of(context)!.failedToUpdate}: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Delete a caricature from history.
  Future<void> _deleteCaricature(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteCreationConfirm),
        content: Text(l10n.deleteCreationMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final updated = await _service.deleteCaricature(index);
      if (!mounted) return;
      setState(() => _caricatureHistory = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.creationDeleted)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.failedToDelete}: $e')),
      );
    }
  }

  /// Revert to the original (pre-caricature) picture — one tap, no friction.
  Future<void> _revertPicture() async {
    if (_originalPicture == null) return;

    setState(() {
      _reverting = true;
      _error = null;
    });

    try {
      final result = await _service.revertPicture();
      if (!mounted) return;
      setState(() {
        _pictureCtrl.text = result.picture ?? _originalPicture!;
        _originalPicture = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.revertedToOriginal)),
      );
    } catch (e) {
      setState(() => _error = '${AppLocalizations.of(context)!.failedToRevert}: $e');
    } finally {
      if (mounted) setState(() => _reverting = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.updateMe(
        firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
        appId: _appIdCtrl.text.trim().isEmpty ? null : _appIdCtrl.text.trim(),
        picture: _pictureCtrl.text.trim().isEmpty ? null : _pictureCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.profileUpdated)),
      );
      // Close the profile page and return to onboarding after successful save
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showFullImage(String imageUrl, {String? heroTag}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => _FullImageViewer(
          imageUrl: imageUrl,
          heroTag: heroTag,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _appIdCtrl.dispose();
    _pictureCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myProfile),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.save, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  _buildAvatar(),
                  const SizedBox(height: 8),
                  _buildPictureActions(),
                  if (_caricatureHistory.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildCreationsGallery(),
                  ],
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  TextField(
                    controller: _firstNameCtrl,
                    decoration: InputDecoration(labelText: l10n.firstName),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lastNameCtrl,
                    decoration: InputDecoration(labelText: l10n.lastName),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _appIdCtrl,
                    decoration: InputDecoration(labelText: l10n.appIdOptional),
                    keyboardType: TextInputType.number,
                    maxLength: 9,
                  ),
                  if (_profile != null) ...[
                    const SizedBox(height: 24),
                    _buildAccountSection(),
                  ],
                ],
              ),
            ),
    );
  }

  // ── Account section ─────────────────────────────────────────

  Widget _buildAccountSection() {
    final l10n = AppLocalizations.of(context)!;
    final profile = _profile!;
    final primary = profile.provider ?? 'unknown';
    final linked = profile.linkedProviders;

    // Determine which providers are linked (besides primary)
    final linkedNames = linked.map((lp) => lp['provider']?.toString() ?? '').toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 18, color: AppColors.primaryPurple.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(
              l10n.account,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Email (read-only)
        if (profile.email != null && profile.email!.isNotEmpty)
          _buildInfoRow(Icons.email_outlined, l10n.email, profile.email!),

        // Phone (read-only)
        if (profile.authPhoneNumber != null && profile.authPhoneNumber!.isNotEmpty)
          _buildInfoRow(Icons.phone_outlined, l10n.phone, profile.authPhoneNumber!),

        const SizedBox(height: 14),

        // Linked accounts header
        Text(
          l10n.linkedAccounts,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 8),

        // Provider chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildProviderChip(
              'google',
              isPrimary: primary == 'google',
              isLinked: primary == 'google' || linkedNames.contains('google'),
            ),
            _buildProviderChip(
              'apple',
              isPrimary: primary == 'apple',
              isLinked: primary == 'apple' || linkedNames.contains('apple'),
            ),
            _buildProviderChip(
              'phone',
              isPrimary: primary == 'phone',
              isLinked: primary == 'phone' || linkedNames.contains('phone'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderChip(String provider, {required bool isPrimary, required bool isLinked}) {
    final l10n = AppLocalizations.of(context)!;
    final label = _providerDisplayName(provider);
    final icon = _providerIcon(provider);
    final color = _providerColor(provider);

    if (isPrimary) {
      // Primary provider — solid chip with badge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(l10n.primary, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      );
    } else if (isLinked) {
      // Linked provider — outlined with checkmark
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            const SizedBox(width: 4),
            Icon(Icons.check_circle, size: 14, color: AppColors.success),
          ],
        ),
      );
    } else {
      // Not linked — show Link button or Coming soon
      final canLink = provider == 'phone';
      return GestureDetector(
        onTap: canLink ? _startPhoneLinking : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(width: 6),
              if (canLink)
                _linkingPhone
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                    : Text(l10n.linkAccount, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryPurple))
              else
                Text(l10n.comingSoon, style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      );
    }
  }

  String _providerDisplayName(String provider) {
    switch (provider) {
      case 'google': return 'Google';
      case 'apple': return 'Apple';
      case 'phone': return 'Phone';
      default: return provider;
    }
  }

  IconData _providerIcon(String provider) {
    switch (provider) {
      case 'google': return Icons.g_mobiledata_rounded;
      case 'apple': return Icons.apple_rounded;
      case 'phone': return Icons.phone_iphone_rounded;
      default: return Icons.link;
    }
  }

  Color _providerColor(String provider) {
    switch (provider) {
      case 'google': return const Color(0xFF4285F4);
      case 'apple': return AppColors.textDark;
      case 'phone': return AppColors.success;
      default: return AppColors.textMuted;
    }
  }

  // ── Phone linking flow ─────────────────────────────────────

  Future<void> _startPhoneLinking() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PhoneLinkSheet(),
    );
    if (result == true && mounted) {
      // Reload profile to pick up the newly linked phone
      setState(() => _linkingPhone = true);
      await _load();
      setState(() => _linkingPhone = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.phoneLinkedSuccessfully)),
        );
      }
    }
  }

  /// Builds the row of action buttons below the avatar.
  Widget _buildPictureActions() {
    final hasPicture = _pictureCtrl.text.trim().isNotEmpty;
    final canRevert = _originalPicture != null && _originalPicture!.isNotEmpty;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        // Upload photo from gallery
        _uploading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : TextButton.icon(
                onPressed: _pickAndUploadImage,
                icon: const Icon(Icons.photo_library_rounded, size: 16),
                label: Text(AppLocalizations.of(context)!.upload),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
        if (hasPicture)
          TextButton.icon(
            onPressed: _showCaricatureSheet,
            icon: const Icon(Icons.camera_enhance_rounded, size: 16),
            label: Text(AppLocalizations.of(context)!.glowUp),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.secondary,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        if (canRevert)
          _reverting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton.icon(
                  onPressed: _revertPicture,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: Text(AppLocalizations.of(context)!.originalPhoto),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
      ],
    );
  }

  void _showCaricatureSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CaricatureGeneratorSheet(
        currentPictureUrl: _pictureCtrl.text.trim(),
        onAccepted: _acceptCaricature,
        userName: _firstNameCtrl.text.trim().isNotEmpty ? _firstNameCtrl.text.trim() : null,
        userLastName: _lastNameCtrl.text.trim().isNotEmpty ? _lastNameCtrl.text.trim() : null,
      ),
    );
  }

  Widget _buildAvatar() {
    final hasPicture = _pictureCtrl.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: _uploading
          ? null
          : hasPicture
              ? () => _showFullImage(_pictureCtrl.text.trim(), heroTag: 'profile-avatar')
              : _pickAndUploadImage,
      child: Hero(
        tag: 'profile-avatar',
        child: Stack(
          children: [
            InitialsAvatar(
              imageUrl: _pictureCtrl.text.trim(),
              firstName: _firstNameCtrl.text.trim(),
              lastName: _lastNameCtrl.text.trim(),
              radius: 48,
            ),
            if (_uploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Horizontal gallery of previous caricature creations.
  Widget _buildCreationsGallery() {
    // Show newest first, max 5
    final items = _caricatureHistory.reversed.take(5).toList();
    final isCurrentPicCaricature = items.any((c) => c.url == _pictureCtrl.text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.collections_rounded, size: 18, color: AppColors.primaryPurple.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.myCreations,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryPurple,
              ),
            ),
            const Spacer(),
            Text(
              '${items.length} of ${_caricatureHistory.length}',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = items[i];
              final isActive = item.url == _pictureCtrl.text.trim();
              // index in original array (for delete API)
              final originalIndex = _caricatureHistory.length - 1 - i;

              return _buildCreationCard(item, isActive, originalIndex);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreationCard(CaricatureHistoryItem item, bool isActive, int originalIndex) {
    final roleLabel = _formatLabel(item.role);
    final styleLabel = _formatLabel(item.artStyle);

    return GestureDetector(
      onTap: () => _showCreationDetail(item, isActive, originalIndex),
      child: Container(
        width: 105,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? AppColors.primaryIndigo : AppColors.border,
            width: isActive ? 2.5 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: AppColors.primaryPurple.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      item.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceGray,
                        child: const Icon(Icons.broken_image, size: 24, color: AppColors.textMuted),
                      ),
                    ),
                    if (isActive)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.active,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryPurple.withValues(alpha: 0.05) : Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
              ),
              child: Column(
                children: [
                  Text(
                    roleLabel,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    styleLabel,
                    style: TextStyle(fontSize: 9, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show a bottom sheet with the full creation + actions.
  void _showCreationDetail(CaricatureHistoryItem item, bool isActive, int originalIndex) {
    final roleLabel = _formatLabel(item.role);
    final styleLabel = _formatLabel(item.artStyle);
    final dateStr = '${item.createdAt.month}/${item.createdAt.day}/${item.createdAt.year}';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Large image — tap to view full screen
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _showFullImage(item.url);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  item.url,
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 300,
                    color: AppColors.surfaceGray,
                    child: const Icon(Icons.broken_image, size: 48, color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Info row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _infoChip(Icons.badge_outlined, roleLabel),
                const SizedBox(width: 8),
                _infoChip(Icons.palette_outlined, styleLabel),
                const SizedBox(width: 8),
                _infoChip(Icons.calendar_today_outlined, dateStr),
              ],
            ),
            const SizedBox(height: 18),
            // Action buttons
            Row(
              children: [
                // Delete button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteCaricature(originalIndex);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(AppLocalizations.of(context)!.delete),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Use / View full button
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: isActive
                        ? () {
                            Navigator.pop(ctx);
                            _showFullImage(item.url);
                          }
                        : () {
                            Navigator.pop(ctx);
                            _reuseCaricature(item);
                          },
                    icon: Icon(isActive ? Icons.fullscreen_rounded : Icons.check_rounded, size: 20),
                    label: Text(isActive ? AppLocalizations.of(context)!.viewFullSize : AppLocalizations.of(context)!.useThisPhoto),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  String _formatLabel(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

/// Full-screen image viewer with pinch-to-zoom and dismiss.
class _FullImageViewer extends StatelessWidget {
  const _FullImageViewer({required this.imageUrl, this.heroTag});

  final String imageUrl;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final imageWidget = InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, size: 64, color: Colors.white54),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: heroTag != null
                  ? Hero(tag: heroTag!, child: imageWidget)
                  : imageWidget,
            ),
            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for linking a phone number to the current account.
/// Handles Firebase OTP verification directly (bypasses PhoneAuthService login
/// flow), then calls [PhoneAuthService.linkPhoneToAccount] to link via backend.
class _PhoneLinkSheet extends StatefulWidget {
  const _PhoneLinkSheet();

  @override
  State<_PhoneLinkSheet> createState() => _PhoneLinkSheetState();
}

class _PhoneLinkSheetState extends State<_PhoneLinkSheet> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _linkService = PhoneAuthService();

  String? _verificationId;
  int? _resendToken;
  bool _sendingCode = false;
  bool _codeSent = false;
  bool _verifying = false;
  String? _error;
  String _countryCode = '+1';

  static const _countryCodes = [
    ('+1', 'US'),
    ('+44', 'UK'),
    ('+52', 'MX'),
    ('+34', 'ES'),
    ('+33', 'FR'),
    ('+49', 'DE'),
  ];

  Future<void> _sendOtp() async {
    final phone = '$_countryCode${_phoneCtrl.text.trim()}';
    if (_phoneCtrl.text.trim().length < 7) {
      setState(() => _error = AppLocalizations.of(context)!.pleaseEnterValidPhoneNumber);
      return;
    }
    setState(() { _sendingCode = true; _error = null; });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android — sign in and link immediately
          await _signInAndLink(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          final l10n = AppLocalizations.of(context)!;
          String msg = l10n.verificationFailed;
          if (e.code == 'invalid-phone-number') msg = l10n.invalidPhoneFormat;
          else if (e.code == 'too-many-requests') msg = l10n.tooManyAttemptsMessage;
          else if (e.message != null) msg = e.message!;
          setState(() { _sendingCode = false; _error = msg; });
        },
        codeSent: (String vId, int? resendToken) {
          if (!mounted) return;
          _verificationId = vId;
          _resendToken = resendToken;
          setState(() { _sendingCode = false; _codeSent = true; });
        },
        codeAutoRetrievalTimeout: (String vId) {
          _verificationId = vId;
        },
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _sendingCode = false; _error = '${AppLocalizations.of(context)!.failedToSendCode}: $e'; });
    }
  }

  Future<void> _verifyAndLink() async {
    if (_otpCtrl.text.trim().length < 6) {
      setState(() => _error = AppLocalizations.of(context)!.pleaseEnterVerificationCode);
      return;
    }
    if (_verificationId == null) {
      setState(() => _error = AppLocalizations.of(context)!.noVerificationInProgress);
      return;
    }
    setState(() { _verifying = true; _error = null; });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
      );
      await _signInAndLink(credential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      String msg = l10n.verificationFailed;
      if (e.code == 'invalid-verification-code') msg = l10n.invalidCodeMessage;
      else if (e.code == 'session-expired') msg = l10n.codeExpiredMessage;
      setState(() { _verifying = false; _error = msg; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _verifying = false; _error = '${AppLocalizations.of(context)!.verificationFailed}: $e'; });
    }
  }

  /// Sign in with Firebase credential, get ID token, link via backend, sign out.
  Future<void> _signInAndLink(PhoneAuthCredential credential) async {
    try {
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) {
        if (!mounted) return;
        setState(() { _verifying = false; _error = AppLocalizations.of(context)!.firebaseAuthFailed; });
        return;
      }
      final idToken = await user.getIdToken();
      if (idToken == null) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() { _verifying = false; _error = AppLocalizations.of(context)!.failedToGetAuthToken; });
        return;
      }

      // Link phone to existing account via backend
      final linked = await _linkService.linkPhoneToAccount(idToken);
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      if (linked) {
        Navigator.pop(context, true);
      } else {
        setState(() { _verifying = false; _error = AppLocalizations.of(context)!.failedToLinkPhoneNumber; });
      }
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() { _verifying = false; _error = '${AppLocalizations.of(context)!.failedToLink}: $e'; });
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.borderMedium,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            AppLocalizations.of(context)!.linkPhoneNumber,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.addPhoneDescription,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          if (!_codeSent) ...[
            // Phone number input
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _countryCode,
                      items: _countryCodes.map((c) {
                        return DropdownMenuItem(value: c.$1, child: Text('${c.$1} ${c.$2}', style: const TextStyle(fontSize: 14)));
                      }).toList(),
                      onChanged: (v) => setState(() => _countryCode = v ?? '+1'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.phoneNumberHint,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sendingCode ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _sendingCode
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(AppLocalizations.of(context)!.sendVerificationCode, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ] else ...[
            // OTP input
            TextField(
              controller: _otpCtrl,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.sixDigitCode,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              autofocus: true,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _verifying ? null : _verifyAndLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _verifying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(AppLocalizations.of(context)!.verifyAndLink, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(fontSize: 12, color: AppColors.error), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
