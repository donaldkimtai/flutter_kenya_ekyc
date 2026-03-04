import 'dart:developer' as developer;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/kenyan_id_data.dart';

/// Parses a Kenyan National ID or Driving License via ML Kit OCR.
///
/// Supports both front-of-ID (names, ID number, DOB) and
/// driving license text layouts.
class KenyaIdParser {
  KenyaIdParser._();

  static final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Scans the provided [InputImage] and extracts [KenyanIdData].
  ///
  /// Returns `null` if the image is not recognised as a Kenyan ID/license
  /// or if critical fields (ID number) cannot be extracted.
  static Future<KenyanIdData?> parseDocument(InputImage inputImage) async {
    try {
      final RecognizedText recognised =
          await _recognizer.processImage(inputImage);
      final String raw = recognised.text;
      final String text = raw.toUpperCase();

      // --- Security gate: must look like a Kenyan ID or license ---
      final bool isId = text.contains('REPUBLIC OF KENYA') ||
          text.contains('IDENTITY CARD') ||
          text.contains('NATIONAL IDENTITY');
      final bool isLicense = text.contains('DRIVING LICENCE') ||
          text.contains('DRIVING LICENSE') ||
          text.contains('KENYA DRIVING');

      if (!isId && !isLicense) return null;

      // --- ID Number: 7 or 8 consecutive digits ---
      final RegExp idRx = RegExp(r'\b(\d{7,8})\b');

      // --- Date of Birth: DD.MM.YYYY or DD/MM/YYYY ---
      final RegExp dobRx = RegExp(r'\b(\d{2}[.\/]\d{2}[.\/]\d{4})\b');

      // FIX: Tight name regex — stops at the next ALL-CAPS label keyword
      // so it no longer captures "JOHN OTIENO SEX MALE DATE OF BIRTH".
      // Captures 2–5 uppercase words on the line immediately after NAME.
      final RegExp nameRx = RegExp(
        r'(?:FULL\s+NAME|SURNAME|NAME)\s*[\n:]\s*([A-Z][A-Z\s]{2,60}?)(?=\s*(?:SEX|DATE|BIRTH|ID|SERIAL|DL|\d|$))',
        multiLine: true,
      );

      // --- Optional fields ---
      final RegExp genderRx = RegExp(r'\b(MALE|FEMALE)\b');
      final RegExp districtRx =
          RegExp(r'(?:DISTRICT|COUNTY)[:\s]+([A-Z\s]{3,30}?)(?=\n|$)',
              multiLine: true);
      final RegExp expiryRx = RegExp(
          r'(?:EXPIRY|EXPIRES?|VALID\s+UNTIL)[:\s]+(\d{2}[.\/]\d{2}[.\/]\d{4})',
          caseSensitive: false);

      final String idNumber = idRx.firstMatch(text)?.group(1) ?? '';
      if (idNumber.isEmpty) return null; // Critical field missing

      final String dob = dobRx.firstMatch(text)?.group(1) ?? '';
      final String fullName =
          nameRx.firstMatch(text)?.group(1)?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
      final String gender = genderRx.firstMatch(text)?.group(1) ?? '';
      final String district =
          districtRx.firstMatch(text)?.group(1)?.trim() ?? '';
      final String expiry = expiryRx.firstMatch(text)?.group(1) ?? '';

      return KenyanIdData(
        idNumber: idNumber,
        fullName: fullName,
        dateOfBirth: dob,
        gender: gender,
        district: district,
        expiryDate: expiry,
      );
    } catch (e, st) {
      developer.log(
        'KenyaIdParser: parse error',
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