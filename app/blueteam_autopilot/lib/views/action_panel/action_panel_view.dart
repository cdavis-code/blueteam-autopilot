import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/models/recommendation_model.dart';
import '../../cubits/action_panel/action_panel_cubit.dart';
import '../../cubits/action_panel/action_panel_state.dart';
import '../../theme/app_theme.dart';

/// Displays recommendation cards with approve/reject/execute actions.
class ActionPanelView extends StatelessWidget {
  final String incidentId;
  final List<RecommendationModel> recommendations;

  const ActionPanelView({
    super.key,
    required this.incidentId,
    required this.recommendations,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: recommendations
          .map(
            (rec) => _RecommendationCard(
              recommendation: rec,
              incidentId: incidentId,
            ),
          )
          .toList(),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final RecommendationModel recommendation;
  final String incidentId;

  const _RecommendationCard({
    required this.recommendation,
    required this.incidentId,
  });

  @override
  Widget build(BuildContext context) {
    final proposal = recommendation.proposal;
    final recId = recommendation.recommendationId;

    return BlocBuilder<ActionPanelCubit, ActionPanelState>(
      builder: (context, actionState) {
        final isOperating =
            actionState is ActionPanelOperating &&
            actionState.recommendationId == recId;

        // Derive effective status from action result
        String effectiveStatus = recommendation.status;
        if (actionState is ActionPanelSuccess &&
            actionState.recommendationId == recId) {
          effectiveStatus = actionState.newStatus;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: status + risk
                Row(
                  children: [
                    _StatusBadge(status: effectiveStatus),
                    const SizedBox(width: 8),
                    _RiskBadge(risk: proposal.riskLevel),
                    const Spacer(),
                    if (proposal.requiresApproval)
                      const Chip(
                        label: Text('Human Approval Required'),
                        backgroundColor: Color(0x15FBBF24),
                        labelStyle: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Reasoning
                Text(
                  proposal.reasoning,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Details grid
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _DetailField(
                      label: 'Policy ID',
                      value: proposal.recommendedPolicyId,
                    ),
                    _DetailField(
                      label: 'Expected Effects',
                      value: proposal.expectedEffects,
                    ),
                    _DetailField(
                      label: 'Rollback Plan',
                      value: proposal.rollbackPlan,
                    ),
                  ],
                ),

                // Compliance controls
                if (proposal.complianceControls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: proposal.complianceControls
                        .map(
                          (c) => Text(
                            c,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],

                // Trusted network warning
                if (proposal.trustedNetworkMatch) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Color(0xFFEF4444), size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Source IP matched a trusted network. Verify before proceeding.',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Execution log
                if (actionState is ActionPanelSuccess &&
                    actionState.recommendationId == recId &&
                    actionState.executionLog != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      actionState.executionLog!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                  ),
                ],

                // Error message
                if (actionState is ActionPanelError &&
                    actionState.recommendationId == recId) ...[
                  const SizedBox(height: 8),
                  Text(
                    actionState.message,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                    ),
                  ),
                ],

                // Action buttons (only show for PENDING or APPROVED status)
                if (effectiveStatus == 'PENDING' ||
                    effectiveStatus == 'APPROVED') ...[
                  const SizedBox(height: 16),
                  _ActionButtons(
                    incidentId: incidentId,
                    recId: recId,
                    status: effectiveStatus,
                    isOperating: isOperating,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final String incidentId;
  final String recId;
  final String status;
  final bool isOperating;

  const _ActionButtons({
    required this.incidentId,
    required this.recId,
    required this.status,
    required this.isOperating,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ActionPanelCubit>();

    return Row(
      children: [
        if (status == 'PENDING') ...[
          FilledButton.icon(
            onPressed: isOperating
                ? null
                : () => cubit.approve(incidentId, recId),
            icon: isOperating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Approve'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: isOperating
                ? null
                : () => cubit.reject(incidentId, recId),
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
            ),
          ),
        ],
        if (status == 'APPROVED') ...[
          FilledButton.icon(
            onPressed: isOperating
                ? null
                : () => cubit.execute(incidentId, recId),
            icon: isOperating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: const Text('Apply Recommended Response'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: isOperating
                ? null
                : () => cubit.execute(incidentId, recId, dryRun: true),
            icon: const Icon(Icons.science),
            label: const Text('Dry Run'),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Small widgets
// ---------------------------------------------------------------------------
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.recommendationStatusColor(
          status,
        ).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: AppTheme.recommendationStatusColor(status),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String risk;

  const _RiskBadge({required this.risk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.riskColor(risk).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Risk: $risk',
        style: TextStyle(
          color: AppTheme.riskColor(risk),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;

  const _DetailField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isNotEmpty ? value : '—',
          style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
        ),
      ],
    );
  }
}
