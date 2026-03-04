// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ekyc_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EkycVerificationResult _$EkycVerificationResultFromJson(
        Map<String, dynamic> json) =>
    EkycVerificationResult(
      isLivenessVerified: json['is_liveness_verified'] as bool? ?? false,
      faceMatchScore: (json['face_match_score'] as num?)?.toDouble(),
      isFaceMatch: json['is_face_match'] as bool?,
      scannedDocumentType: $enumDecodeNullable(
          _$KenyanDocumentTypeEnumMap, json['scanned_document_type']),
      documentData: json['document_data'] as Map<String, dynamic>?,
      errorMessage: json['error_message'] as String?,
    );

Map<String, dynamic> _$EkycVerificationResultToJson(
        EkycVerificationResult instance) =>
    <String, dynamic>{
      'is_liveness_verified': instance.isLivenessVerified,
      'face_match_score': instance.faceMatchScore,
      'is_face_match': instance.isFaceMatch,
      'scanned_document_type':
          _$KenyanDocumentTypeEnumMap[instance.scannedDocumentType],
      'document_data': instance.documentData,
      'error_message': instance.errorMessage,
    };

const _$KenyanDocumentTypeEnumMap = {
  KenyanDocumentType.nationalIdFront: 'nationalIdFront',
  KenyanDocumentType.nationalIdBack: 'nationalIdBack',
  KenyanDocumentType.ntsaLogbook: 'ntsaLogbook',
  KenyanDocumentType.drivingLicense: 'drivingLicense',
  KenyanDocumentType.psvBadge: 'psvBadge',
};
