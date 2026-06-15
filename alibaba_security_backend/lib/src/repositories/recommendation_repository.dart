import 'dart:convert';

import 'package:alibaba_security_agent/alibaba_security_agent.dart';
import 'package:ulid/ulid.dart';

import '../config/backend_config.dart';
import '../tablestore/tablestore_client.dart';

/// Stored recommendation record linking an [ActionProposal] to an incident.
class StoredRecommendation {
  final String recommendationId;
  final String accountId;
  final String incidentId;
  final ActionProposal proposal;
  final String status; // PENDING, APPROVED, REJECTED, APPLIED, FAILED
  final String? executionLog;
  final int createdAt;

  const StoredRecommendation({
    required this.recommendationId,
    required this.accountId,
    required this.incidentId,
    required this.proposal,
    required this.status,
    this.executionLog,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'recommendationId': recommendationId,
        'incidentId': incidentId,
        'status': status,
        'executionLog': executionLog,
        'createdAt': createdAt,
        'proposal': proposal.toJson(),
      };
}

/// Repository for persisting and querying action recommendations.
///
/// Uses TableStore when configured, falls back to in-memory storage.
class RecommendationRepository {
  final TableStoreClient? _client;
  final String _table;
  final String _accountId;

  /// In-memory fallback storage.
  final List<StoredRecommendation> _memoryStore = [];

  RecommendationRepository({
    TableStoreClient? client,
    required BackendConfig config,
    String accountId = 'default',
  }) : _client = client,
       _table = config.recommendationsTable,
       _accountId = accountId;

  /// Whether this repository uses persistent TableStore storage.
  bool get isPersistent => _client != null;

  /// Create a recommendation from an [ActionProposal].
  ///
  /// Returns the generated recommendation ID (ULID).
  Future<String> create(ActionProposal proposal, String incidentId) async {
    final recommendationId = Ulid().toString();
    final now = DateTime.now().millisecondsSinceEpoch;

    final stored = StoredRecommendation(
      recommendationId: recommendationId,
      accountId: _accountId,
      incidentId: incidentId,
      proposal: proposal,
      status: 'PENDING',
      createdAt: now,
    );

    if (_client != null) {
      await _client.putRow(_table, {
        'account_id': _accountId,
        'recommendation_id': recommendationId,
      }, {
        'incident_id': incidentId,
        'reasoning': proposal.reasoning,
        'recommended_policy_id': proposal.recommendedPolicyId,
        'expected_effects': proposal.expectedEffects,
        'rollback_plan': proposal.rollbackPlan,
        'risk_level': proposal.riskLevel,
        'requires_approval': proposal.requiresApproval,
        'status': 'PENDING',
        'raw_proposal_json': json.encode(proposal.toJson()),
        'created_at': now,
      });
    } else {
      _memoryStore.add(stored);
    }

    return recommendationId;
  }

  /// Get a recommendation by its ID.
  Future<StoredRecommendation?> getById(String recommendationId) async {
    if (_client != null) {
      final row = await _client.getRow(_table, {
        'account_id': _accountId,
        'recommendation_id': recommendationId,
      });
      if (row == null) return null;
      return _rowToStoredRecommendation(row);
    }

    try {
      return _memoryStore.firstWhere(
        (r) => r.recommendationId == recommendationId,
      );
    } catch (_) {
      return null;
    }
  }

  /// List all recommendations for a given incident.
  Future<List<StoredRecommendation>> listForIncident(String incidentId) async {
    List<StoredRecommendation> results;

    if (_client != null) {
      final rows = await _client.getRange(
        _table,
        startKey: {'account_id': _accountId, 'recommendation_id': '\xFF'},
        endKey: {'account_id': _accountId, 'recommendation_id': ''},
        limit: 100,
      );
      results = rows
          .map(_rowToStoredRecommendation)
          .where((r) => r.incidentId == incidentId)
          .toList();
    } else {
      results = _memoryStore
          .where((r) => r.incidentId == incidentId)
          .toList();
    }

    return results;
  }

  /// Update the status of a recommendation.
  ///
  /// [executionLog] can be set when status transitions to APPLIED or FAILED.
  Future<void> updateStatus(
    String recommendationId,
    String status, {
    String? executionLog,
  }) async {
    if (_client != null) {
      final columns = <String, dynamic>{'status': status};
      if (executionLog != null) {
        columns['execution_log'] = executionLog;
      }
      await _client.updateRow(
        _table,
        {'account_id': _accountId, 'recommendation_id': recommendationId},
        columns,
      );
    } else {
      final idx = _memoryStore.indexWhere(
        (r) => r.recommendationId == recommendationId,
      );
      if (idx >= 0) {
        final old = _memoryStore[idx];
        _memoryStore[idx] = StoredRecommendation(
          recommendationId: old.recommendationId,
          accountId: old.accountId,
          incidentId: old.incidentId,
          proposal: old.proposal,
          status: status,
          executionLog: executionLog ?? old.executionLog,
          createdAt: old.createdAt,
        );
      }
    }
  }

  StoredRecommendation _rowToStoredRecommendation(Map<String, dynamic> row) {
    final rawJson = row['raw_proposal_json'] as String?;
    final ActionProposal proposal;
    if (rawJson != null) {
      proposal = ActionProposal.fromJson(
        json.decode(rawJson) as Map<String, dynamic>,
      );
    } else {
      proposal = ActionProposal(
        reasoning: row['reasoning']?.toString() ?? '',
        recommendedPolicyId: row['recommended_policy_id']?.toString() ?? '',
        expectedEffects: row['expected_effects']?.toString() ?? '',
        rollbackPlan: row['rollback_plan']?.toString() ?? '',
        riskLevel: row['risk_level']?.toString() ?? 'MEDIUM',
      );
    }

    return StoredRecommendation(
      recommendationId: row['recommendation_id']?.toString() ?? '',
      accountId: row['account_id']?.toString() ?? _accountId,
      incidentId: row['incident_id']?.toString() ?? '',
      proposal: proposal,
      status: row['status']?.toString() ?? 'PENDING',
      executionLog: row['execution_log']?.toString(),
      createdAt: (row['created_at'] as int?) ?? 0,
    );
  }
}
