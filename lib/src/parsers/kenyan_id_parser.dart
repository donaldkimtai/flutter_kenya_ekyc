import 'dart:developer' as developer; // FIX: Modern logging standard per Flutter rules
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/kenyan_id_data.dart';

/// A utility class dedicated to extracting Kenyan National ID data using ML Kit.
class KenyaIdParser {
  // Private constructor to prevent instantiation (Utility class pattern)
  KenyaIdParser._();

  static final TextRecognizer _textRecognizer = 
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Scans the provided image and attempts to extract [KenyanIdData].
  /// 
  /// Returns `null` if the document is not recognized as a Kenyan ID 
  /// or if critical fields are missing.
  static Future<KenyanIdData?> parseDocument(InputImage inputImage) async {
    try {
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      final String fullText = recognizedText.text.toUpperCase();

      // 1. Security Check: Is this actually a Kenyan ID?
      if (!fullText.contains('REPUBLIC OF KENYA') && !fullText.contains('IDENTITY CARD')) {
        return null; // Reject the document early
      }

      // 2. RegEx Patterns for specific Kenyan ID fields
      // Matches 7 or 8 consecutive digits (Standard Kenyan ID format)
      final RegExp idRegEx = RegExp(r'\b\d{7,8}\b'); 
      
      // Matches standard Kenyan DOB formats like DD.MM.YYYY or DD/MM/YYYY
      final RegExp dobRegEx = RegExp(r'\d{2}[\.\/]\d{2}[\.\/]\d{4}'); 
      
      // Looks for a string of uppercase letters appearing shortly after "NAME" or "FULL NAME"
      final RegExp nameRegEx = RegExp(r'(?:NAME|FULL NAME)[\s\n]*([A-Z\s]+)'); 

      // 3. Extract the data using the patterns
      final String extractedId = idRegEx.firstMatch(fullText)?.group(0) ?? '';
      final String extractedDob = dobRegEx.firstMatch(fullText)?.group(0) ?? '';
      
      // Clean up the name by grabbing the first matched group and trimming whitespace
      final String extractedName = nameRegEx.firstMatch(fullText)?.group(1)?.trim() ?? '';

      // 4. Validate and return the strongly-typed model
      if (extractedId.isNotEmpty) {
        return KenyanIdData(
          idNumber: extractedId,
          fullName: extractedName,
          dateOfBirth: extractedDob,
        );
      }
      
      return null;
    } catch (e, stackTrace) {
      // Used structured logging instead of print/debugPrint
      developer.log(
        'Error parsing Kenyan ID',
        name: 'flutter_kenya_ekyc.parser',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Closes the ML Kit recognizer to free up device memory.
  static void dispose() {
    _textRecognizer.close();
  }
}