import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'alibaba_credentials.dart';

/// Signs Alibaba Cloud OpenAPI requests using the v3 signature algorithm
/// (HMAC-SHA256 with canonical request format).
///
/// Reference: https://api.alibabacloud.com/document
class AlibabaSigner {
  final AlibabaCredentials _credentials;
  final String _version;

  /// Create a signer with the given credentials, region, service, and version.
  ///
  /// [service] is typically "sas" for Security Center, "cloud-siem" for
  /// Cloud SIEM, or "waf-openapi" for WAF APIs.
  /// [version] is the API version string (e.g., "2018-12-03").
  const AlibabaSigner({
    required AlibabaCredentials credentials,
    required String region,
    String service = 'sas',
    String version = '2018-12-03',
  }) : _credentials = credentials,
       _version = version;

  /// Sign an HTTP request and return the headers to add.
  ///
  /// [method] is the HTTP method (GET, POST, etc.).
  /// [uri] is the full request URI.
  /// [body] is the request body (empty string for GET requests).
  /// [action] is the API action name (e.g., "DescribeVulList").
  /// [additionalHeaders] are any extra headers being sent.
  Map<String, String> signRequest({
    required String method,
    required Uri uri,
    String body = '',
    required String action,
    Map<String, String> additionalHeaders = const {},
  }) {
    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);

    // Build the canonical request
    final canonicalUri = uri.path.isEmpty ? '/' : uri.path;
    final canonicalQueryString = _buildCanonicalQueryString(
      uri.queryParameters,
    );
    final payloadHash = sha256.convert(utf8.encode(body)).toString();

    final version = _version;

    final signedHeaderNames = [
      'host',
      'x-acs-action',
      'x-acs-date',
      'x-acs-signature-nonce',
      'x-acs-version',
    ];
    if (_credentials.isStsCredential) {
      signedHeaderNames.add('x-acs-security-token');
    }
    signedHeaderNames.sort();

    final canonicalHeaders = StringBuffer();
    canonicalHeaders.writeln('host:${uri.host}');
    canonicalHeaders.writeln('x-acs-action:$action');
    canonicalHeaders.writeln('x-acs-date:$amzDate');

    final nonce = _generateNonce();
    canonicalHeaders.writeln('x-acs-signature-nonce:$nonce');
    canonicalHeaders.writeln('x-acs-version:$version');
    if (_credentials.isStsCredential) {
      canonicalHeaders.writeln(
        'x-acs-security-token:${_credentials.securityToken}',
      );
    }

    final signedHeaders = signedHeaderNames.join(';');

    final canonicalRequest = [
      method.toUpperCase(),
      canonicalUri,
      canonicalQueryString,
      canonicalHeaders.toString(),
      signedHeaders,
      payloadHash,
    ].join('\n');

    // Build the string to sign (ACS3 format: algorithm + newline + hash)
    final canonicalRequestHash = sha256
        .convert(utf8.encode(canonicalRequest))
        .toString();
    final stringToSign = 'ACS3-HMAC-SHA256\n$canonicalRequestHash';

    // Calculate signature using raw AccessKey secret
    final signature = Hmac(
      sha256,
      utf8.encode(_credentials.accessKeySecret),
    ).convert(utf8.encode(stringToSign)).toString();

    // Build the Authorization header (no spaces after commas per ACS3 spec)
    final authorization =
        'ACS3-HMAC-SHA256 Credential=${_credentials.accessKeyId},'
        'SignedHeaders=$signedHeaders,'
        'Signature=$signature';

    final headers = <String, String>{
      'Authorization': authorization,
      'x-acs-action': action,
      'x-acs-date': amzDate,
      'x-acs-signature-nonce': nonce,
      'x-acs-version': version,
    };

    if (_credentials.isStsCredential) {
      headers['x-acs-security-token'] = _credentials.securityToken!;
    }

    return headers;
  }

  /// Build a canonical query string from query parameters.
  String _buildCanonicalQueryString(Map<String, String> params) {
    if (params.isEmpty) return '';
    final sortedKeys = params.keys.toList()..sort();
    return sortedKeys
        .map(
          (k) =>
              '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(params[k]!)}',
        )
        .join('&');
  }

  /// Format a date as ISO-8601 extended format for the x-acs-date header.
  /// Required format: yyyy-MM-dd'T'HH:mm:ss'Z'
  String _formatAmzDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}T'
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}Z';
  }

  /// Generate a unique nonce for request signing.
  String _generateNonce() {
    return '${DateTime.now().millisecondsSinceEpoch}-'
        '${DateTime.now().microsecondsSinceEpoch}';
  }
}
