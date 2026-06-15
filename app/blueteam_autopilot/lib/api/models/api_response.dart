/// Generic API response wrapper matching the backend's `{data, error, meta}`
/// envelope format.
class ApiResponse<T> {
  final T? data;
  final ApiError? error;
  final ApiMeta? meta;

  const ApiResponse({this.data, this.error, this.meta});

  bool get isSuccess => error == null;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromData,
  ) {
    return ApiResponse(
      data: json['data'] != null ? fromData(json['data']) : null,
      error: json['error'] != null
          ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      meta: json['meta'] != null
          ? ApiMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ApiError {
  final String code;
  final String message;

  const ApiError({required this.code, required this.message});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? 'Unknown error',
    );
  }

  @override
  String toString() => '[$code] $message';
}

class ApiMeta {
  final int total;

  const ApiMeta({required this.total});

  factory ApiMeta.fromJson(Map<String, dynamic> json) {
    return ApiMeta(total: json['total'] as int? ?? 0);
  }
}
