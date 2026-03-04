import 'package:flutter/material.dart';
import 'flutter_kenya_ekyc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _EkycTestApp());
}

/// Standalone test harness for the eKYC engine.

class _EkycTestApp extends StatelessWidget {
  const _EkycTestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kenya eKYC Engine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF1A237E),
      ),
      home: const _TestLauncherScreen(),
    );
  }
}

class _TestLauncherScreen extends StatefulWidget {
  const _TestLauncherScreen();

  @override
  State<_TestLauncherScreen> createState() => _TestLauncherScreenState();
}

class _TestLauncherScreenState extends State<_TestLauncherScreen> {
  EkycVerificationResult? _lastResult;
  KenyanDocumentType _selected = KenyanDocumentType.nationalIdFront;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kenya eKYC — Test Launcher')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select document type:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<KenyanDocumentType>(
              value: _selected,
              isExpanded: true,
              items: KenyanDocumentType.values
                  .map((t) => DropdownMenuItem(
                      value: t, child: Text(t.name)))
                  .toList(),
              onChanged: (v) => setState(() => _selected = v!),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Launch eKYC Wizard'),
              onPressed: () async {
                final result = await EkycService.launch(
                  context,
                  documentType: _selected,
                  // riderId: FirebaseAuth.instance.currentUser!.uid,
                  // uploadToFirebase: true,
                );
                setState(() => _lastResult = result);
              },
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 8),
              Text('Decision: ${_lastResult!.decision.name}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                  'Liveness: ${_lastResult!.isLivenessVerified}'),
              Text(
                  'Face match: ${_lastResult!.isFaceMatch}'),
              Text(
                  'Match score: ${_lastResult!.faceMatchScore?.toStringAsFixed(3) ?? 'N/A'}'),
              Text(
                  'Document: ${_lastResult!.scannedDocumentType?.name}'),
              Text('Verified at: ${_lastResult!.verifiedAt}'),
              const SizedBox(height: 8),
              Text('Document data:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(_lastResult!.documentData?.toString() ?? 'none'),
            ],
          ],
        ),
      ),
    );
  }
}