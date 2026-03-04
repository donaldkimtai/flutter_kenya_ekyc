import 'dart:developer' as developer;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/driving_license_data.dart';

/// Parses a Kenyan Driving Licence via ML Kit OCR.
///
/// Extracts licence number, holder name, DOB, issue/expiry dates,
/// and permitted vehicle classes (A, B, C, D, E, F, G).
class DrivingLicenseParser {
  DrivingLicenseParser._();

  static final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Scans the provided [InputImage] and extracts [DrivingLicenseData].
  ///
  /// Returns `null` if the image is not recognised as a Kenyan Driving
  /// Licence or if the licence number cannot be extracted.
  static Future<DrivingLicenseData?> parseDocument(
      InputImage inputImage) async {
    try {
      final RecognizedText recognised =
          await _recognizer.processImage(inputImage);
      final String text = recognised.text.toUpperCase();

      // --- Security gate ---
      final bool isLicense = text.contains('DRIVING LICEN') ||
          text.contains('KENYA DRIVING') ||
          text.contains('NTSA') && text.contains('LICEN');
      if (!isLicense) return null;

      // --- Licence number: Kenyan format DL + 7 digits, e.g. DL0012345 ---
      final RegExp licenceRx = RegExp(r'\bDL\d{7}\b');

      // --- Fallback: any 7-digit number if DL prefix not OCR'd cleanly ---
      final RegExp licenceFallbackRx = RegExp(r'\b(\d{7})\b');

      // --- Holder name ---
      final RegExp nameRx = RegExp(
        r'(?:SURNAME|FULL\s+NAME|NAME)\s*[\n:]\s*([A-Z][A-Z\s]{2,60}?)(?=\s*(?:DOB|DATE|BIRTH|CLASS|EXPIRY|ISSUED?|LICENCE|\d|$))',
        multiLine: true,
      );

      // --- Dates ---
      final RegExp dobRx = RegExp(r'\b(\d{2}[.\/]\d{2}[.\/]\d{4})\b');
      final RegExp expiryRx = RegExp(
          r'(?:EXPIRY|EXPIRES?|VALID\s+UNTIL)\s*[\n:]*\s*(\d{2}[.\/]\d{2}[.\/]\d{4})',
          caseSensitive: false);
      final RegExp issueRx = RegExp(
          r'(?:ISSUED?|DATE\s+OF\s+ISSUE)\s*[\n:]*\s*(\d{2}[.\/]\d{2}[.\/]\d{4})',
          caseSensitive: false);

      // --- Vehicle classes: single capital letters A-G ---
      final RegExp classRx =
          RegExp(r'(?:CLASS(?:ES)?|CATEGORIES?)\s*[\n:]\s*([A-G\s,]+)',
              multiLine: true);

      String licenceNumber =
          licenceRx.firstMatch(text)?.group(0) ?? '';
      if (licenceNumber.isEmpty) {
        licenceNumber =
            licenceFallbackRx.firstMatch(text)?.group(1) ?? '';
      }
      if (licenceNumber.isEmpty) return null;

      final String holderName =
          nameRx.firstMatch(text)?.group(1)?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
      final String dob = dobRx.firstMatch(text)?.group(1) ?? '';
      final String expiryDate =
          expiryRx.firstMatch(text)?.group(1) ?? '';
      final String issueDate =
          issueRx.firstMatch(text)?.group(1) ?? '';
      final String rawClasses =
          classRx.firstMatch(text)?.group(1)?.trim() ?? '';
      final List<String> vehicleClasses = rawClasses
          .split(RegExp(r'[\s,]+'))
          .where((s) => RegExp(r'^[A-G]$').hasMatch(s))
          .toList();

      return DrivingLicenseData(
        licenceNumber: licenceNumber,
        holderName: holderName,
        dateOfBirth: dob,
        issueDate: issueDate,
        expiryDate: expiryDate,
        vehicleClasses: vehicleClasses,
      );
    } catch (e, st) {
      developer.log(
        'DrivingLicenseParser: parse error',
        name: 'flutter_kenya_ekyc.parser',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Closes the ML Kit text recognizer and frees memory.
  static void dispose() => _recognizer.close();
}