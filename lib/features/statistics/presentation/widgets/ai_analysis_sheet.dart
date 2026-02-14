import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../brand/data/providers/brand_provider.dart';
import '../../data/models/statistics_models.dart';
import '../../data/services/statistics_service.dart';

/// Shared bottom sheet that fetches and displays AI analysis of stats data.
class AIAnalysisSheet extends StatefulWidget {
  const AIAnalysisSheet({
    super.key,
    required this.statistics,
    required this.payroll,
    required this.topPerformers,
  });

  final ManagerStatistics statistics;
  final PayrollReport payroll;
  final TopPerformersReport topPerformers;

  @override
  State<AIAnalysisSheet> createState() => _AIAnalysisSheetState();
}

class _AIAnalysisSheetState extends State<AIAnalysisSheet> {
  bool _loading = true;
  bool _generating = false;
  String? _analysis;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAnalysis();
  }

  Future<void> _fetchAnalysis() async {
    try {
      final result = await StatisticsService.getAIAnalysis(
        statistics: widget.statistics,
        payroll: widget.payroll,
        topPerformers: widget.topPerformers,
      );
      if (mounted) {
        setState(() {
          _analysis = result;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[AIAnalysis] Error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _downloadDoc(String format) async {
    if (_analysis == null) return;
    setState(() => _generating = true);

    String? templateDesign;
    try {
      templateDesign = context.read<BrandProvider>().preferredDocDesign;
    } catch (_) {}

    try {
      final url = await StatisticsService.generateAnalysisDoc(
        analysis: _analysis!,
        statistics: widget.statistics,
        format: format,
        templateDesign: templateDesign,
      );

      if (mounted) {
        setState(() => _generating = false);
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('[AIAnalysis] Doc generation error: $e');
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/ai_assistant_logo.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212C4A),
                        ),
                      ),
                      Text(
                        widget.statistics.period.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_analysis != null && !_generating)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.download_rounded, color: Color(0xFF212C4A)),
                    tooltip: 'Download report',
                    onSelected: _downloadDoc,
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'pdf',
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Download PDF'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'docx',
                        child: Row(
                          children: [
                            Icon(Icons.description, size: 18, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Download Word'),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (_generating)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF212C4A),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Analyzing your data...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _loading = true;
                                    _error = null;
                                  });
                                  _fetchAnalysis();
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Markdown(
                        data: _analysis ?? '',
                        padding: const EdgeInsets.all(20),
                        styleSheet: MarkdownStyleSheet(
                          h1: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212C4A),
                          ),
                          h2: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF212C4A),
                          ),
                          h3: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                          p: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF374151),
                          ),
                          listBullet: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF374151),
                          ),
                          strong: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212C4A),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
