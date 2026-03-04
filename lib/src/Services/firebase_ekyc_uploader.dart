import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

// NOTE: Add these to pubspec.yaml when you're ready for Firebase:
//   firebase_core: ^2.x.x
//   cloud_firestore: ^4.x.x
//   firebase_storage: ^11.x.x
//
// Then uncomment the imports below and remove the stub classes at the bottom.
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';

import '../models/ekyc_result.dart';

/// Uploads the completed eKYC verification result to Firebase.
///
/// Writes to two Firebase services:
/// - **Firestore** (`riders/{riderId}/verifications/{docId}`): the structured
///   [EkycVerificationResult] JSON + metadata
/// - **Firebase Storage** (`ekyc/{riderId}/{docId}/selfie.jpg`): the captured
///   selfie JPEG (optional, only if [selfieBytes] is provided)
///
/// Usage from Bodago Rider after the wizard returns:
/// ```dart
/// final uploadRef = await FirebaseEkycUploader.upload(
///   riderId: currentUser.uid,
///   result: ekycResult,
///   selfieBytes: capturedJpegBytes, // optional
/// );
/// ```
class FirebaseEkycUploader {
  FirebaseEkycUploader._();

  static const String _collection = 'rider_verifications';
  static const String _storageBucket = 'ekyc';

  /// Uploads [result] to Firestore and optionally [selfieBytes] to Storage.
  ///
  /// Returns the Firestore document ID on success, or throws on failure.
  static Future<String> upload({
    required String riderId,
    required EkycVerificationResult result,
    Uint8List? selfieBytes,
  }) async {
    try {
      // ── 1. Write structured result to Firestore ──────────────────────────
      final Map<String, dynamic> payload = {
        ...result.toJson(),
        'rider_id': riderId,
        'uploaded_at': DateTime.now().toUtc().toIso8601String(),
        // Firestore-friendly decision string
        'decision_label': result.decision.name,
      };

      // TODO: Replace _FirestoreStub with real FirebaseFirestore.instance
      final String docId = await _FirestoreStub.addDocument(
        collection: '$_collection/$riderId/verifications',
        data: payload,
      );

      debugPrint('[FirebaseEkycUploader] Firestore doc created: $docId');

      // ── 2. Upload selfie to Storage (if provided) ────────────────────────
      if (selfieBytes != null && selfieBytes.isNotEmpty) {
        final String storagePath =
            '$_storageBucket/$riderId/$docId/selfie.jpg';

        // TODO: Replace _StorageStub with real FirebaseStorage.instance
        await _StorageStub.uploadBytes(
          path: storagePath,
          bytes: selfieBytes,
          contentType: 'image/jpeg',
        );

        debugPrint(
            '[FirebaseEkycUploader] Selfie uploaded: $storagePath');

        // Update the Firestore doc with the selfie path
        await _FirestoreStub.updateDocument(
          collection: '$_collection/$riderId/verifications',
          docId: docId,
          data: {'selfie_storage_path': storagePath},
        );
      }

      return docId;
    } catch (e, st) {
      developer.log(
        'FirebaseEkycUploader: upload failed',
        name: 'flutter_kenya_ekyc.firebase',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Fetches all verification records for a given [riderId] from Firestore.
  ///
  /// Useful in the Bodago Rider admin panel to review past submissions.
  static Future<List<Map<String, dynamic>>> getVerificationsForRider(
      String riderId) async {
    try {
      return await _FirestoreStub.getDocuments(
        collection: '$_collection/$riderId/verifications',
      );
    } catch (e) {
      debugPrint(
          '[FirebaseEkycUploader] getVerificationsForRider error: $e');
      return [];
    }
  }
}


// STUBS — Replace with real Firebase SDK calls once you add firebase_core etc.


class _FirestoreStub {
  static Future<String> addDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    // Replace with:
    // final ref = await FirebaseFirestore.instance
    //     .collection(collection)
    //     .add(data);
    // return ref.id;
    debugPrint('[Stub] Firestore.add($collection): $data');
    return 'stub_doc_${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<void> updateDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    // Replace with:
    // await FirebaseFirestore.instance
    //     .collection(collection)
    //     .doc(docId)
    //     .update(data);
    debugPrint('[Stub] Firestore.update($collection/$docId): $data');
  }

  static Future<List<Map<String, dynamic>>> getDocuments({
    required String collection,
  }) async {
    // Replace with:
    // final snap = await FirebaseFirestore.instance
    //     .collection(collection)
    //     .orderBy('uploaded_at', descending: true)
    //     .get();
    // return snap.docs.map((d) => d.data()).toList();
    debugPrint('[Stub] Firestore.get($collection)');
    return [];
  }
}

class _StorageStub {
  static Future<void> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    // Replace with:
    // await FirebaseStorage.instance
    //     .ref(path)
    //     .putData(bytes, SettableMetadata(contentType: contentType));
    debugPrint(
        '[Stub] Storage.upload($path) — ${bytes.lengthInBytes} bytes');
  }
}