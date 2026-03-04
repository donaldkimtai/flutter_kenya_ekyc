import 'package:flutter/material.dart';
import 'flutter_kenya_ekyc.dart'; // Imports the new barrel file

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KenyaIdentityEngineApp());
}

class KenyaIdentityEngineApp extends StatelessWidget {
  const KenyaIdentityEngineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kenyan Identity Engine',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF1A237E), 
      ),
      // Point home to the new Wizard and set a test document type
      home: const EkycWizardView(
        targetDocumentType: KenyanDocumentType.nationalIdFront,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}