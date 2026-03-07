import 'package:flutter/material.dart';
import 'package:nexa/shared/constants/skill_cert_catalogs.dart';
import 'package:nexa/shared/presentation/theme/app_colors.dart';

/// Result returned by [showRoleRequirementsPicker].
class RoleRequirementsResult {
  final List<String> skills;
  final List<String> certifications;

  const RoleRequirementsResult({required this.skills, required this.certifications});
}

/// Shows a bottom sheet to pick required skills and certifications for an event role.
/// Returns the selected items, or null if dismissed.
Future<RoleRequirementsResult?> showRoleRequirementsPicker({
  required BuildContext context,
  required String roleName,
  List<String> initialSkills = const [],
  List<String> initialCerts = const [],
}) {
  return showModalBottomSheet<RoleRequirementsResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RoleRequirementsSheet(
      roleName: roleName,
      initialSkills: initialSkills,
      initialCerts: initialCerts,
    ),
  );
}

class _RoleRequirementsSheet extends StatefulWidget {
  final String roleName;
  final List<String> initialSkills;
  final List<String> initialCerts;

  const _RoleRequirementsSheet({
    required this.roleName,
    required this.initialSkills,
    required this.initialCerts,
  });

  @override
  State<_RoleRequirementsSheet> createState() => _RoleRequirementsSheetState();
}

class _RoleRequirementsSheetState extends State<_RoleRequirementsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _selectedSkills = <String>{};
  final _selectedCerts = <String>{};
  var _searchQuery = '';
  var _activeCategory = 'All';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _selectedSkills.addAll(widget.initialSkills.map((s) => s.toLowerCase()));
    _selectedCerts.addAll(widget.initialCerts.map((s) => s.toLowerCase()));
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {
          _searchQuery = '';
          _activeCategory = 'All';
        });
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _selectedSkills.length + _selectedCerts.length;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Requirements: ${widget.roleName}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: _tabCtrl.index == 0 ? 'Search skills...' : 'Search certifications...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true, fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Tab bar
          TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.techBlue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.techBlue,
            tabs: [
              Tab(text: 'Skills${_selectedSkills.isNotEmpty ? ' (${_selectedSkills.length})' : ''}'),
              Tab(text: 'Certifications${_selectedCerts.isNotEmpty ? ' (${_selectedCerts.length})' : ''}'),
            ],
          ),
          // Category chips
          _buildCategoryChips(),
          const SizedBox(height: 4),
          // Content
          Flexible(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildCatalogList(skillCategories, _selectedSkills),
                _buildCatalogList(certCategories, _selectedCerts),
              ],
            ),
          ),
          // Done button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    // Convert back to original case from catalog
                    final allSkills = skillCategories.values.expand((v) => v.$2).toList();
                    final allCerts = certCategories.values.expand((v) => v.$2).toList();

                    final skills = _selectedSkills
                        .map((s) => allSkills.firstWhere((sk) => sk.toLowerCase() == s, orElse: () => s))
                        .toList();
                    final certs = _selectedCerts
                        .map((c) => allCerts.firstWhere((ct) => ct.toLowerCase() == c, orElse: () => c))
                        .toList();

                    Navigator.pop(context, RoleRequirementsResult(skills: skills, certifications: certs));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.techBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    totalCount > 0 ? 'Done ($totalCount selected)' : 'Done',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = _tabCtrl.index == 0 ? skillCategories : certCategories;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: _activeCategory == 'All',
              selectedColor: AppColors.techBlue.withValues(alpha: 0.15),
              onSelected: (_) => setState(() => _activeCategory = 'All'),
              visualDensity: VisualDensity.compact,
            ),
          ),
          ...categories.entries.map((cat) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(cat.value.$1, size: 16),
              label: Text(cat.key),
              selected: _activeCategory == cat.key,
              selectedColor: AppColors.techBlue.withValues(alpha: 0.15),
              onSelected: (_) => setState(() => _activeCategory = cat.key),
              visualDensity: VisualDensity.compact,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCatalogList(
    Map<String, (IconData, List<String>)> catalog,
    Set<String> selected,
  ) {
    final entries = <MapEntry<String, List<String>>>[];
    for (final cat in catalog.entries) {
      final filtered = cat.value.$2.where((item) {
        if (_activeCategory != 'All' && cat.key != _activeCategory) return false;
        if (_searchQuery.isNotEmpty) return item.toLowerCase().contains(_searchQuery.toLowerCase());
        return true;
      }).toList();
      if (filtered.isNotEmpty) entries.add(MapEntry(cat.key, filtered));
    }

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No items match "$_searchQuery"',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: entries.expand((entry) => [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(entry.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        ),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: entry.value.map((item) {
            final isSelected = selected.contains(item.toLowerCase());
            return FilterChip(
              label: Text(item, style: const TextStyle(fontSize: 13)),
              selected: isSelected,
              selectedColor: AppColors.techBlue.withValues(alpha: 0.15),
              checkmarkColor: AppColors.techBlue,
              onSelected: (val) => setState(() {
                val ? selected.add(item.toLowerCase()) : selected.remove(item.toLowerCase());
              }),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.grey.shade200),
            );
          }).toList(),
        ),
      ]).toList(),
    );
  }
}
