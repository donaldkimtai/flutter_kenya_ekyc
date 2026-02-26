import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class KenyaIdParser {
  static final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static Future<Map<String, dynamic>> parseDocument(InputImage inputImage) async {
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    String fullText = recognizedText.text;

    final RegExp idRegEx = RegExp(r'\b\d{7,8}\b'); 
    final RegExp dobRegEx = RegExp(r'\d{2}\.\d{2}\.\d{4}|\d{2}/\d{2}/\d{4}'); 
    final RegExp nameRegEx = RegExp(r'(?<=NAME\s)([A-Z\s]+)'); 

    String extractedId = idRegEx.firstMatch(fullText)?.group(0) ?? '';
    String extractedDob = dobRegEx.firstMatch(fullText)?.group(0) ?? '';
    String extractedName = nameRegEx.firstMatch(fullText)?.group(0)?.trim() ?? '';

    return {
      'rawText': fullText,
      'idNumber': extractedId,
      'dateOfBirth': extractedDob,
      'fullName': extractedName,
      'isKenyanId': fullText.toUpperCase().contains('REPUBLIC OF KENYA') || fullText.toUpperCase().contains('IDENTITY CARD'),
    };
  }

  static void dispose() {
    _textRecognizer.close();
  }
}