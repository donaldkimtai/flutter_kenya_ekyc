# Flutter Kenya eKYC

[![pub package](https://img.shields.io/pub/v/flutter_kenya_ekyc.svg)](https://pub.dev/packages/flutter_kenya_ekyc)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Modern offline Kenyan Identity Engine using Google ML Kit and MobileFaceNet for secure, fast, and reliable electronic Know Your Customer (eKYC) verification.

## 📋 Overview

Flutter Kenya eKYC is a comprehensive Flutter package designed specifically for Kenyan identity verification needs. It provides offline-first biometric verification and document recognition capabilities, making it perfect for financial services, telecom, lending platforms, and government services in Kenya.

### Key Features

- 🎯 **Offline-First Architecture** - All processing happens on-device, no cloud dependency
- 📱 **Document Capture & OCR** - Automatically detect and extract data from Kenyan National IDs
- 👤 **Facial Recognition** - MobileFaceNet-powered face matching and liveness detection
- 🚀 **Fast & Efficient** - Optimized for mobile devices with low latency
- 🔒 **Privacy-Focused** - Data stays on device, compliant with data protection regulations
- 🎨 **Customizable UI** - Flexible components that match your app's design
- 📄 **Multiple Document Support** - National ID, Passport, and other Kenyan identity documents

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android: minSdkVersion 21 or higher
- iOS: iOS 12.0 or higher

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_kenya_ekyc: ^1.0.0
```

Then run:

```bash
flutter pub get
```

### Platform Setup

#### Android

Add the following permissions to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

#### iOS

Add the following to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for identity verification</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is needed to select identity documents</string>
```

## 💡 Usage

### Basic Implementation

```dart
import 'package:flutter_kenya_ekyc/flutter_kenya_ekyc.dart';

class IdentityVerification extends StatefulWidget {
  @override
  _IdentityVerificationState createState() => _IdentityVerificationState();
}

class _IdentityVerificationState extends State<IdentityVerification> {
  final KenyaEkyc _ekyc = KenyaEkyc();

  Future<void> startVerification() async {
    try {
      // Initialize the eKYC engine
      await _ekyc.initialize();
      
      // Start document capture
      final idResult = await _ekyc.captureNationalId();
      
      // Capture user's face
      final faceResult = await _ekyc.captureFace();
      
      // Verify face matches ID photo
      final matchResult = await _ekyc.verifyFaceMatch(
        idPhoto: idResult.photo,
        capturedFace: faceResult.image,
      );
      
      if (matchResult.isMatch) {
        print('Verification successful!');
        print('Confidence: ${matchResult.confidence}%');
      }
    } catch (e) {
      print('Verification failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Identity Verification')),
      body: Center(
        child: ElevatedButton(
          onPressed: startVerification,
          child: Text('Start Verification'),
        ),
      ),
    );
  }
}
```

### Document Scanning

```dart
// Scan Kenyan National ID
final idData = await _ekyc.scanNationalId();
print('ID Number: ${idData.idNumber}');
print('Full Name: ${idData.fullName}');
print('Date of Birth: ${idData.dateOfBirth}');
print('Gender: ${idData.gender}');

// Scan Passport
final passportData = await _ekyc.scanPassport();
print('Passport Number: ${passportData.passportNumber}');
```

### Face Verification with Liveness Detection

```dart
// Capture face with liveness detection
final livenessResult = await _ekyc.performLivenessCheck(
  instructions: LivenessInstructions(
    requireBlink: true,
    requireSmile: true,
    requireTurnHead: true,
  ),
);

if (livenessResult.isPassed) {
  print('Liveness check passed');
  final faceImage = livenessResult.capturedImage;
  
  // Compare with ID photo
  final matchScore = await _ekyc.compareFaces(
    face1: idPhoto,
    face2: faceImage,
  );
  
  print('Match score: ${matchScore.similarity}%');
}
```

### Advanced Configuration

```dart
// Configure eKYC settings
await _ekyc.configure(
  EkycConfig(
    documentDetectionConfidence: 0.8,
    faceMatchThreshold: 0.85,
    livenessThreshold: 0.9,
    enableDebugMode: false,
    language: 'en', // or 'sw' for Swahili
  ),
);
```

## 🏗️ Architecture

### Technology Stack

- **Google ML Kit**: Powers text recognition (OCR) for extracting data from identity documents
- **MobileFaceNet**: Lightweight neural network optimized for mobile face recognition
- **Flutter**: Cross-platform framework for iOS and Android
- **Native Camera Integration**: Direct access to device camera for real-time processing

### Processing Flow

1. **Document Capture**: Camera captures ID/passport with auto-focus and boundary detection
2. **OCR Processing**: ML Kit extracts text fields (name, ID number, DOB, etc.)
3. **Data Validation**: Extracted data is validated against Kenyan ID formats
4. **Face Capture**: High-quality face photo captured with liveness detection
5. **Face Comparison**: MobileFaceNet generates embeddings and compares faces
6. **Result Generation**: Confidence scores and verification status returned

## 🎯 Use Cases

### Financial Services
- Bank account opening and KYC compliance
- Mobile money wallet registration
- Loan application processing
- Insurance policy registration

### Telecommunications
- SIM card registration (meeting regulatory requirements)
- Mobile number porting verification
- Device financing identity checks

### Government Services
- Digital service access verification
- Benefits enrollment
- Voter registration support

### E-Commerce & Gig Economy
- Seller/driver verification
- Age verification for restricted products
- Payment account setup

## 📊 Performance

- **Document Scan**: < 2 seconds
- **Face Capture**: < 1 second
- **Face Matching**: < 0.5 seconds
- **Total Verification Flow**: < 10 seconds
- **Offline Operation**: 100% (no internet required)

## 🔐 Security & Privacy

- All processing happens on-device (offline-first)
- No biometric data transmitted over network
- Compliant with Kenya Data Protection Act
- Face embeddings are not reversible to original images
- Optional encryption for stored verification results
- GDPR-ready data handling

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure your code follows the existing style and includes appropriate tests.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Google ML Kit team for the powerful OCR capabilities
- MobileFaceNet authors for the efficient face recognition model
- Kenyan fintech community for feedback and requirements
- Flutter team for the amazing framework

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/donaldkimtai/flutter_kenya_ekyc/issues)
- **Discussions**: [GitHub Discussions](https://github.com/donaldkimtai/flutter_kenya_ekyc/discussions)
- **Documentation**: [Wiki](https://github.com/donaldkimtai/flutter_kenya_ekyc/wiki)

## 🗺️ Roadmap

- [ ] Support for Kenyan Alien ID cards
- [ ] Integration with IPRS (Integrated Population Registration System)
- [ ] Multi-language support (English, Swahili, and local languages)
- [ ] Enhanced liveness detection algorithms
- [ ] Document authenticity verification (hologram detection)
- [ ] Cloud backup option for verification results
- [ ] React Native bridge for cross-platform support

## ⚖️ Legal & Compliance

This package is designed to help applications comply with:
- Kenya's Data Protection Act, 2019
- Central Bank of Kenya KYC requirements
- Communications Authority of Kenya SIM registration regulations
- Anti-Money Laundering regulations

**Disclaimer**: Users are responsible for ensuring their implementation complies with all applicable laws and regulations. This package is a tool and does not constitute legal advice.

---

Made with ❤️ in Kenya 🇰🇪
