import 'package:json_annotation/json_annotation.dart';
import 'document_types.dart';

part 'ekyc_result.g.dart';

/// The recommended routing decision produced by the eKYC engine.
enum VerificationDecision {
  /// Face matched the document with high confidence. Auto-approve the rider.
  autoApproved,

  /// Face match score was borderline OR a non-face document was verified.
  /// Route to an admin/operations agent for manual review.
  requiresAdminReview,

  /// Spoofing detected, face mismatch, or critical document fields missing.
  /// Reject and ask the rider to retry or contact support.
  rejected,
}

/// The complete, immutable result returned by the eKYC engine after
/// document scanning, liveness detection, and face match.
///
/// Serialised to JSON and sent to Firebase by [FirebaseEkycUploader].
@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class EkycVerificationResult {
  /// Whether passive (TFLite spoof) and active (ML Kit liveness) checks passed.
  final bool isLivenessVerified;

  /// Euclidean distance between selfie and document face embeddings.
  /// Lower = more similar. Null if no face was found on the document.
  final double? faceMatchScore;

  /// Whether the face match score is within the acceptable threshold.
  /// Null if no document face embedding was available.
  final bool? isFaceMatch;

  /// The recommended routing decision for the backend / Bodago Rider app.
  final VerificationDecision decision;

  /// The type of document that was scanned.
  final KenyanDocumentType? scannedDocumentType;

  /// Structured document data extracted by OCR (varies by document type).
  final Map<String, dynamic>? documentData;

  /// ISO-8601 timestamp of when verification completed.
  final String? verifiedAt;

  /// Any error message generated during the process.
  final String? errorMessage;

  const EkycVerificationResult({
    this.isLivenessVerified = false,
    this.faceMatchScore,
    this.isFaceMatch,
    required this.decision,
    this.scannedDocumentType,
    this.documentData,
    this.verifiedAt,
    this.errorMessage,
  });

  factory EkycVerificationResult.fromJson(Map<String, dynamic> json) =>
      _$EkycVerificationResultFromJson(json);

  Map<String, dynamic> toJson() => _$EkycVerificationResultToJson(this);
}