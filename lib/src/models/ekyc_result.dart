import 'package:json_annotation/json_annotation.dart';
import 'document_types.dart';

part 'ekyc_result.g.dart';

/// Represents the comprehensive result of the eKYC verification process.
@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class EkycVerificationResult {
  /// Whether the passive (TFLite) and active (ML Kit) liveness checks passed.
  final bool isLivenessVerified;

  /// The mathematical distance between the live selfie and document photo.
  final double? faceMatchScore;

  /// Whether the face match score meets the acceptable Kenyan threshold.
  final bool? isFaceMatch;

  /// The type of document that was scanned.
  final KenyanDocumentType? scannedDocumentType;

  /// The extracted document data stored as a JSON map.
  /// 
  /// This accommodates different models like [KenyanIdData] or [NtsaLogbookData].
  final Map<String, dynamic>? documentData;

  /// Any error message generated during the process.
  final String? errorMessage;

  /// Creates a new immutable [EkycVerificationResult].
  const EkycVerificationResult({
    this.isLivenessVerified = false,
    this.faceMatchScore,
    this.isFaceMatch,
    this.scannedDocumentType,
    this.documentData,
    this.errorMessage,
  });

  /// Creates an [EkycVerificationResult] from a JSON map.
  factory EkycVerificationResult.fromJson(Map<String, dynamic> json) => 
      _$EkycVerificationResultFromJson(json);

  /// Converts this [EkycVerificationResult] to a JSON map.
  Map<String, dynamic> toJson() => _$EkycVerificationResultToJson(this);
}