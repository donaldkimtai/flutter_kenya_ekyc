import 'package:flutter/material.dart';
import '../models/document_types.dart';
import '../models/ekyc_result.dart';
import '../ui/ekyc_wizard_view.dart';
import '../services/firebase_ekyc_uploader.dart';

/// High-level entry point for the eKYC engine.
///
/// final result = await EkycService.launch(
///   context,
///   documentType: KenyanDocumentType.drivingLicense,
///   riderId: FirebaseAuth.instance.currentUser!.uid,
///   uploadToFirebase: true,
/// );
///
/// if (result == null) {
///   // User cancelled
/// } else if (result.decision == VerificationDecision.autoApproved) {
///   // Proceed to next registration step
/// } else if (result.decision == VerificationDecision.requiresAdminReview) {
///   // Show "pending review" screen
/// } else {
///   // result.decision == VerificationDecision.rejected
///   // Show retry / support screen
/// }
/// ```
class EkycService {
  EkycService._();

  /// Launches the eKYC wizard as a full-screen modal route.
  ///
  /// Parameters:
  /// - [context]: BuildContext from the calling screen
  /// - [documentType]: Which document to verify (ID, licence, logbook, PSV)
  /// - [riderId]: The Firebase UID of the rider being registered.
  ///   Required if [uploadToFirebase] is true.
  /// - [uploadToFirebase]: When true, the result is automatically uploaded
  ///   to Firestore after the wizard completes. Defaults to `false`.
  ///
  /// Returns an [EkycVerificationResult], or `null` if the user cancelled.
  static Future<EkycVerificationResult?> launch(
    BuildContext context, {
    required KenyanDocumentType documentType,
    String? riderId,
    bool uploadToFirebase = false,
  }) async {
    final EkycVerificationResult? result =
        await Navigator.of(context).push<EkycVerificationResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EkycWizardView(targetDocumentType: documentType),
      ),
    );

    if (result == null) return null;

    // Optionally upload to Firebase in the background
    if (uploadToFirebase && riderId != null && riderId.isNotEmpty) {
      try {
        await FirebaseEkycUploader.upload(
          riderId: riderId,
          result: result,
          // selfieBytes: pass captured bytes here if you want selfie stored
        );
      } catch (e) {
        // Upload failure should NOT block the calling app — log and continue
        debugPrint('[EkycService] Firebase upload failed (non-fatal): $e');
      }
    }

    return result;
  }
}
