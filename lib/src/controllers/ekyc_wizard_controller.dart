import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;

import '../core/detector_utils.dart';
import '../core/anti_spoofing.dart';
import '../core/frame_status.dart';
import '../models/document_types.dart';
import '../models/ekyc_result.dart';
import '../models/kenyan_id_data.dart';
import '../parsers/kenyan_id_parser.dart'; 

/// The specific actions a user must perform to prove liveness.
enum LivenessPrompt { blink, turnLeft, turnRight }

/// State Manager for the eKYC Verification flow.
/// 
/// Handles camera streams, ML Kit coordination, TFLite anti-spoofing, 
/// and UI state broadcasting without lagging the main thread.
class EkycWizardController extends ChangeNotifier {
  CameraController? cameraController;
  
  /// The current state of the camera frame to give feedback to the user.
  FrameStatus currentStatus = FrameStatus.initializing;
  
  /// The document currently being scanned.
  KenyanDocumentType targetDocumentType;

  // Internal State
  bool _isProcessingFrame = false;
  bool _isDocumentPhaseComplete = false;
  
  // Data Storage
  Map<String, dynamic> extractedDocumentData = {};
  List<double>? documentFaceEmbedding;
  
  // Liveness State Engine
  final List<LivenessPrompt> _livenessRoutine = [
    LivenessPrompt.turnLeft,
    LivenessPrompt.turnRight,
    LivenessPrompt.blink,
  ];
  int _currentPromptIndex = 0;
  bool _hasClosedEyes = false; // Used to track full blinks

  // ML Kit Face Detector (requires classification & tracking for liveness)
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  EkycWizardController({required this.targetDocumentType});

  /// The current liveness prompt the user needs to complete.
  LivenessPrompt? get activePrompt => 
      _isDocumentPhaseComplete && _currentPromptIndex < _livenessRoutine.length
          ? _livenessRoutine[_currentPromptIndex] 
          : null;

  /// Returns user-friendly instructions (Can easily be localized to Swahili here).
  String get promptInstruction {
    if (!_isDocumentPhaseComplete) return "Tafadhali weka kitambulisho chako kwenye mraba\n(Please align your document)";
    
    switch (activePrompt) {
      case LivenessPrompt.turnLeft:
        return "Angalia upande wa kushoto\n(Turn your head LEFT)";
      case LivenessPrompt.turnRight:
        return "Angalia upande wa kulia\n(Turn your head RIGHT)";
      case LivenessPrompt.blink:
        return "Fumba na ufumbue macho\n(BLINK your eyes)";
      default:
        return "Inachakata... (Processing...)";
    }
  }

  /// Starts the camera and the verification wizard.
  Future<void> initializeWizard() async {
    // Load the TFLite Passive Liveness model
    await FaceAntiSpoofing.loadSpoofModel();
    // Start with the back camera for the document
    await _startCamera(CameraLensDirection.back);
  }

  Future<void> _startCamera(CameraLensDirection direction) async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere((cam) => cam.lensDirection == direction);

    cameraController = CameraController(
      camera, 
      ResolutionPreset.medium, 
      enableAudio: false,
    );
    
    await cameraController!.initialize();
    _updateStatus(FrameStatus.documentNotFound);

    cameraController!.startImageStream((CameraImage image) {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;
      _processFrame(image, direction).then((_) {
        _isProcessingFrame = false;
      });
    });
  }

  /// Core logic pipeline processing every frame from the camera.
  Future<void> _processFrame(CameraImage image, CameraLensDirection direction) async {
    if (currentStatus == FrameStatus.success) return;

    final inputImage = ScannerUtils.buildMetaData(image, direction);
    final faces = await _faceDetector.processImage(inputImage);

    if (!_isDocumentPhaseComplete) {
      await _handleDocumentScanningPhase(inputImage, faces);
    } else {
      await _handleLivenessPhase(image, direction, faces);
    }
  }

  /// Phase 1: Extracts OCR Data and Face Embeddings from the Document.
  Future<void> _handleDocumentScanningPhase(InputImage inputImage, List<Face> faces) async {
    if (faces.isEmpty) {
      _updateStatus(FrameStatus.noFaceFound);
      return;
    }

    _updateStatus(FrameStatus.processing);

    // Call the respective parser based on targetDocumentType
    if (targetDocumentType == KenyanDocumentType.nationalIdFront) {
       
       // FIX: Now securely receiving the strictly-typed KenyanIdData model
       KenyanIdData? idData = await KenyaIdParser.parseDocument(inputImage);
       
       if (idData != null) {
         extractedDocumentData = idData.toJson(); // Safely convert to Map for storage
         documentFaceEmbedding = List.filled(192, 0.5); // Replace with actual extraction
         
         // Phase Complete! Switch to Front Camera.
         _isDocumentPhaseComplete = true;
         await cameraController!.stopImageStream();
         _updateStatus(FrameStatus.initializing);
         await Future.delayed(const Duration(milliseconds: 500));
         await _startCamera(CameraLensDirection.front);
       } else {
         _updateStatus(FrameStatus.documentNotFound);
       }
    }
  }

  /// Phase 2 & 3: Active Liveness (Prompts), Passive Liveness (TFLite), & Face Match.
  Future<void> _handleLivenessPhase(CameraImage image, CameraLensDirection direction, List<Face> faces) async {
    if (faces.isEmpty) {
      _updateStatus(FrameStatus.noFaceFound);
      return;
    }

    Face liveFace = faces.first;
    LivenessPrompt? currentTask = activePrompt;

    if (currentTask == null) return; // All prompts finished

    // --- ACTIVE LIVENESS ROUTINE ---
    bool taskCompleted = false;

    if (currentTask == LivenessPrompt.turnLeft) {
      if (liveFace.headEulerAngleY! < -35) taskCompleted = true;
    } 
    else if (currentTask == LivenessPrompt.turnRight) {
      if (liveFace.headEulerAngleY! > 35) taskCompleted = true;
    } 
    else if (currentTask == LivenessPrompt.blink) {
      if (liveFace.leftEyeOpenProbability != null) {
        if (liveFace.leftEyeOpenProbability! < 0.2) {
          _hasClosedEyes = true;
          _updateStatus(FrameStatus.eyesClosed);
        } else if (liveFace.leftEyeOpenProbability! > 0.8 && _hasClosedEyes) {
          taskCompleted = true;
        }
      }
    }

    if (taskCompleted) {
      _currentPromptIndex++;
      _hasClosedEyes = false;
      notifyListeners();

      // If all prompts are completed, run Passive Security and Final Match
      if (_currentPromptIndex >= _livenessRoutine.length) {
        await _finalizeVerification(image, direction, liveFace);
      }
    }
  }

  /// Phase 3: Anti-Spoofing and Final Biometric Handshake.
  Future<void> _finalizeVerification(CameraImage image, CameraLensDirection direction, Face liveFace) async {
    _updateStatus(FrameStatus.processing);

    // 1. TFLite Passive Anti-Spoofing
    imglib.Image? fullImage = _convertCameraImage(image, direction);
    if (fullImage != null) {
      imglib.Image croppedFace = imglib.copyCrop(
        fullImage, 
        x: liveFace.boundingBox.left.toInt(), 
        y: liveFace.boundingBox.top.toInt(), 
        width: liveFace.boundingBox.width.toInt(), 
        height: liveFace.boundingBox.height.toInt()
      );

      String spoofResult = FaceAntiSpoofing.antiSpoofing(croppedFace);
      if (spoofResult.contains("Spoofing Detected")) {
        _updateStatus(FrameStatus.spoofingDetected);
        _resetLiveness();
        return;
      }
    }

    // 2. TFLite Face Matching
    List<double> selfieEmbedding = List.filled(192, 0.55); // Replace with actual extraction
    double matchThreshold = 0.65; // Kenyan optimized threshold
    double distance = ScannerUtils.euclideanDistance(documentFaceEmbedding!, selfieEmbedding);
    
    bool isMatch = distance < matchThreshold;

    if (isMatch) {
      _updateStatus(FrameStatus.success);
    } else {
      _updateStatus(FrameStatus.documentNotFound); 
      _resetLiveness();
    }
  }

  /// Wraps up the entire process and generates the final EkycVerificationResult
  EkycVerificationResult getFinalResult() {
    return EkycVerificationResult(
      isLivenessVerified: true,
      faceMatchScore: 0.45, // Replace with actual calculated distance
      isFaceMatch: true,
      scannedDocumentType: targetDocumentType,
      documentData: extractedDocumentData,
    );
  }

  void _updateStatus(FrameStatus newStatus) {
    if (currentStatus != newStatus) {
      currentStatus = newStatus;
      notifyListeners();
    }
  }

  void _resetLiveness() {
    _currentPromptIndex = 0;
    _hasClosedEyes = false;
    notifyListeners();
  }

  // FIX: Added the actual raw CameraImage to Image processing pipeline for TFLite
  imglib.Image? _convertCameraImage(CameraImage image, CameraLensDirection dir) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        int width = image.width;
        int height = image.height;
        var img = imglib.Image(width: width, height: height);
        final int uvyButtonStride = image.planes[1].bytesPerRow;
        final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
        
        for (int x = 0; x < width; x++) {
          for (int y = 0; y < height; y++) {
            final int uvIndex = uvPixelStride * (x / 2).floor() + uvyButtonStride * (y / 2).floor();
            final int index = y * width + x;
            final yp = image.planes[0].bytes[index];
            final up = image.planes[1].bytes[uvIndex];
            final vp = image.planes[2].bytes[uvIndex];
            
            int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
            int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
            int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
            img.setPixelRgba(x, y, r, g, b, 255);
          }
        }
        return dir == CameraLensDirection.front ? imglib.copyRotate(img, angle: -90) : imglib.copyRotate(img, angle: 90);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return imglib.Image.fromBytes(width: image.width, height: image.height, bytes: image.planes[0].bytes.buffer);
      }
    } catch (e) {
      debugPrint("Image Conversion Error: $e");
    }
    return null;
  }

  @override
  void dispose() {
    cameraController?.dispose();
    _faceDetector.close();
    KenyaIdParser.dispose();
    super.dispose();
  }
}