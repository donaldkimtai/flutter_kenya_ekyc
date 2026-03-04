import 'dart:developer' as developer;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/psv_badge_data.dart';

/// Parses a Kenyan PSV (Public Service Vehicle) Badge via ML Kit OCR.
///
/// A PSV badge is issued by NTSA to individual drivers and contains
/// the badge number, driver name, vehicle class, and expiry date.
class PsvBadgeParser {
  PsvBadgeParser._();

  static final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Scans the provided [InputImage] and extracts [PsvBadgeData].
  ///
  /// Returns `null` if the image is not recognised as a PSV badge
  /// or if the badge number cannot be extracted.
  static Future<PsvBadgeData?> parseDocument(InputImage inputImage) async {
    try {
      final RecognizedText recognised =
          await _recognizer.processImage(inputImage);
      final String text = recognised.text.toUpperCase();

      // --- Security gate ---
      final bool isPsv = text.contains('PSV') ||
          text.contains('PUBLIC SERVICE') ||
          text.contains('NTSA') ||
          text.contains('PSV BADGE');
      if (!isPsv) return null;

      // --- PSV Badge Number: alphanumeric, e.g. PSV/001234 or 001234 ---
      final RegExp badgeRx =
          RegExp(r'(?:PSV[\/\s]?)?(\d{4,8})\b');

      // --- Driver name ---
      final RegExp nameRx = RegExp(
        r'(?:NAME|HOLDER|DRIVER)\s*[\n:]\s*([A-Z][A-Z\s]{2,60}?)(?=\s*(?:BADGE|CLASS|EXPIRY|DATE|VEHICLE|\d|$))',
        multiLine: true,
      );

      // --- Vehicle class: e.g. Class A, Class B, Matatu, Taxi ---
      final RegExp classRx = RegExp(
          r'(?:CLASS|VEHICLE\s+CLASS)\s*[\n:]\s*([A-Z0-9][A-Z0-9\s]{0,20}?)(?=\n|$)',
          multiLine: true);

      // --- Expiry date ---
      final RegExp expiryRx =
          RegExp(r'(?:EXPIRY|EXPIRES?|VALID\s+UNTIL)\s*[\n:]*\s*(\d{2}[.\/]\d{2}[.\/]\d{4})',
              caseSensitive: false);

      // --- Issue date ---
      final RegExp issuedRx =
          RegExp(r'(?:ISSUED?|DATE\s+OF\s+ISSUE)\s*[\n:]*\s*(\d{2}[.\/]\d{2}[.\/]\d{4})',
              caseSensitive: false);

      final String badgeNumber =
          badgeRx.firstMatch(text)?.group(1) ?? '';
      if (badgeNumber.isEmpty) return null;

      final String driverName =
          nameRx.firstMatch(text)?.group(1)?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
      final String vehicleClass =
          classRx.firstMatch(text)?.group(1)?.trim() ?? '';
      final String expiryDate =
          expiryRx.firstMatch(text)?.group(1) ?? '';
      final String issueDate =
          issuedRx.firstMatch(text)?.group(1) ?? '';

      return PsvBadgeData(
        badgeNumber: badgeNumber,
        driverName: driverName,
        vehicleClass: vehicleClass,
        expiryDate: expiryDate,
        issueDate: issueDate,
      );
    } catch (e, st) {
      developer.log(
        'PsvBadgeParser: parse error',
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