import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nexa/l10n/app_localizations.dart';
import 'package:nexa/services/terminology_provider.dart';
import '../../../../core/widgets/custom_sliver_app_bar.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../brand/presentation/widgets/brand_customization_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Terminology management
  String? _selectedTerminology;

  @override
  void initState() {
    super.initState();
    // Load current terminology after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedTerminology = context.read<TerminologyProvider>().terminology;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          CustomSliverAppBar(
            title: l10n.settings,
            subtitle: l10n.manageYourPreferences,
            onBackPressed: () => Navigator.of(context).pop(),
            expandedHeight: 120.0,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Terminology Section
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Consumer<TerminologyProvider>(
                      builder: (context, terminologyProvider, _) {
                        // Initialize selected terminology if not set
                        _selectedTerminology ??= terminologyProvider.terminology;

                        final bool hasChanges = _selectedTerminology != terminologyProvider.terminology;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.work_outline,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  l10n.workTerminology,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.howPreferWorkAssignments,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            RadioListTile<String>(
                              title: Text(l10n.jobs),
                              subtitle: Text(l10n.jobsExample),
                              value: 'Jobs',
                              groupValue: _selectedTerminology,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedTerminology = value;
                                  });
                                }
                              },
                            ),
                            RadioListTile<String>(
                              title: Text(l10n.shifts),
                              subtitle: Text(l10n.shiftsExample),
                              value: 'Shifts',
                              groupValue: _selectedTerminology,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedTerminology = value;
                                  });
                                }
                              },
                            ),
                            RadioListTile<String>(
                              title: Text(l10n.events),
                              subtitle: Text(l10n.eventsExample),
                              value: 'Events',
                              groupValue: _selectedTerminology,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedTerminology = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: hasChanges
                                    ? () async {
                                        await terminologyProvider.setTerminology(_selectedTerminology!);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                                            SnackBar(
                                              content: Text(l10n.terminologyUpdatedSuccess),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                icon: const Icon(Icons.check),
                                label: Text(l10n.saveTerminology),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.terminologyUpdateInfo,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Brand Customization Section
                const BrandCustomizationCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
