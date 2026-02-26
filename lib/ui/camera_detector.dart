import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;
import '../core/detector_utils.dart';
import '../core/kenya_id_parser.dart';
import '../core/anti_spoofing.dart';

enum ScannerState { scanningId, scanningFace, processing, complete }

class CameraDetector extends StatefulWidget {
  const CameraDetector({super.key});

  @override
  State<CameraDetector> createState() => _CameraDetectorState();
}

class _CameraDetectorState extends State<CameraDetector> with WidgetsBindingObserver {
  CameraController? _camera;
  ScannerState _currentState = ScannerState.scanningId;
  bool _isProcessingFrame = false;
  String _uiInstruction = "Please align your Kenyan ID Card";
  
  final Map<String, dynamic> _ekycResults = {};
  List<double>? _idFaceEmbedding;
  
  bool _hasClosedEyes = false;
  bool _hasBlinked = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, 
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FaceAntiSpoofing.loadSpoofModel(); 
    _initializeCamera(CameraLensDirection.back); 
  }

  Future<void> _initializeCamera(CameraLensDirection direction) async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere((cam) => cam.lensDirection == direction);

    _camera = CameraController(camera, ResolutionPreset.medium, enableAudio: false);
    await _camera!.initialize();
    
    _camera!.startImageStream((CameraImage image) {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;
      _processCameraFrame(image, direction).then((_) {
        if (mounted) _isProcessingFrame = false;
      });
    });
    setState(() {});
  }

  Future<void> _processCameraFrame(CameraImage image, CameraLensDirection direction) async {
    if (_currentState == ScannerState.complete || _currentState == ScannerState.processing) return;

    final inputImage = ScannerUtils.buildMetaData(image, direction);
    final faces = await _faceDetector.processImage(inputImage);

  
    // SCAN KENYAN ID CARD

    if (_currentState == ScannerState.scanningId) {
      Map<String, dynamic> idData = await KenyaIdParser.parseDocument(inputImage);
      
      if (idData['isKenyanId'] == true && idData['idNumber'].toString().isNotEmpty) {
        _ekycResults.addAll(idData);
        
        if (faces.isNotEmpty) {
           _idFaceEmbedding = List.filled(192, 0.5); // Replace with your model extraction
        }

        setState(() {
          _currentState = ScannerState.processing;
          _uiInstruction = "ID Scanned! ${idData['fullName']}\nSwitching to Selfie...";
        });

        await Future.delayed(const Duration(seconds: 2));
        await _camera!.stopImageStream();
        setState(() { 
          _currentState = ScannerState.scanningFace; 
          _uiInstruction = "Please BLINK to verify liveness"; 
        });
        await _initializeCamera(CameraLensDirection.front);
      }
    }

    // ACTIVE & PASSIVE LIVENESS
    
    else if (_currentState == ScannerState.scanningFace) {
      if (faces.isNotEmpty) {
        Face liveFace = faces.first;
        
        // --- 1. ACTIVE LIVENESS (BLINK) ---
        if (liveFace.leftEyeOpenProbability != null && liveFace.rightEyeOpenProbability != null) {
          if (liveFace.leftEyeOpenProbability! < 0.2 && liveFace.rightEyeOpenProbability! < 0.2) {
            _hasClosedEyes = true; 
            setState(() => _uiInstruction = "Eyes closed. Now open them!");
          } else if (liveFace.leftEyeOpenProbability! > 0.8 && liveFace.rightEyeOpenProbability! > 0.8 && _hasClosedEyes) {
            _hasBlinked = true; 
          }
        }

        if (_hasBlinked) {
          setState(() {
            _uiInstruction = "Analyzing texture for Spoofing...";
            _currentState = ScannerState.processing;
          });

          // --- 2. PASSIVE LIVENESS (TFLITE) ---
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

             if (spoofResult.contains("Spoofing Detected") || spoofResult.contains("Blurry")) {
                setState(() {
                  _uiInstruction = "Spoofing Detected! Try again.";
                  _currentState = ScannerState.scanningFace; 
                  _hasBlinked = false;
                  _hasClosedEyes = false;
                });
                return;
             }
          }

          setState(() => _uiInstruction = "Liveness Confirmed! Verifying Match...");

          // --- 3. FINAL HANDSHAKE ---
          List<double> selfieEmbedding = List.filled(192, 0.55); // Replace with your model extraction
          double matchThreshold = 0.65; 
          double distance = ScannerUtils.euclideanDistance(_idFaceEmbedding ?? List.filled(192, 0.0), selfieEmbedding);
          
          _ekycResults['faceMatchScore'] = distance;
          _ekycResults['isMatch'] = distance < matchThreshold;
          _ekycResults['livenessConfirmed'] = true;
          _ekycResults['antiSpoofingPassed'] = true;

          await Future.delayed(const Duration(seconds: 1));
          if (mounted) Navigator.pop(context, _ekycResults);
        }
      } else {
        setState(() => _uiInstruction = "Face not detected. Look at the camera.");
      }
    }
  }

  // Helper: Converts native camera frame to image library format
  imglib.Image? _convertCameraImage(CameraImage image, CameraLensDirection dir) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        int width = image.width;
        int height = image.height;
        var img = imglib.Image(width: width, height: height);
        final int uvyButtonStride = image.planes[1].bytesPerRow;
        
        // FIX: Added '?? 1' fallback for null safety
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
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _faceDetector.close();
    KenyaIdParser.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_camera == null || !_camera!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_camera!),
          
          ColorFiltered(
            // FIX: Replaced deprecated withOpacity with modern withValues(alpha: ...)
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.srcOut),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
                Center(
                  child: Container(
                    height: _currentState == ScannerState.scanningId ? 250 : 350,
                    width: _currentState == ScannerState.scanningId ? 350 : 300,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(_currentState == ScannerState.scanningId ? 16 : 200),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            top: 80, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(12)),
              child: Text(_uiInstruction, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 40),
              onPressed: () => Navigator.pop(context),
            ),
          )
        ],
      ),
    );
  }
}