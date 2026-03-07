import 'package:flutter/material.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';
import 'package:nexa/shared/widgets/initials_avatar.dart';
import '../data/services/payroll_export_service.dart';

/// Roster-based payroll mapping screen.
///
/// Instead of typing opaque userKeys, the manager sees their full staff roster
/// (photos, names, roles) and enters external payroll IDs inline.
class EmployeeMappingScreen extends StatefulWidget {
  const EmployeeMappingScreen({super.key});

  @override
  State<EmployeeMappingScreen> createState() => _EmployeeMappingScreenState();
}

class _EmployeeMappingScreenState extends State<EmployeeMappingScreen> {
  final _service = PayrollExportService();
  final _searchController = TextEditingController();

  List<StaffRosterItem> _roster = [];
  PayrollConfig _config = PayrollConfig();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String _searchQuery = '';

  // In-memory edits: userKey → externalEmployeeId
  final Map<String, String> _editedIds = {};
  // In-memory edits: userKey → workerType
  final Map<String, String> _editedWorkerTypes = {};
  // Stable controllers so cursor doesn't jump on setState
  final Map<String, TextEditingController> _idControllers = {};

  @override
  void initState() {
    super.initState();
    _thresholdController = TextEditingController(text: '40');
    _multiplierController = TextEditingController(text: '1.5');
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _thresholdController.dispose();
    _multiplierController.dispose();
    for (final c in _idControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await Future.wait([
        _service.getPayrollConfig(),
        _service.fetchStaffRoster(),
      ]);
      final config = results[0] as PayrollConfig;
      final roster = results[1] as List<StaffRosterItem>;
      setState(() {
        _config = config;
        _roster = roster;
        _isLoading = false;
        // Populate OT controllers from config
        _thresholdController.text = config.overtimeThreshold.toStringAsFixed(
          config.overtimeThreshold == config.overtimeThreshold.roundToDouble() ? 0 : 1,
        );
        _multiplierController.text = config.overtimeMultiplier.toStringAsFixed(1);
        // Pre-fill edits and stable controllers from existing data
        for (final staff in roster) {
          if (staff.externalEmployeeId.isNotEmpty) {
            _editedIds[staff.userKey] = staff.externalEmployeeId;
          }
          if (staff.workerType.isNotEmpty) {
            _editedWorkerTypes[staff.userKey] = staff.workerType;
          }
          _idControllers.putIfAbsent(
            staff.userKey,
            () => TextEditingController(text: staff.externalEmployeeId),
          );
        }
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<StaffRosterItem> get _filteredRoster {
    if (_searchQuery.isEmpty) return _roster;
    final q = _searchQuery.toLowerCase();
    return _roster.where((s) =>
      s.name.toLowerCase().contains(q) ||
      (s.email?.toLowerCase().contains(q) ?? false) ||
      s.roles.any((r) => r.toLowerCase().contains(q))
    ).toList();
  }

  int get _mappedCount {
    return _roster.where((s) {
      final editedId = _editedIds[s.userKey];
      return (editedId != null && editedId.isNotEmpty) || s.isMapped;
    }).length;
  }

  bool get _hasUnsavedChanges {
    for (final staff in _roster) {
      final editedId = _editedIds[staff.userKey] ?? '';
      if (editedId != staff.externalEmployeeId) return true;
      final editedType = _editedWorkerTypes[staff.userKey] ?? 'w2';
      if (editedType != staff.workerType) return true;
    }
    return false;
  }

  // OT settings
  bool _otExpanded = false;
  late TextEditingController _thresholdController;
  late TextEditingController _multiplierController;

  Future<void> _saveProvider(String provider) async {
    try {
      final updated = await _service.savePayrollConfig(
        _config.copyWith(provider: provider),
      );
      setState(() => _config = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save provider: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _saveOvertimeSettings() async {
    final threshold = double.tryParse(_thresholdController.text) ?? 40;
    final multiplier = double.tryParse(_multiplierController.text) ?? 1.5;

    if (threshold < 0 || threshold > 168) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Threshold must be 0–168 hours')),
      );
      return;
    }
    if (multiplier < 1 || multiplier > 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Multiplier must be 1.0–3.0')),
      );
      return;
    }

    try {
      final updated = await _service.savePayrollConfig(
        _config.copyWith(overtimeThreshold: threshold, overtimeMultiplier: multiplier),
      );
      setState(() => _config = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Overtime settings saved'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _saveAll() async {
    // Collect all mappings with non-empty IDs
    final mappings = <StaffPayrollMapping>[];
    for (final staff in _roster) {
      final id = _editedIds[staff.userKey] ?? staff.externalEmployeeId;
      final type = _editedWorkerTypes[staff.userKey] ?? staff.workerType;
      // Include if there's an ID (either new or existing)
      if (id.isNotEmpty) {
        mappings.add(StaffPayrollMapping(
          userKey: staff.userKey,
          externalEmployeeId: id,
          workerType: type.isEmpty ? 'w2' : type,
        ));
      }
    }

    if (mappings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employee IDs to save')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _service.bulkSaveMappings(mappings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved ${mappings.length} mapping(s)'),
            backgroundColor: AppColors.success,
          ),
        );
        // Reload to get fresh data
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Staff Payroll Mapping'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navySpaceCadet,
        iconTheme: const IconThemeData(color: AppColors.navySpaceCadet),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
      bottomNavigationBar: (!_isLoading && _error == null)
          ? _buildSaveBar()
          : null,
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final filtered = _filteredRoster;

    return Column(
      children: [
        // Provider config header
        _buildProviderHeader(),

        // Overtime settings (collapsible)
        _buildOvertimeSettings(),

        // Progress bar
        _buildProgressBar(),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search staff by name or role...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),

        // Roster list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'No staff match "$_searchQuery"'
                        : 'No staff in your roster',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _buildStaffRow(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildProviderHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_outlined, color: AppColors.secondaryPurple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payroll Provider',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  _config.isConfigured ? _config.providerLabel : 'Not configured',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _config.isConfigured
                        ? AppColors.navySpaceCadet
                        : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: _saveProvider,
            initialValue: _config.provider,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'adp', child: Text('ADP Workforce Now')),
              PopupMenuItem(value: 'paychex', child: Text('Paychex Flex')),
              PopupMenuItem(value: 'gusto', child: Text('Gusto')),
              PopupMenuItem(value: 'none', child: Text('None')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Change', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.secondaryPurple,
                  )),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 18, color: AppColors.secondaryPurple),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeSettings() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          // Collapsible header
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _otExpanded = !_otExpanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.timer_outlined, color: Color(0xFFD97706), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Overtime Settings',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                color: AppColors.navySpaceCadet)),
                        Text(
                          'OT after ${_config.overtimeThreshold.toStringAsFixed(0)}h/client at ${_config.overtimeMultiplier}x',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _otExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_otExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _thresholdController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'OT after (hours/client)',
                            labelStyle: const TextStyle(fontSize: 12),
                            hintText: '40',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                            filled: true,
                            fillColor: AppColors.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.borderLight),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.borderLight),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.secondaryPurple),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _multiplierController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'OT rate multiplier',
                            labelStyle: const TextStyle(fontSize: 12),
                            hintText: '1.5',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                            filled: true,
                            fillColor: AppColors.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.borderLight),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.borderLight),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.secondaryPurple),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: _saveOvertimeSettings,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save OT Settings', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondaryPurple,
                        side: const BorderSide(color: AppColors.secondaryPurple),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = _roster.length;
    final mapped = _mappedCount;
    final progress = total > 0 ? mapped / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$mapped of $total staff mapped',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.navySpaceCadet),
              ),
              if (total > 0)
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: progress == 1.0 ? AppColors.success : AppColors.secondaryPurple,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? AppColors.success : AppColors.secondaryPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffRow(StaffRosterItem staff) {
    final currentId = _editedIds[staff.userKey] ?? staff.externalEmployeeId;
    final currentType = _editedWorkerTypes[staff.userKey] ?? staff.workerType;
    final hasMappedId = currentId.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasMappedId ? AppColors.success.withValues(alpha: 0.3) : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Staff info row
          Row(
            children: [
              // Status indicator
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasMappedId ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              // Avatar
              UserAvatar(
                imageUrl: staff.picture,
                fullName: staff.name,
                email: staff.email,
                radius: 20,
              ),
              const SizedBox(width: 12),
              // Name and roles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (staff.roles.isNotEmpty)
                      Text(
                        staff.roles.join(', '),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // W-2 / 1099 toggle
              GestureDetector(
                onTap: () {
                  setState(() {
                    _editedWorkerTypes[staff.userKey] =
                        currentType == 'w2' ? '1099' : 'w2';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: currentType == '1099'
                        ? const Color(0xFFFFF7ED)
                        : AppColors.surfaceBlue,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: currentType == '1099'
                          ? const Color(0xFFFED7AA)
                          : AppColors.borderLight,
                    ),
                  ),
                  child: Text(
                    currentType == '1099' ? '1099' : 'W-2',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: currentType == '1099'
                          ? const Color(0xFF92400E)
                          : AppColors.secondaryPurple,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Employee ID text field
          SizedBox(
            height: 42,
            child: TextField(
              controller: _idControllers.putIfAbsent(
                staff.userKey,
                () => TextEditingController(text: currentId),
              ),
              onChanged: (v) {
                _editedIds[staff.userKey] = v.trim();
                setState(() {}); // Refresh mapped count / indicators
              },
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: _config.employeeIdLabel,
                labelStyle: const TextStyle(fontSize: 12),
                hintText: _config.isConfigured
                    ? 'Enter ${_config.employeeIdLabel}'
                    : 'Select a provider first',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.secondaryPurple),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: hasMappedId
                    ? const Icon(Icons.check_circle, color: AppColors.success, size: 18)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SizedBox(
        height: 50,
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _saveAll,
          icon: _isSaving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined),
          label: Text(
            _isSaving ? 'Saving...' : _hasUnsavedChanges ? 'Save All ($_mappedCount) *' : 'Save All ($_mappedCount)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}
