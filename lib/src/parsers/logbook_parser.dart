import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/ntsa_logbook_data.dart';

/// A utility class dedicated to extracting NTSA Logbook data using ML Kit.
class LogbookParser {
  LogbookParser._();

  static final TextRecognizer _textRecognizer = 
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Scans the provided image and attempts to extract [NtsaLogbookData].
  static Future<NtsaLogbookData?> parseDocument(InputImage inputImage) async {
    try {
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      final String fullText = recognizedText.text.toUpperCase();

      // 1. Security Check: Is this a Logbook?
      if (!fullText.contains('LOGBOOK') && !fullText.contains('NTSA')) {
        return null;
      }

      // 2. RegEx Patterns optimized for NTSA Logbooks
      // Matches Kenyan Plate format: 3 Letters, 3 Digits, 1 Letter (e.g., KCA 123A or KCA123A)
      final RegExp plateRegEx = RegExp(r'\bK[A-Z]{2}\s?\d{3}[A-Z]\b');
      
      // Matches a 17-character alphanumeric string typical of VIN/Chassis numbers
      final RegExp chassisRegEx = RegExp(r'\b[A-HJ-NPR-Z0-9]{17}\b');
      
      // Looks for a name explicitly after the word "OWNER" or "NAME OF OWNER"
      final RegExp ownerRegEx = RegExp(r'(?:OWNER|NAME)[\s\n]*([A-Z\s]+)');

      // 3. Extract data
      final String extractedPlate = plateRegEx.firstMatch(fullText)?.group(0) ?? '';
      final String extractedChassis = chassisRegEx.firstMatch(fullText)?.group(0) ?? '';
      final String extractedOwner = ownerRegEx.firstMatch(fullText)?.group(1)?.trim() ?? '';

      // 4. Return the strongly-typed model
      if (extractedPlate.isNotEmpty || extractedChassis.isNotEmpty) {
        return NtsaLogbookData(
          plateNumber: extractedPlate,
          chassisNumber: extractedChassis,
          ownerName: extractedOwner,
        );
      }
      
      return null;
    } catch (e) {
      debugPrint('Error parsing NTSA Logbook: $e');
      return null;
    }
  }

  static void dispose() {
    _textRecognizer.close();
  }
}