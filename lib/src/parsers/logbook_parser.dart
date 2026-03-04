import 'dart:developer' as developer;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/ntsa_logbook_data.dart';

/// Parses an NTSA Vehicle Logbook via ML Kit OCR.
class LogbookParser {
  LogbookParser._();

  static final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Scans the provided [InputImage] and extracts [NtsaLogbookData].
  ///
  /// Returns `null` if the document is not recognised as an NTSA Logbook
  /// or if plate and chassis cannot both be extracted.
  static Future<NtsaLogbookData?> parseDocument(InputImage inputImage) async {
    try {
      final RecognizedText recognised =
          await _recognizer.processImage(inputImage);
      final String text = recognised.text.toUpperCase();

      // --- Security gate ---
      if (!text.contains('LOGBOOK') &&
          !text.contains('NTSA') &&
          !text.contains('KENYA REVENUE')) {
        return null;
      }

      // --- Plate: KXX 000X or KXX000X ---
      final RegExp plateRx = RegExp(r'\bK[A-Z]{2}\s?\d{3}[A-Z]\b');

      // --- Chassis/VIN: standard 17-char alphanumeric (no I, O, Q) ---
      final RegExp chassisRx = RegExp(r'\b[A-HJ-NPR-Z0-9]{17}\b');

      // FIX: Tight owner regex — stops at the next field label so we
      // don't swallow "JOHN KAMAU MAKE TOYOTA" as the owner name.
      final RegExp ownerRx = RegExp(
        r'(?:REGISTERED\s+OWNER|OWNER|NAME\s+OF\s+OWNER)\s*[\n:]\s*([A-Z][A-Z\s]{2,60}?)(?=\s*(?:MAKE|MODEL|YEAR|ENGINE|CHASSIS|PLATE|\d|$))',
        multiLine: true,
      );

      // --- NEW: Vehicle make, model, year ---
      final RegExp makeRx = RegExp(
          r'(?:MAKE|MANUFACTURER)\s*[\n:]\s*([A-Z][A-Z\s]{1,30}?)(?=\n|MODEL|$)',
          multiLine: true);
      final RegExp modelRx = RegExp(
          r'MODEL\s*[\n:]\s*([A-Z0-9][A-Z0-9\s\-]{1,30}?)(?=\n|YEAR|$)',
          multiLine: true);
      final RegExp yearRx = RegExp(r'\b(19[7-9]\d|20[0-3]\d)\b');
      final RegExp engineRx =
          RegExp(r'ENGINE\s*(?:NO|NUMBER|#)?\s*[\n:]\s*([A-Z0-9]{5,20})',
              multiLine: true);

      final String plate = plateRx.firstMatch(text)?.group(0) ?? '';
      final String chassis = chassisRx.firstMatch(text)?.group(0) ?? '';

      if (plate.isEmpty && chassis.isEmpty) return null;

      final String owner =
          ownerRx.firstMatch(text)?.group(1)?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
      final String make =
          makeRx.firstMatch(text)?.group(1)?.trim() ?? '';
      final String model =
          modelRx.firstMatch(text)?.group(1)?.trim() ?? '';
      final String year = yearRx.firstMatch(text)?.group(1) ?? '';
      final String engineNo =
          engineRx.firstMatch(text)?.group(1)?.trim() ?? '';

      return NtsaLogbookData(
        plateNumber: plate,
        chassisNumber: chassis,
        ownerName: owner,
        vehicleMake: make,
        vehicleModel: model,
        yearOfManufacture: year,
        engineNumber: engineNo,
      );
    } catch (e, st) {
      developer.log(
        'LogbookParser: parse error',
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