import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'package:alibaba_security_api/alibaba_security_api.dart';

/// Thin client for Alibaba Cloud TableStore (OTS) REST API.
///
/// Implements OTS-specific request signing (different from ACS3 used by
/// Security Center APIs). Falls back to returning empty results when
/// TableStore is not reachable.
class TableStoreClient {
  final AlibabaCredentials credentials;
  final String endpoint;
  final String instanceName;
  final Dio _dio;

  TableStoreClient({
    required this.credentials,
    required this.endpoint,
    required this.instanceName,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// Put a single row into [table].
  ///
  /// [primaryKey] is a map of primary key column names to values.
  /// [columns] is a map of attribute column names to values.
  Future<void> putRow(
    String table,
    Map<String, dynamic> primaryKey,
    Map<String, dynamic> columns,
  ) async {
    final body = json.encode({
      'table_name': table,
      'condition': {'row_existence': 'IGNORE'},
      'primary_key': _encodePrimaryKey(primaryKey),
      'attribute_columns': _encodeColumns(columns),
    });

    await _request('POST', '/', body: body, resource: '/$table');
  }

  /// Get a single row by primary key.
  ///
  /// Returns `null` if the row does not exist.
  Future<Map<String, dynamic>?> getRow(
    String table,
    Map<String, dynamic> primaryKey,
  ) async {
    final body = json.encode({
      'table_name': table,
      'primary_key': _encodePrimaryKey(primaryKey),
      'columns_to_get': [],
      'max_version': 1,
    });

    final response = await _request('POST', '/', body: body, resource: '/$table');
    if (response == null) return null;

    final data = json.decode(response) as Map<String, dynamic>;
    final rows = data['rows'] as List<dynamic>?;
    if (rows == null || rows.isEmpty) return null;

    return _decodeRow(rows.first as Map<String, dynamic>);
  }

  /// Get a range of rows from [table].
  ///
  /// [startKey] and [endKey] define the inclusive/exclusive boundaries.
  /// [limit] caps the number of rows returned.
  Future<List<Map<String, dynamic>>> getRange(
    String table, {
    required Map<String, dynamic> startKey,
    required Map<String, dynamic> endKey,
    int limit = 100,
  }) async {
    final body = json.encode({
      'table_name': table,
      'direction': 'BACKWARD',
      'limit': limit,
      'inclusive_start_primary_key': _encodePrimaryKey(startKey),
      'exclusive_end_primary_key': _encodePrimaryKey(endKey),
      'columns_to_get': [],
      'max_version': 1,
    });

    final response = await _request('POST', '/', body: body, resource: '/$table');
    if (response == null) return [];

    final data = json.decode(response) as Map<String, dynamic>;
    final rows = data['rows'] as List<dynamic>? ?? [];
    return rows.map((r) => _decodeRow(r as Map<String, dynamic>)).toList();
  }

  /// Update specific columns of an existing row.
  Future<void> updateRow(
    String table,
    Map<String, dynamic> primaryKey,
    Map<String, dynamic> columns,
  ) async {
    final body = json.encode({
      'table_name': table,
      'condition': {'row_existence': 'IGNORE'},
      'primary_key': _encodePrimaryKey(primaryKey),
      'update_of_attribute_columns': {
        'PUT': _encodeColumns(columns),
      },
    });

    await _request('POST', '/', body: body, resource: '/$table');
  }

  /// Delete a row by primary key.
  Future<void> deleteRow(
    String table,
    Map<String, dynamic> primaryKey,
  ) async {
    final body = json.encode({
      'table_name': table,
      'condition': {'row_existence': 'IGNORE'},
      'primary_key': _encodePrimaryKey(primaryKey),
    });

    await _request('POST', '/', body: body, resource: '/$table');
  }

  // ---------------------------------------------------------------------------
  // Internal HTTP + signing
  // ---------------------------------------------------------------------------

  Future<String?> _request(
    String method,
    String path, {
    String? body,
    String? resource,
  }) async {
    final uri = Uri.parse('$endpoint$path');
    final bodyBytes = body != null ? utf8.encode(body) : <int>[];
    final contentMd5 = bodyBytes.isEmpty
        ? ''
        : base64.encode(md5.convert(bodyBytes).bytes);
    final contentType = body != null ? 'application/json' : '';
    final date = _formatRfc1123(DateTime.now().toUtc());

    final canonicalResource = resource ?? path;
    final canonicalHeaders = 'x-ots-contentmd5:$contentMd5\n'
        'x-ots-date:$date\n'
        'x-ots-instancename:$instanceName\n'
        'x-ots-signaturemethod:HMAC-SHA256\n';

    final stringToSign =
        '$method\n$contentMd5\n$contentType\n$date\n$canonicalHeaders$canonicalResource';

    final signature = Hmac(
      sha256,
      utf8.encode(credentials.accessKeySecret),
    ).convert(utf8.encode(stringToSign)).toString();

    final sigBase64 = base64.encode(utf8.encode(signature));

    final headers = <String, String>{
      'Content-Type': contentType,
      'x-ots-date': date,
      'x-ots-contentmd5': contentMd5,
      'x-ots-signaturemethod': 'HMAC-SHA256',
      'x-ots-instancename': instanceName,
      'Authorization':
          'OTS ${credentials.accessKeyId}:$sigBase64',
    };

    if (credentials.isStsCredential) {
      headers['x-ots-security-token'] = credentials.securityToken!;
    }

    try {
      final response = await _dio.request<String>(
        uri.toString(),
        data: body,
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.plain,
        ),
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw TableStoreException(
        message: e.message ?? 'TableStore request failed',
        statusCode: e.response?.statusCode,
        body: e.response?.data?.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Encoding helpers
  // ---------------------------------------------------------------------------

  /// TableStore expects primary keys as list of {name: {type: value}} objects.
  List<Map<String, dynamic>> _encodePrimaryKey(Map<String, dynamic> key) {
    return key.entries.map((e) {
      final value = e.value;
      if (value is int) {
        return {e.key: {'INTEGER': value}};
      }
      return {e.key: {'STRING': value.toString()}};
    }).toList();
  }

  /// Attribute columns as list of {name: {type: value}} objects.
  List<Map<String, dynamic>> _encodeColumns(Map<String, dynamic> columns) {
    return columns.entries.map((e) {
      final value = e.value;
      if (value is int) {
        return {e.key: {'INTEGER': value}};
      }
      if (value is bool) {
        return {e.key: {'BOOLEAN': value}};
      }
      return {e.key: {'STRING': value.toString()}};
    }).toList();
  }

  /// Decode a TableStore row response into a flat Map.
  Map<String, dynamic> _decodeRow(Map<String, dynamic> row) {
    final result = <String, dynamic>{};

    final primaryKey = row['primary_key'] as List<dynamic>? ?? [];
    for (final pk in primaryKey) {
      final map = pk as Map<String, dynamic>;
      for (final entry in map.entries) {
        final v = entry.value;
        if (v is Map<String, dynamic>) {
          result[entry.key] = v['INTEGER'] ?? v['STRING'] ?? v['BINARY'];
        } else {
          result[entry.key] = v;
        }
      }
    }

    final attributes = row['attributes'] as List<dynamic>? ?? [];
    for (final attr in attributes) {
      final map = attr as Map<String, dynamic>;
      for (final entry in map.entries) {
        final v = entry.value;
        if (v is Map<String, dynamic>) {
          result[entry.key] =
              v['STRING'] ?? v['INTEGER'] ?? v['BOOLEAN'] ?? v['BINARY'];
        } else {
          result[entry.key] = v;
        }
      }
    }

    return result;
  }

  String _formatRfc1123(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[dt.weekday - 1]}, '
        '${dt.day.toString().padLeft(2, '0')} '
        '${months[dt.month - 1]} '
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')} GMT';
  }
}

/// Exception thrown when a TableStore operation fails.
class TableStoreException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  const TableStoreException({
    required this.message,
    this.statusCode,
    this.body,
  });

  @override
  String toString() =>
      'TableStoreException($message, status: $statusCode)';
}
