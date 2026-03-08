# 🇰🇪 flutter_kenya_ekyc

An optimized, eKYC and identity verification engine. 

This Flutter package handles document scanning, optical character recognition (OCR), passive and active liveness detection, and deep-learning biometric face matching—all running 100% locally on the user's device for maximum privacy and zero latency.

## ✨ Key Features

* 🤖 **Biometric Face Matching:** Extracts a 192-point mathematical facial embedding from the ID card photo and compares it to a live selfie using a custom TFLite `MobileFaceNet` implementation.
* 🛡️ **Anti-Spoofing & Liveness:** Prevents fraud using a dedicated TFLite Anti-Spoofing model (detects printed photos, screens, and masks) combined with an active state-machine liveness check (Turn Left, Turn Right, Blink).

## 📄 Supported Kenyan Documents

Includes precision, regex-backed OCR parsers tailored for:
* **Kenyan National ID** (Front & Back) - Extracts ID Number, Name, Gender, DoB, and District.
* **NTSA Driving License**
* **NTSA Logbook** - Extracts Make, Model, Chassis, and Owner details.
* **PSV Badge**

---

## 🛠️ Setup & Installation

### 1. Asset Configuration
This engine relies on two offline TFLite models for its AI capabilities. You must place these models in your `assets` folder:
* `mobilefacenet.tflite` (For biometric face matching)
* `FaceAntiSpoofing.tflite` (For passive liveness)

Update your `pubspec.yaml` to explicitly declare these models to ensure they are bundled correctly:

```yaml
flutter:
  uses-material-design: true
  assets: 
    - assets/FaceAntiSpoofing.tflite
    - assets/mobilefacenet.tflite
    - assets/
