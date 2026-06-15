import 'package:json_annotation/json_annotation.dart';

part 'error_envelope.g.dart';

/// Details about an Alibaba Cloud API error.
@JsonSerializable()
class ErrorDetails {
  /// HTTP status code from the API response.
  final int? httpStatus;

  /// The Alibaba API action that failed (e.g., "DescribeVulList").
  final String? api;

  /// Request ID returned by Alibaba Cloud for correlation.
  final String? requestId;

  const ErrorDetails({this.httpStatus, this.api, this.requestId});

  factory ErrorDetails.fromJson(Map<String, dynamic> json) =>
      _$ErrorDetailsFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorDetailsToJson(this);
}

/// An error body inside the LLM-friendly error envelope.
@JsonSerializable(explicitToJson: true)
class ErrorBody {
  /// Machine-readable error code (e.g., "ALIBABA_API_ERROR").
  final String code;

  /// Human-readable error message suitable for LLM consumption.
  final String message;

  /// Additional structured details about the error.
  final ErrorDetails? details;

  const ErrorBody({required this.code, required this.message, this.details});

  factory ErrorBody.fromJson(Map<String, dynamic> json) =>
      _$ErrorBodyFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorBodyToJson(this);
}

/// LLM-friendly error envelope returned by all API tools.
///
/// Shape:
/// ```json
/// {
///   "error": {
///     "code": "ALIBABA_API_ERROR",
///     "message": "Human-readable message",
///     "details": { "httpStatus": 403, "api": "DescribeVulList" }
///   }
/// }
/// ```
@JsonSerializable(explicitToJson: true)
class AlibabaApiError implements Exception {
  /// The structured error body.
  final ErrorBody error;

  const AlibabaApiError({required this.error});

  /// Create an error from an API failure.
  factory AlibabaApiError.api({
    required String message,
    int? httpStatus,
    String? api,
    String? requestId,
  }) {
    return AlibabaApiError(
      error: ErrorBody(
        code: 'ALIBABA_API_ERROR',
        message: message,
        details: ErrorDetails(
          httpStatus: httpStatus,
          api: api,
          requestId: requestId,
        ),
      ),
    );
  }

  /// Create an error for missing or invalid credentials.
  factory AlibabaApiError.credentials({required String message}) {
    return AlibabaApiError(
      error: ErrorBody(code: 'CREDENTIALS_ERROR', message: message),
    );
  }

  /// Create an error for invalid parameters.
  factory AlibabaApiError.validation({required String message}) {
    return AlibabaApiError(
      error: ErrorBody(code: 'VALIDATION_ERROR', message: message),
    );
  }

  factory AlibabaApiError.fromJson(Map<String, dynamic> json) =>
      _$AlibabaApiErrorFromJson(json);

  Map<String, dynamic> toJson() => _$AlibabaApiErrorToJson(this);

  @override
  String toString() => 'AlibabaApiError(${error.code}: ${error.message})';
}
