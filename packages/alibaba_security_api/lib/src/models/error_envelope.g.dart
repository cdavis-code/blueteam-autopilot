// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_envelope.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorDetails _$ErrorDetailsFromJson(Map<String, dynamic> json) => ErrorDetails(
  httpStatus: (json['httpStatus'] as num?)?.toInt(),
  api: json['api'] as String?,
  requestId: json['requestId'] as String?,
);

Map<String, dynamic> _$ErrorDetailsToJson(ErrorDetails instance) =>
    <String, dynamic>{
      'httpStatus': instance.httpStatus,
      'api': instance.api,
      'requestId': instance.requestId,
    };

ErrorBody _$ErrorBodyFromJson(Map<String, dynamic> json) => ErrorBody(
  code: json['code'] as String,
  message: json['message'] as String,
  details: json['details'] == null
      ? null
      : ErrorDetails.fromJson(json['details'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ErrorBodyToJson(ErrorBody instance) => <String, dynamic>{
  'code': instance.code,
  'message': instance.message,
  'details': instance.details?.toJson(),
};

AlibabaApiError _$AlibabaApiErrorFromJson(Map<String, dynamic> json) =>
    AlibabaApiError(
      error: ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AlibabaApiErrorToJson(AlibabaApiError instance) =>
    <String, dynamic>{'error': instance.error.toJson()};
