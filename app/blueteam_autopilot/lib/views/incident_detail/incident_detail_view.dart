import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../api/backend_client.dart';
import '../../api/models/incident_model.dart';
import '../../cubits/incident_detail/incident_detail_cubit.dart';
import '../../cubits/incident_detail/incident_detail_state.dart';
import '../../theme/app_theme.dart';
import '../action_panel/action_panel_view.dart';

class IncidentDetailView extends StatefulWidget {
  final String incidentId;

  const IncidentDetailView({super.key, required this.incidentId});

  @override
  State<IncidentDetailView> createState() => _IncidentDetailViewState();
}

class _IncidentDetailViewState extends State<IncidentDetailView> {
  @override
  void initState() {
    super.initState();
    context.read<IncidentDetailCubit>().load(widget.incidentId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IncidentDetailCubit, IncidentDetailState>(
      builder: (context, state) {
        return switch (state) {
          IncidentDetailInitial() || IncidentDetailLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          IncidentDetailError(:final message) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFEF4444),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(message),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.read<IncidentDetailCubit>().load(
                    widget.incidentId,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          IncidentDetailLoaded(:final detail) => _DetailContent(detail: detail),
        };
      },
    );
  }
}

class _DetailContent extends StatelessWidget {
  final IncidentDetailModel detail;

  const _DetailContent({required this.detail});

  @override
  Widget build(BuildContext context) {
    final incident = detail.incident;
    final report = incident.report;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _DetailHeader(incident: incident),
          const SizedBox(height: 16),

          // Tabs
          DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF334155)),
                    ),
                  ),
                  child: const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.psychology), text: 'AI Summary'),
                      Tab(icon: Icon(Icons.code), text: 'Raw Event'),
                      Tab(icon: Icon(Icons.notifications), text: 'Alerts'),
                    ],
                  ),
                ),
                SizedBox(
                  height: 600,
                  child: TabBarView(
                    children: [
                      _AiSummaryTab(report: report),
                      _RawEventTab(incident: incident),
                      _AlertsTab(report: report),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Panel (recommendations)
          if (detail.recommendations.isNotEmpty) ...[
            Text(
              'Response Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ActionPanelView(
              incidentId: incident.incidentId,
              recommendations: detail.recommendations,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final IncidentModel incident;

  const _DetailHeader({required this.incident});

  @override
  Widget build(BuildContext context) {
    final report = incident.report;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Severity badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.severityColor(
                      report.severity,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    report.severity,
                    style: TextStyle(
                      color: AppTheme.severityColor(report.severity),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.statusColor(
                      incident.status,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    incident.status,
                    style: TextStyle(
                      color: AppTheme.statusColor(incident.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Event ID
                Text(
                  'ID: ${incident.incidentId}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              report.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            // Meta info
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                if (report.affectedAssets.isNotEmpty)
                  _MetaChip(
                    icon: Icons.computer,
                    label: report.affectedAssets.join(', '),
                  ),
                if (report.sourceIps.isNotEmpty)
                  _MetaChip(
                    icon: Icons.language,
                    label: 'Source: ${report.sourceIps.join(', ')}',
                  ),
                if (report.relatedCves.isNotEmpty)
                  _MetaChip(
                    icon: Icons.bug_report,
                    label: report.relatedCves.join(', '),
                  ),
                _MetaChip(
                  icon: Icons.schedule,
                  label: 'Event: ${report.eventId}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: AI Summary
// ---------------------------------------------------------------------------
class _AiSummaryTab extends StatelessWidget {
  final IncidentReportModel report;

  const _AiSummaryTab({required this.report});

  @override
  Widget build(BuildContext context) {
    if (!report.hasAiAnalysis) {
      return const Center(
        child: Text(
          'No AI analysis available for this incident.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Summary (Markdown)
          MarkdownBody(
            data: report.aiSummary,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
              h1: const TextStyle(color: Colors.white, fontSize: 20),
              h2: const TextStyle(color: Colors.white, fontSize: 17),
              strong: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              code: const TextStyle(
                color: Color(0xFFFBBF24),
                backgroundColor: Color(0xFF1E293B),
                fontFamily: 'monospace',
              ),
              codeblockDecoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const Divider(height: 32, color: Color(0xFF334155)),

          // Root Cause
          if (report.rootCause.isNotEmpty) ...[
            const _SectionTitle('Root Cause'),
            const SizedBox(height: 8),
            Text(
              report.rootCause,
              style: const TextStyle(color: Color(0xFFE2E8F0)),
            ),
            const SizedBox(height: 16),
          ],

          // Business Impact
          if (report.businessImpact.isNotEmpty) ...[
            const _SectionTitle('Business Impact'),
            const SizedBox(height: 8),
            Text(
              report.businessImpact,
              style: const TextStyle(color: Color(0xFFE2E8F0)),
            ),
            const SizedBox(height: 16),
          ],

          // Attack Chain
          if (report.attackChain.isNotEmpty) ...[
            const _SectionTitle('Attack Chain'),
            const SizedBox(height: 8),
            ...report.attackChain.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.stage,
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.description,
                        style: const TextStyle(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Compliance Controls
          if (report.complianceControls.isNotEmpty) ...[
            const _SectionTitle('Compliance Controls'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: report.complianceControls
                  .map(
                    (c) => Chip(
                      label: Text(c),
                      backgroundColor: const Color(0xFF0F172A),
                      labelStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Raw Event
// ---------------------------------------------------------------------------
class _RawEventTab extends StatelessWidget {
  final IncidentModel incident;

  const _RawEventTab({required this.incident});

  @override
  Widget build(BuildContext context) {
    final json = {
      'incidentId': incident.incidentId,
      'accountId': incident.accountId,
      'status': incident.status,
      'createdAt': incident.createdAt,
      'updatedAt': incident.updatedAt,
      'report': {
        'eventId': incident.report.eventId,
        'title': incident.report.title,
        'severity': incident.report.severity,
        'aiSummary': incident.report.aiSummary,
        'rootCause': incident.report.rootCause,
        'businessImpact': incident.report.businessImpact,
        'attackChain': incident.report.attackChain
            .map((e) => {'stage': e.stage, 'description': e.description})
            .toList(),
        'affectedAssets': incident.report.affectedAssets,
        'sourceIps': incident.report.sourceIps,
        'relatedCves': incident.report.relatedCves,
        'complianceControls': incident.report.complianceControls,
        'generatedAt': incident.report.generatedAt,
      },
    };

    final prettyJson = const JsonEncoder.withIndent('  ').convert(json);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: SelectableText(
          prettyJson,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFF22C55E),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Alerts
// ---------------------------------------------------------------------------
class _AlertsTab extends StatelessWidget {
  final IncidentReportModel report;

  const _AlertsTab({required this.report});

  @override
  Widget build(BuildContext context) {
    // The backend doesn't expose raw alerts directly yet.
    // Show a summary based on the incident report data grouped by source.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alert Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Source info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Source: ${_deriveSource(report)}',
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Event ID: ${report.eventId}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  if (report.sourceIps.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Source IPs: ${report.sourceIps.join(', ')}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Affected assets
          if (report.affectedAssets.isNotEmpty) ...[
            const Text(
              'Affected Assets',
              style: TextStyle(
                color: Color(0xFFE2E8F0),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...report.affectedAssets.map(
              (asset) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.computer,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      asset,
                      style: const TextStyle(color: Color(0xFFE2E8F0)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Related CVEs
          if (report.relatedCves.isNotEmpty) ...[
            const Text(
              'Related CVEs',
              style: TextStyle(
                color: Color(0xFFE2E8F0),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...report.relatedCves.map(
              (cve) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bug_report,
                      size: 16,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Text(cve, style: const TextStyle(color: Color(0xFFE2E8F0))),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Text(
            'Detailed alert data from Cloud SIEM and Security Center will be '
            'available when connected to a live Alibaba Cloud environment.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _deriveSource(IncidentReportModel report) {
    final title = report.title.toLowerCase();
    if (title.contains('waf')) return 'WAF';
    if (title.contains('cwpp') || title.contains('host')) return 'CWPP';
    if (title.contains('siem')) return 'Cloud SIEM';
    return 'Security Center';
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------
class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
