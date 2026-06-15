import '../client/alibaba_api_client.dart';
import '../enums.dart';
import '../models/error_envelope.dart';
import '../models/response_policy.dart';

/// Wraps Alibaba Cloud SIEM (2022-06-16) APIs.
///
/// Provides methods for listing and executing response policies from
/// Agentic SOC automation / playbook capabilities.
class CloudSiemService {
  final AlibabaApiClient _client;

  CloudSiemService(this._client);

  /// List response policies (automated response rules) from Cloud SIEM.
  ///
  /// Maps to the `ListAutomateResponseConfigs` API.
  /// [scope] filters by policy scope (WAF or ALL).
  Future<List<ResponsePolicy>> listResponsePolicies({
    PolicyScope scope = PolicyScope.all,
  }) async {
    final params = <String, String>{'PageSize': '50', 'PageNumber': '1'};

    if (scope == PolicyScope.waf) {
      params['ProductCode'] = 'waf';
    }

    final Map<String, dynamic> response;
    try {
      response = await _client.callSiemApi(
        'ListAutomateResponseConfigs',
        params: params,
      );
    } on AlibabaApiError catch (e) {
      // Cloud SIEM (Threat Analysis) requires Security Center Enterprise+.
      if (e.error.message.contains('InvalidAction.NotFound') ||
          e.error.message.contains('InvalidVersion')) {
        throw AlibabaApiError.api(
          message:
              'Cloud SIEM (Threat Analysis) is not available. '
              'It requires Security Center Enterprise edition or higher. '
              'Original error: ${e.error.message}',
          httpStatus: e.error.details?.httpStatus,
          api: 'ListAutomateResponseConfigs',
          requestId: e.error.details?.requestId,
        );
      }
      rethrow;
    }

    final data = response['Data'] as Map<String, dynamic>? ?? {};
    final policyList =
        data['AutomateResponseConfigs'] as List<dynamic>? ??
        data['ResponsePolicies'] as List<dynamic>? ??
        [];

    return policyList.map((item) {
      final map = item as Map<String, dynamic>;
      return ResponsePolicy(
        policyId:
            map['ConfigId']?.toString() ?? map['RuleId']?.toString() ?? '',
        name:
            map['ConfigName']?.toString() ??
            map['RuleName']?.toString() ??
            'Unknown Policy',
        description: map['Description']?.toString(),
        triggerType:
            map['TriggerType']?.toString() ?? map['ConditionType']?.toString(),
        actionType:
            map['ActionType']?.toString() ?? map['PlaybookName']?.toString(),
        isEnabled:
            map['Status']?.toString() == 'ENABLED' ||
            map['Status']?.toString() == '1' ||
            map['Enabled'] == true,
      );
    }).toList();
  }

  /// Execute a response policy against an event or IP list.
  ///
  /// In **dry-run mode**, no actual API call is made. Instead a simulated
  /// response describing what *would* happen is returned.
  ///
  /// In **real mode**, the Cloud SIEM `PostAutomateResponseConfig` API is
  /// called to trigger the policy.
  Future<ExecuteResponseResult> executeResponsePolicy({
    required String policyId,
    String? eventId,
    bool? dryRun,
  }) async {
    final effectiveDryRun = dryRun ?? _client.isDryRun;

    if (effectiveDryRun) {
      return ExecuteResponseResult(
        policyId: policyId,
        eventId: eventId,
        mode: 'dry-run',
        result:
            '[DRY-RUN] Would execute response policy "$policyId"'
            '${eventId != null ? ' for event "$eventId"' : ''}. '
            'No state-changing API call was made.',
        raw: {'simulated': true, 'policyId': policyId, 'eventId': eventId},
      );
    }

    // Real execution: enable the automated response config.
    final params = <String, String>{'ConfigId': policyId, 'Status': 'ENABLED'};
    if (eventId != null) {
      params['EventId'] = eventId;
    }

    final Map<String, dynamic> response;
    try {
      response = await _client.callSiemApi(
        'UpdateAutomateResponseConfigStatus',
        params: params,
      );
    } on AlibabaApiError catch (e) {
      if (e.error.message.contains('InvalidAction.NotFound') ||
          e.error.message.contains('InvalidVersion')) {
        throw AlibabaApiError.api(
          message:
              'Cloud SIEM (Threat Analysis) is not available. '
              'It requires Security Center Enterprise edition or higher. '
              'Original error: ${e.error.message}',
          httpStatus: e.error.details?.httpStatus,
          api: 'UpdateAutomateResponseConfigStatus',
          requestId: e.error.details?.requestId,
        );
      }
      rethrow;
    }

    return ExecuteResponseResult(
      policyId: policyId,
      eventId: eventId,
      mode: 'real',
      result:
          'Response policy "$policyId" executed successfully'
          '${eventId != null ? ' for event "$eventId"' : ''}.',
      raw: response,
    );
  }
}
