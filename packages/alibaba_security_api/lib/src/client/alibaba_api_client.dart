import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../auth/alibaba_credentials.dart';
import '../auth/alibaba_signer.dart';
import '../enums.dart';
import '../models/error_envelope.dart';

/// Endpoint configuration for an Alibaba Cloud API service.
class _ServiceEndpoint {
  final String host;
  final String service;
  final String version;

  const _ServiceEndpoint({
    required this.host,
    required this.service,
    required this.version,
  });
}

/// Centralized HTTP client for Alibaba Cloud Security APIs.
///
/// Handles request signing, pagination, error shaping, and dry-run mode.
/// All service classes ([SecurityCenterService], [CloudSiemService]) use
/// this client for API communication.
class AlibabaApiClient {
  final AlibabaCredentials credentials;
  final String region;
  final SecurityCenterMode mode;
  final Dio _dio;

  /// Security Center (SAS) API endpoint.
  late final _ServiceEndpoint _sasEndpoint;

  /// Cloud SIEM API endpoint.
  late final _ServiceEndpoint _siemEndpoint;

  /// WAF API endpoint.
  late final _ServiceEndpoint _wafEndpoint;

  /// Create a client with explicit credentials.
  AlibabaApiClient({
    required this.credentials,
    required this.region,
    this.mode = SecurityCenterMode.dryRun,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _sasEndpoint = _ServiceEndpoint(
      host: 'tds.$region.aliyuncs.com',
      service: 'sas',
      version: '2018-12-03',
    );
    _siemEndpoint = _ServiceEndpoint(
      host: 'cloud-siem.$region.aliyuncs.com',
      service: 'cloud-siem',
      version: '2022-06-16',
    );
    _wafEndpoint = _ServiceEndpoint(
      host: 'wafopenapi.$region.aliyuncs.com',
      service: 'waf-openapi',
      version: '2021-10-01',
    );
  }

  /// Create a client loading credentials from environment variables.
  factory AlibabaApiClient.fromEnvironment({Dio? dio}) {
    final credentials = AlibabaCredentials.fromEnvironment();
    final region = Platform.environment['ALIBABA_REGION'] ?? 'cn-hangzhou';
    final modeStr = Platform.environment['SECURITY_CENTER_MODE'] ?? 'dry-run';

    return AlibabaApiClient(
      credentials: credentials,
      region: region,
      mode: SecurityCenterMode.fromString(modeStr),
      dio: dio,
    );
  }

  /// Whether the client is in dry-run mode.
  bool get isDryRun => mode == SecurityCenterMode.dryRun;

  /// Call a Security Center (SAS) API action.
  ///
  /// [action] is the API action name (e.g., "DescribeVulList").
  /// [params] are additional query parameters.
  Future<Map<String, dynamic>> callSasApi(
    String action, {
    Map<String, String> params = const {},
  }) async {
    // 'From' is required by most SAS API actions (fixed value 'aqs').
    return _callApi(_sasEndpoint, action, params: {'From': 'aqs', ...params});
  }

  /// Call a Cloud SIEM API action.
  ///
  /// [action] is the API action name.
  /// [params] are additional query parameters.
  Future<Map<String, dynamic>> callSiemApi(
    String action, {
    Map<String, String> params = const {},
  }) async {
    return _callApi(_siemEndpoint, action, params: params);
  }

  /// Call a WAF API action.
  ///
  /// [action] is the API action name (e.g., "DescribeAlarmList").
  /// [params] are additional query parameters.
  Future<Map<String, dynamic>> callWafApi(
    String action, {
    Map<String, String> params = const {},
  }) async {
    return _callApi(_wafEndpoint, action, params: params);
  }

  /// Internal API call implementation with signing and error handling.
  Future<Map<String, dynamic>> _callApi(
    _ServiceEndpoint endpoint,
    String action, {
    Map<String, String> params = const {},
  }) async {
    final queryParams = <String, String>{
      'Action': action,
      'Version': endpoint.version,
      'Format': 'JSON',
      ...params,
    };

    final uri = Uri.https(endpoint.host, '/', queryParams);

    // DEBUG: log the full URI for diagnostics
    if (Platform.environment['ALIBABA_DEBUG'] == '1') {
      stderr.writeln('[DEBUG] ${endpoint.service} URI: $uri');
    }

    final signer = AlibabaSigner(
      credentials: credentials,
      region: region,
      service: endpoint.service,
      version: endpoint.version,
    );

    final signHeaders = signer.signRequest(
      method: 'GET',
      uri: uri,
      action: action,
    );

    try {
      final response = await _dio.get(
        uri.toString(),
        options: Options(headers: signHeaders),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }

      return json.decode(response.data.toString()) as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _shapeError(e, action);
    }
  }

  /// Call a paginated API, aggregating all pages into a single list.
  ///
  /// [fetchPage] is called for each page number and returns the page results
  /// and total count.
  Future<List<Map<String, dynamic>>> fetchAllPages({
    required Future<({List<Map<String, dynamic>> items, int totalCount})>
    Function(int pageNumber, int pageSize)
    fetchPage,
    int pageSize = 20,
    int maxPages = 50,
  }) async {
    final allItems = <Map<String, dynamic>>[];
    var page = 1;

    while (page <= maxPages) {
      final result = await fetchPage(page, pageSize);
      allItems.addAll(result.items);

      if (allItems.length >= result.totalCount || result.items.isEmpty) {
        break;
      }
      page++;
    }

    return allItems;
  }

  /// Shape a DioException into an LLM-friendly [AlibabaApiError].
  AlibabaApiError _shapeError(DioException e, String action) {
    final response = e.response;
    final statusCode = response?.statusCode;

    // Try to extract Alibaba-specific error info from the response body.
    if (response?.data is Map<String, dynamic>) {
      final body = response!.data as Map<String, dynamic>;
      final code = (body['Code'] ?? body['code'])?.toString();
      final rawMessage = (body['Message'] ?? body['message'])?.toString();
      final message = code != null && rawMessage != null
          ? '$code: $rawMessage'
          : (rawMessage ?? e.message ?? 'Unknown API error');
      return AlibabaApiError.api(
        message: message,
        httpStatus: statusCode,
        api: action,
        requestId: (body['RequestId'] ?? body['requestId'])?.toString(),
      );
    }

    if (statusCode == 403) {
      return AlibabaApiError.api(
        message:
            'Access denied. Check that your RAM credentials have permission '
            'to call $action on Security Center / Agentic SOC.',
        httpStatus: 403,
        api: action,
      );
    }

    if (statusCode == 401) {
      return AlibabaApiError.credentials(
        message:
            'Authentication failed. Verify ALIBABA_ACCESS_KEY_ID and '
            'ALIBABA_ACCESS_KEY_SECRET are correct.',
      );
    }

    return AlibabaApiError.api(
      message: e.message ?? 'An unexpected error occurred calling $action.',
      httpStatus: statusCode,
      api: action,
    );
  }
}
