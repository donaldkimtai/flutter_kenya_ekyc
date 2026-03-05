import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/psv_insurance_data.dart';

class PsvInsuranceParser {
  static TextRecognizer? _recognizer;

  static void _init() {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
  }

  static Future<PsvInsuranceData?> parse(InputImage image) async {
    _init();
    try {
      final RecognizedText recognized = await _recognizer!.processImage(image);
      final String raw = recognized.text;
      if (raw.isEmpty) return null;

      return PsvInsuranceData(
        policyNumber: _extractPolicyNumber(raw),
        insurerName: _extractInsurerName(raw),
        insuredName: _extractInsuredName(raw),
        vehiclePlate: _extractPlate(raw),
        startDate: _extractDate(raw, isStart: true),
        expiryDate: _extractDate(raw, isStart: false),
      );
    } catch (_) {
      return null;
    }
  }

  static String? _extractPolicyNumber(String text) {
    final regex = RegExp(
        r'(?:PSV|MOT|POLICY\s*N[O0]\.?:?\s*)([A-Z0-9/\-]{6,20})',
        caseSensitive: false);
    return regex.firstMatch(text)?.group(1)?.trim();
  }

  static String? _extractInsurerName(String text) {
    const insurers = [
      'Jubilee Insurance', 'APA Insurance', 'CIC Insurance',
      'Britam Insurance', 'UAP Old Mutual', 'Geminia Insurance',
      'Mayfair Insurance', 'Pacis Insurance', 'Resolution Insurance',
      'Sanlam Insurance', 'Trident Insurance', 'Kenya Orient',
    ];
    final lower = text.toLowerCase();
    for (final name in insurers) {
      if (lower.contains(name.toLowerCase())) return name;
    }
    return null;
  }

  static String? _extractInsuredName(String text) {
    final regex = RegExp(
        r'(?:Insured|Name of Insured|Policy Holder)[:\s]+([A-Z ]{4,40})',
        caseSensitive: false);
    return regex.firstMatch(text)?.group(1)?.trim();
  }

  static String? _extractPlate(String text) {
    final regex = RegExp(r'\b(K[A-Z]{1,2}\s?\d{3}\s?[A-Z])\b',
        caseSensitive: false);
    return regex.firstMatch(text)?.group(1)?.replaceAll(' ', '').toUpperCase();
  }

  static String? _extractDate(String text, {required bool isStart}) {
    final dates = RegExp(r'\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4})\b')
        .allMatches(text)
        .map((m) => m.group(1)!)
        .toList();
    if (dates.isEmpty) return null;
    return isStart ? dates.first : (dates.length > 1 ? dates.last : null);
  }

  static void dispose() {
    _recognizer?.close();
    _recognizer = null;
  }
}