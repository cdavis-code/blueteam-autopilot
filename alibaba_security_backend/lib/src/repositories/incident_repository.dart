import 'dart:convert';

import 'package:alibaba_security_agent/alibaba_security_agent.dart';
import 'package:ulid/ulid.dart';

import '../config/backend_config.dart';
import '../tablestore/tablestore_client.dart';

/// Stored incident record combining the [IncidentReport] with metadata.
class StoredIncident {
  final String incidentId;
  final String accountId;
  final IncidentReport report;
  final String status; // OPEN, INVESTIGATING, RESOLVED, DISMISSED
  final int createdAt;
  final int updatedAt;

  const StoredIncident({
    required this.incidentId,
    required this.accountId,
    required this.report,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'incidentId': incidentId,
        'accountId': accountId,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'report': report.toJson(),
      };
}

/// Repository for persisting and querying incidents.
///
/// Uses TableStore when configured, falls back to in-memory storage.
class IncidentRepository {
  final TableStoreClient? _client;
  final String _table;
  final String _accountId;

  /// In-memory fallback storage (used when TableStore is not configured).
  final List<StoredIncident> _memoryStore = [];

  IncidentRepository({
    TableStoreClient? client,
    required BackendConfig config,
    String accountId = 'default',
  }) : _client = client,
       _table = config.incidentsTable,
       _accountId = accountId;

  /// Whether this repository uses persistent TableStore storage.
  bool get isPersistent => _client != null;

  /// Create a new incident from an [IncidentReport].
  ///
  /// Returns the generated incident ID (ULID).
  Future<String> create(IncidentReport report) async {
    final incidentId = Ulid().toString();
    final now = DateTime.now().millisecondsSinceEpoch;

    final stored = StoredIncident(
      incidentId: incidentId,
      accountId: _accountId,
      report: report,
      status: 'OPEN',
      createdAt: now,
      updatedAt: now,
    );

    if (_client != null) {
      await _client.putRow(_table, {
        'account_id': _accountId,
        'incident_id': incidentId,
      }, {
        'event_id': report.eventId,
        'title': report.title,
        'severity': report.severity,
        'status': 'OPEN',
        'ai_summary': report.aiSummary,
        'root_cause': report.rootCause,
        'business_impact': report.businessImpact,
        'attack_chain': json.encode(report.attackChain.map((e) => e.toJson()).toList()),
        'affected_assets': json.encode(report.affectedAssets),
        'source_ips': json.encode(report.sourceIps),
        'related_cves': json.encode(report.relatedCves),
        'compliance_controls': json.encode(report.complianceControls),
        'raw_report_json': json.encode(report.toJson()),
        'created_at': now,
        'updated_at': now,
      });
    } else {
      _memoryStore.add(stored);
    }

    return incidentId;
  }

  /// Get an incident by its ID.
  Future<StoredIncident?> getById(String incidentId) async {
    if (_client != null) {
      final row = await _client.getRow(_table, {
        'account_id': _accountId,
        'incident_id': incidentId,
      });
      if (row == null) return null;
      return _rowToStoredIncident(row);
    }

    try {
      return _memoryStore.firstWhere((i) => i.incidentId == incidentId);
    } catch (_) {
      return null;
    }
  }

  /// Check if an incident already exists for a given event ID.
  Future<StoredIncident?> findByEventId(String eventId) async {
    if (_client != null) {
      // TableStore doesn't support non-PK queries without a secondary index.
      // For hackathon simplicity, return null and let the caller handle
      // deduplication via the event ID.
      return null;
    }

    try {
      return _memoryStore.firstWhere((i) => i.report.eventId == eventId);
    } catch (_) {
      return null;
    }
  }

  /// List incidents with optional filters.
  ///
  /// Returns newest-first (sorted by [createdAt] descending).
  Future<List<StoredIncident>> list({
    String? severity,
    String? status,
    int limit = 50,
  }) async {
    List<StoredIncident> results;

    if (_client != null) {
      // TableStore range query: scan all rows for this account
      final rows = await _client.getRange(
        _table,
        startKey: {'account_id': _accountId, 'incident_id': '\xFF'},
        endKey: {'account_id': _accountId, 'incident_id': ''},
        limit: limit,
      );
      results = rows.map(_rowToStoredIncident).toList();
    } else {
      results = List.from(_memoryStore.reversed);
    }

    // Apply filters
    if (severity != null) {
      results = results
          .where((i) => i.report.severity.toUpperCase() == severity.toUpperCase())
          .toList();
    }
    if (status != null) {
      results = results
          .where((i) => i.status.toUpperCase() == status.toUpperCase())
          .toList();
    }

    return results.take(limit).toList();
  }

  /// Update the status of an incident.
  Future<void> updateStatus(String incidentId, String status) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_client != null) {
      await _client.updateRow(
        _table,
        {'account_id': _accountId, 'incident_id': incidentId},
        {'status': status, 'updated_at': now},
      );
    } else {
      final idx = _memoryStore.indexWhere((i) => i.incidentId == incidentId);
      if (idx >= 0) {
        final old = _memoryStore[idx];
        _memoryStore[idx] = StoredIncident(
          incidentId: old.incidentId,
          accountId: old.accountId,
          report: old.report,
          status: status,
          createdAt: old.createdAt,
          updatedAt: now,
        );
      }
    }
  }

  StoredIncident _rowToStoredIncident(Map<String, dynamic> row) {
    final rawJson = row['raw_report_json'] as String?;
    final IncidentReport report;
    if (rawJson != null) {
      report = IncidentReport.fromJson(
        json.decode(rawJson) as Map<String, dynamic>,
      );
    } else {
      report = IncidentReport(
        eventId: row['event_id']?.toString() ?? '',
        title: row['title']?.toString() ?? 'Unknown',
        severity: row['severity']?.toString() ?? 'MEDIUM',
        aiSummary: row['ai_summary']?.toString() ?? '',
        rootCause: row['root_cause']?.toString() ?? '',
        businessImpact: row['business_impact']?.toString() ?? '',
      );
    }

    return StoredIncident(
      incidentId: row['incident_id']?.toString() ?? '',
      accountId: row['account_id']?.toString() ?? _accountId,
      report: report,
      status: row['status']?.toString() ?? 'OPEN',
      createdAt: (row['created_at'] as int?) ?? 0,
      updatedAt: (row['updated_at'] as int?) ?? 0,
    );
  }
}
