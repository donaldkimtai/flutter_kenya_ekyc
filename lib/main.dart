import 'package:flutter/material.dart';
import 'ui/camera_detector.dart';

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
      home: const CameraDetector(),
      debugShowCheckedModeBanner: false,
    );
  }
}