import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../api/models/incident_model.dart';
import '../../cubits/incident_list/incident_list_cubit.dart';
import '../../cubits/incident_list/incident_list_state.dart';
import '../../theme/app_theme.dart';

class IncidentListView extends StatefulWidget {
  const IncidentListView({super.key});

  @override
  State<IncidentListView> createState() => _IncidentListViewState();
}

class _IncidentListViewState extends State<IncidentListView> {
  @override
  void initState() {
    super.initState();
    context.read<IncidentListCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IncidentListCubit, IncidentListState>(
      builder: (context, state) {
        return switch (state) {
          IncidentListInitial() || IncidentListLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          IncidentListError(:final message) => _ErrorView(
            message: message,
            onRetry: () => context.read<IncidentListCubit>().load(),
          ),
          IncidentListLoaded() => _LoadedView(state: state),
        };
      },
    );
  }
}

class _LoadedView extends StatelessWidget {
  final IncidentListLoaded state;

  const _LoadedView({required this.state});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<IncidentListCubit>().refresh(),
      child: Column(
        children: [
          _FilterBar(
            severityFilter: state.severityFilter,
            statusFilter: state.statusFilter,
          ),
          Expanded(
            child: state.incidents.isEmpty
                ? const Center(
                    child: Text(
                      'No incidents found',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: _IncidentTable(incidents: state.incidents),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? severityFilter;
  final String? statusFilter;

  const _FilterBar({this.severityFilter, this.statusFilter});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<IncidentListCubit>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Severity filter
          DropdownButton<String?>(
            value: severityFilter,
            hint: const Text('Severity'),
            dropdownColor: const Color(0xFF1E293B),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All Severities'),
              ),
              for (final s in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'])
                DropdownMenuItem(
                  value: s,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppTheme.severityColor(s),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(s),
                    ],
                  ),
                ),
            ],
            onChanged: cubit.setSeverityFilter,
          ),
          const SizedBox(width: 16),

          // Status filter
          DropdownButton<String?>(
            value: statusFilter,
            hint: const Text('Status'),
            dropdownColor: const Color(0xFF1E293B),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Statuses')),
              for (final s in [
                'OPEN',
                'INVESTIGATING',
                'RESOLVED',
                'DISMISSED',
              ])
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: cubit.setStatusFilter,
          ),
          const Spacer(),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
            onPressed: cubit.refresh,
          ),
        ],
      ),
    );
  }
}

class _IncidentTable extends StatelessWidget {
  final List<IncidentModel> incidents;

  const _IncidentTable({required this.incidents});

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Severity')),
        DataColumn(label: Text('Title')),
        DataColumn(label: Text('Asset')),
        DataColumn(label: Text('Source')),
        DataColumn(label: Text('Time')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('AI'), numeric: true),
      ],
      rows: incidents.map((inc) {
        final report = inc.report;
        return DataRow(
          onSelectChanged: (_) => context.push('/incidents/${inc.incidentId}'),
          cells: [
            // Severity chip
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.severityColor(
                    report.severity,
                  ).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  report.severity,
                  style: TextStyle(
                    color: AppTheme.severityColor(report.severity),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Title
            DataCell(
              Text(
                report.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),

            // Asset
            DataCell(
              Text(
                report.affectedAssets.isNotEmpty
                    ? report.affectedAssets.first
                    : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Source (derive from eventId or title)
            DataCell(Text(_deriveSource(report))),

            // Time
            DataCell(Text(_formatTime(inc.createdAt))),

            // Status chip
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.statusColor(
                    inc.status,
                  ).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  inc.status,
                  style: TextStyle(
                    color: AppTheme.statusColor(inc.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // AI analyzed flag
            DataCell(
              Icon(
                report.hasAiAnalysis
                    ? Icons.psychology
                    : Icons.psychology_outlined,
                size: 18,
                color: report.hasAiAnalysis
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _deriveSource(IncidentReportModel report) {
    final title = report.title.toLowerCase();
    if (title.contains('waf')) return 'WAF';
    if (title.contains('cwpp') || title.contains('host')) return 'CWPP';
    if (title.contains('siem')) return 'SIEM';
    return 'Security Center';
  }

  String _formatTime(int epochMs) {
    if (epochMs == 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to load incidents',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
