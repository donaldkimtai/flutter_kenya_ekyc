import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;

import '../core/face_net.dart';
import '../core/detector_utils.dart';
import '../core/anti_spoofing.dart';
import '../core/frame_status.dart';
import '../models/document_types.dart';
import '../models/ekyc_result.dart';
import '../models/kenyan_id_data.dart';
import '../models/ntsa_logbook_data.dart';
import '../models/psv_badge_data.dart';
import '../models/driving_license_data.dart';
import '../parsers/kenyan_id_parser.dart';
import '../parsers/logbook_parser.dart';
import '../parsers/psv_badge_parser.dart';
import '../parsers/driving_license_parser.dart';

// ============================================================================
// TOP-LEVEL ISOLATE FUNCTION — must be top-level (not a class member)
// ============================================================================
imglib.Image? convertCameraImageIsolate(Map<String, dynamic> params) {
  try {
    final int width = params['width'] as int;
    final int height = params['height'] as int;
    final String format = params['format'] as String;
    final String dir = params['dir'] as String;
    final Uint8List yPlane = params['y_plane'] as Uint8List? ?? Uint8List(0);

    if (format == 'yuv') {
      // FIX: Safe null fallbacks for bytesPerRow / bytesPerPixel which are
      // nullable on some MediaTek / low-end Android devices.
      final Uint8List uPlane =
          params['u_plane'] as Uint8List? ?? Uint8List(0);
      final Uint8List vPlane =
          params['v_plane'] as Uint8List? ?? Uint8List(0);
      final int uvRowStride = params['uv_stride'] as int? ?? width ~/ 2;
      final int uvPixelStride = params['uv_pixel_stride'] as int? ?? 1;

      final img = imglib.Image(width: width, height: height);
      final bool hasUV = uPlane.isNotEmpty && vPlane.isNotEmpty;

      for (int x = 0; x < width; x++) {
        for (int y = 0; y < height; y++) {
          final int index = y * width + x;
          if (index >= yPlane.length) continue;

          final int yp = yPlane[index];
          int up = 128;
          int vp = 128;

          if (hasUV) {
            final int uvIndex =
                uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
            if (uvIndex < uPlane.length && uvIndex < vPlane.length) {
              up = uPlane[uvIndex];
              vp = vPlane[uvIndex];
            }
          }

          final int r = (yp + (vp * 1436 ~/ 1024) - 179).clamp(0, 255);
          final int g = (yp -
                  (up * 46549 ~/ 131072) +
                  44 -
                  (vp * 93604 ~/ 131072) +
                  91)
              .clamp(0, 255);
          final int b = (yp + (up * 1814 ~/ 1024) - 227).clamp(0, 255);
          img.setPixelRgba(x, y, r, g, b, 255);
        }
      }
      return dir == 'front'
          ? imglib.copyRotate(img, angle: -90)
          : imglib.copyRotate(img, angle: 90);
    } else if (format == 'bgra') {
      return imglib.Image.fromBytes(
          width: width, height: height, bytes: yPlane.buffer);
    }
  } catch (e) {
    debugPrint('[Isolate] Conversion error: $e');
  }
  return null;
}
// ============================================================================

/// The three liveness challenges presented in sequence.
enum LivenessPrompt { turnLeft, turnRight, blink }

/// Orchestrates the full eKYC flow:
/// 1. Document scan (back camera) → OCR → extract face embedding
/// 2. Camera switch to front
/// 3. Liveness prompts (turn left, turn right, blink)
/// 4. Anti-spoofing check
/// 5. Face match (selfie vs document)
/// 6. Final [EkycVerificationResult]
class EkycWizardController extends ChangeNotifier {
  // ── Public state (read by the View) ──────────────────────────────────────

  CameraController? cameraController;
  FrameStatus currentStatus = FrameStatus.initializing;
  KenyanDocumentType targetDocumentType;

  bool isFinalizing = false;

  bool get isSwitchingCamera => _isSwitchingCamera;
  bool get isDocumentPhaseComplete => _isDocumentPhaseComplete;

  /// Progress from 0.0 → 1.0 as liveness prompts are completed.
  double get livenessProgress => _isDocumentPhaseComplete
      ? (_currentPromptIndex / _livenessRoutine.length)
      : 0.0;

  // ── Private state ─────────────────────────────────────────────────────────

  bool _isProcessingFrame = false;
  bool _isDocumentPhaseComplete = false;
  bool _isSwitchingCamera = false;
  bool _isDisposed = false;

  // Exposed so the View can show a friendly error screen
  String? cameraError;

  Map<String, dynamic> _extractedDocumentData = {};
  List<double>? _documentFaceEmbedding;

  // Liveness routine state
  final List<LivenessPrompt> _livenessRoutine = [
    LivenessPrompt.turnLeft,
    LivenessPrompt.turnRight,
    LivenessPrompt.blink,
  ];
  int _currentPromptIndex = 0;
  bool _hasClosedEyes = false;

  // Timeout: rider gets 60 seconds to complete liveness before manual review
  static const Duration _livenessTimeout = Duration(seconds: 60);
  Timer? _livenessTimer;

  // FIX: Frame throttle — on TECNO/MediaTek devices the ImageReader buffer
  // fills faster than ML Kit can process, causing IllegalArgumentException spam.
  // We enforce a minimum gap of 400ms between processed frames.
  // 600ms throttle = max ~1.6 fps fed to ML Kit, well within MediaTek limits
  static const Duration _frameThrottle = Duration(milliseconds: 600);
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Result fields
  VerificationDecision _finalDecision = VerificationDecision.rejected;
  double _finalMatchScore = 0.0;
  bool _finalIsFaceMatch = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // needed for eye open probability
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  EkycWizardController({required this.targetDocumentType});

  // ── Computed getters ──────────────────────────────────────────────────────

  LivenessPrompt? get activePrompt =>
      _isDocumentPhaseComplete &&
              _currentPromptIndex < _livenessRoutine.length
          ? _livenessRoutine[_currentPromptIndex]
          : null;

  String get promptInstruction {
    if (!_isDocumentPhaseComplete) {
      return _docScanPrompt();
    }
    switch (activePrompt) {
      case LivenessPrompt.turnLeft:
        return 'Angalia upande wa kushoto\n(Turn your head LEFT)';
      case LivenessPrompt.turnRight:
        return 'Angalia upande wa kulia\n(Turn your head RIGHT)';
      case LivenessPrompt.blink:
        return 'Fumba na ufumbue macho\n(BLINK your eyes)';
      default:
        return 'Inachakata...\n(Processing...)';
    }
  }

  String _docScanPrompt() {
    switch (targetDocumentType) {
      case KenyanDocumentType.ntsaLogbook:
        return 'Weka Logbook kwenye mraba\n(Align Logbook in frame)';
      case KenyanDocumentType.drivingLicense:
        return 'Weka Leseni kwenye mraba\n(Align Driving Licence in frame)';
      case KenyanDocumentType.psvBadge:
        return 'Weka Beji ya PSV kwenye mraba\n(Align PSV Badge in frame)';
      case KenyanDocumentType.psvInsurance:
        return 'Weka Hati ya Bima ya PSV kwenye mraba\n(Align PSV Insurance in frame)';
      case KenyanDocumentType.nationalIdFront:
      case KenyanDocumentType.nationalIdBack:
        return 'Weka Kitambulisho kwenye mraba\n(Align your ID in frame)';
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Call this once from [State.initState] of the wizard view.
  Future<void> initializeWizard() async {
    await FaceAntiSpoofing.loadSpoofModel();
    await FaceNetService.loadModel();
    await _startCamera(CameraLensDirection.back);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _livenessTimer?.cancel();

    // FIX: Stop stream before disposing to prevent "stream already listened"
    // crashes when the user taps close mid-frame.
    _stopStreamSafely().then((_) {
      cameraController?.dispose();
    });

    _faceDetector.close();
    KenyaIdParser.dispose();
    LogbookParser.dispose();
    PsvBadgeParser.dispose();
    DrivingLicenseParser.dispose();
    FaceNetService.close();
    FaceAntiSpoofing.dispose();
    super.dispose();
  }

  // ── Camera management ─────────────────────────────────────────────────────

  Future<void> _startCamera(CameraLensDirection direction) async {
    if (_isDisposed) return;

    if (cameraController != null) {
      _isSwitchingCamera = true;
      _safeNotify();

      await _stopStreamSafely();
      await Future.delayed(const Duration(milliseconds: 300));

      try {
        await cameraController!.dispose();
      } catch (_) {}
      cameraController = null;

      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (_isDisposed) return;

    final cameras = await availableCameras();
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == direction,
      orElse: () => cameras.first,
    );

    // FIX: Use 'low' (320x240) on Android to prevent native ImageReader buffer
    // overflow on MediaTek devices (TECNO, Infinix, etc.). The camera HAL only
    // allocates 1-2 buffer slots at low resolution, eliminating the
    // "RunningBehind + IllegalArgumentException" spam that persists even with
    // Dart-level throttling because the error fires in the Java camera layer
    // before our Dart callback even runs.
    // iOS uses medium since it handles backpressure correctly.
    final ResolutionPreset preset =
        Platform.isAndroid ? ResolutionPreset.low : ResolutionPreset.medium;

    cameraController = CameraController(
      camera,
      preset,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    // FIX: Catch sensor privacy / permission errors gracefully.
    // TECNO/Infinix devices can have a hardware privacy switch that blocks the camera.
    try {
      await cameraController!.initialize();
    } on CameraException catch (e) {
      cameraError = (e.description?.contains('sensor privacy') == true ||
                     e.code == 'CameraAccessException')
          ? 'Camera blocked.\n\nGo to Settings → Privacy → Camera\nand enable camera access for this app,\nthen reopen the screen.'
          : 'Camera error: ${e.description ?? e.code}';
      cameraController = null;
      _isSwitchingCamera = false;
      _safeNotify();
      return;
    }

    if (_isDisposed) return;

    cameraError = null;
    _updateStatus(_isDocumentPhaseComplete
        ? FrameStatus.noFaceFound
        : FrameStatus.documentNotFound);

    _isSwitchingCamera = false;
    _safeNotify();

    // Start liveness timeout once the front camera is live
    if (direction == CameraLensDirection.front) {
      _startLivenessTimeout();
    }

    cameraController!.startImageStream((CameraImage image) {
  
      final DateTime now = DateTime.now();
      if (now.difference(_lastFrameTime) < _frameThrottle) return;
      if (_isProcessingFrame || _isDisposed) return;
      _lastFrameTime = now;
      _isProcessingFrame = true;
      _processFrame(image, camera).whenComplete(() {
        _isProcessingFrame = false;
      });
    });
  }

  Future<void> _stopStreamSafely() async {
    try {
      if (cameraController?.value.isStreamingImages == true) {
        await cameraController!.stopImageStream();
      }
    } catch (_) {}
  }

  // ── Frame processing ──────────────────────────────────────────────────────

  Future<void> _processFrame(
      CameraImage image, CameraDescription camera) async {
    if (currentStatus == FrameStatus.success || _isDisposed) return;

    // FIX: Pass actual sensor orientation from CameraDescription instead of
    // hardcoded 270/90 which was wrong for iOS and landscape mode.
    final InputImage? inputImage = ScannerUtils.buildMetaData(
      image,
      camera.lensDirection,
      camera.sensorOrientation,
    );
    if (inputImage == null) return;

    if (!_isDocumentPhaseComplete) {
      await _handleDocumentPhase(inputImage, image, camera);
    } else {
      final faces = await _faceDetector.processImage(inputImage);
      // FIX: schedule UI update on main thread instead of calling
      // notifyListeners() directly from the image stream callback thread.
      await _handleLivenessPhase(image, camera, faces);
    }
  }

  // ── Document scanning phase ───────────────────────────────────────────────

  Future<void> _handleDocumentPhase(
    InputImage inputImage,
    CameraImage image,
    CameraDescription camera,
  ) async {
    _updateStatus(FrameStatus.processing);

    Map<String, dynamic>? docData;

    // FIX: Handle ALL document types — previously only nationalIdFront
    // was handled, all others fell through silently to documentNotFound.
    switch (targetDocumentType) {
      case KenyanDocumentType.nationalIdFront:
      case KenyanDocumentType.nationalIdBack:
      case KenyanDocumentType.drivingLicense:
        // Driving licence shares the same ID parser (similar layout)
        final KenyanIdData? data =
            await KenyaIdParser.parseDocument(inputImage);
        docData = data?.toJson();
        break;

      case KenyanDocumentType.ntsaLogbook:
        final NtsaLogbookData? data =
            await LogbookParser.parseDocument(inputImage);
        docData = data?.toJson();
        break;

      case KenyanDocumentType.psvBadge:
        final PsvBadgeData? data =
            await PsvBadgeParser.parseDocument(inputImage);
        docData = data?.toJson();
        break;

      case KenyanDocumentType.psvInsurance:
        // Handle PSV Insurance document parsing
        docData = null; // Update with actual parser when available
        break;
    }

    if (docData == null) {
      _updateStatus(FrameStatus.documentNotFound);
      return;
    }

    _extractedDocumentData = docData;
    _isDocumentPhaseComplete = true;

    // Try to extract the face from the document (for ID / licence only)
    final isolateParams = _prepareIsolateParams(image, camera);
    await _stopStreamSafely();

    try {
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty && isolateParams != null) {
        final imglib.Image? fullImage =
            await compute(convertCameraImageIsolate, isolateParams);
        if (fullImage != null) {
          final Face idFace = faces.first;
          final imglib.Image? cropped =
              _safeCropFace(fullImage, idFace.boundingBox);
          if (cropped != null) {
            _documentFaceEmbedding = FaceNetService.getFaceEmbedding(cropped);
          }
        }
      }
    } catch (e) {
      debugPrint('[Controller] Document face extraction failed: $e');
      // Non-fatal — we still proceed, just without a face match
    }

    // Switch to front camera for liveness
    await _startCamera(CameraLensDirection.front);
  }

  // ── Liveness phase ────────────────────────────────────────────────────────

  Future<void> _handleLivenessPhase(
    CameraImage image,
    CameraDescription camera,
    List<Face> faces,
  ) async {
    if (faces.isEmpty) {
      _scheduleUpdate(FrameStatus.noFaceFound);
      return;
    }

    final Face liveFace = faces.first;
    final LivenessPrompt? task = activePrompt;
    if (task == null) return;

    bool taskDone = false;

    switch (task) {
      case LivenessPrompt.turnLeft:
        if ((liveFace.headEulerAngleY ?? 0) < -35) taskDone = true;
        break;
      case LivenessPrompt.turnRight:
        if ((liveFace.headEulerAngleY ?? 0) > 35) taskDone = true;
        break;
      case LivenessPrompt.blink:
        final double? eyeOpen = liveFace.leftEyeOpenProbability;
        if (eyeOpen != null) {
          if (eyeOpen < 0.2) {
            _hasClosedEyes = true;
            _scheduleUpdate(FrameStatus.eyesClosed);
          } else if (eyeOpen > 0.8 && _hasClosedEyes) {
            taskDone = true;
          }
        }
        break;
    }

    if (taskDone) {
      _currentPromptIndex++;
      _hasClosedEyes = false;
      _scheduleUpdate(FrameStatus.processing);

      if (_currentPromptIndex >= _livenessRoutine.length) {
        // All prompts done — finalise
        _livenessTimer?.cancel();
        final isolateParams = _prepareIsolateParams(image, camera);
        await _stopStreamSafely();
        // FIX: await the finalization so _isProcessingFrame is not reset
        // before the finalization completes, preventing double-execution races.
        await _finalizeVerification(isolateParams, liveFace);
      }
    }
    // No else — we simply don't update status if nothing changed this frame
  }

  // ── Finalization ──────────────────────────────────────────────────────────

  Future<void> _finalizeVerification(
    Map<String, dynamic>? isolateParams,
    Face liveFace,
  ) async {
    if (_isDisposed) return;
    isFinalizing = true;
    _scheduleUpdate(FrameStatus.processing);

    try {
      if (isolateParams == null) {
        throw Exception('Image buffer cleared by OS before finalization');
      }

      final imglib.Image? fullImage =
          await compute(convertCameraImageIsolate, isolateParams);
      if (fullImage == null) {
        throw Exception('Isolate returned null image');
      }

      final imglib.Image? croppedFace =
          _safeCropFace(fullImage, liveFace.boundingBox);
      if (croppedFace == null) {
        throw Exception('Face bounding box out of image bounds');
      }

      // Step 1: Anti-spoofing
      final String spoofResult =
          FaceAntiSpoofing.antiSpoofing(croppedFace);
      if (spoofResult == 'Spoofing Detected') {
        _finalDecision = VerificationDecision.rejected;
        _scheduleUpdate(FrameStatus.spoofingDetected);
        _resetLiveness();
        isFinalizing = false;
        Future.delayed(const Duration(seconds: 2), () {
          if (!_isDisposed) _startCamera(CameraLensDirection.front);
        });
        return;
      }

      // Step 2: Face match
      final List<double>? selfieEmbedding =
          FaceNetService.getFaceEmbedding(croppedFace);

      if (selfieEmbedding != null && _documentFaceEmbedding != null) {
        _finalMatchScore = ScannerUtils.euclideanDistance(
          _documentFaceEmbedding!,
          selfieEmbedding,
        );

        // Thresholds tuned for MobileFaceNet 192-dim embeddings
        const double autoApprove = 0.80;
        const double manualReview = 1.10;

        if (_finalMatchScore <= autoApprove) {
          _finalIsFaceMatch = true;
          _finalDecision = VerificationDecision.autoApproved;
        } else if (_finalMatchScore <= manualReview) {
          _finalIsFaceMatch = false;
          _finalDecision = VerificationDecision.requiresAdminReview;
        } else {
          // Hard reject: face too different
          _finalIsFaceMatch = false;
          _finalDecision = VerificationDecision.rejected;
          _scheduleUpdate(FrameStatus.documentNotFound);
          _resetLiveness();
          isFinalizing = false;
          Future.delayed(const Duration(seconds: 2), () {
            if (!_isDisposed) _startCamera(CameraLensDirection.front);
          });
          return;
        }
      } else {
        // No document face — can't do biometric match → manual review
        _finalMatchScore = -1.0;
        _finalIsFaceMatch = false;
        _finalDecision = VerificationDecision.requiresAdminReview;
      }

      _scheduleUpdate(FrameStatus.success);
    } catch (e) {
      debugPrint('[Controller] Finalization fallback triggered: $e');
      // Fail safe: route to manual review rather than crashing
      _finalDecision = VerificationDecision.requiresAdminReview;
      _scheduleUpdate(FrameStatus.success);
    }
  }

  // ── Timeout ───────────────────────────────────────────────────────────────

  void _startLivenessTimeout() {
    _livenessTimer?.cancel();
    _livenessTimer = Timer(_livenessTimeout, () {
      if (_isDisposed || currentStatus == FrameStatus.success) return;
      debugPrint('[Controller] Liveness timeout — routing to manual review');
      _finalDecision = VerificationDecision.requiresAdminReview;
      isFinalizing = true;
      _scheduleUpdate(FrameStatus.timeout);
      // The view listens for timeout and pops with getFinalResult()
    });
  }

  // ── Public result ─────────────────────────────────────────────────────────

  /// Returns the final verification result. Call after [FrameStatus.success]
  /// or [FrameStatus.timeout].
  EkycVerificationResult getFinalResult() {
    return EkycVerificationResult(
      isLivenessVerified: isFinalizing && _finalDecision != VerificationDecision.rejected,
      faceMatchScore: _finalMatchScore >= 0 ? _finalMatchScore : null,
      isFaceMatch: _documentFaceEmbedding != null ? _finalIsFaceMatch : null,
      decision: _finalDecision,
      scannedDocumentType: targetDocumentType,
      documentData: _extractedDocumentData.isNotEmpty
          ? _extractedDocumentData
          : null,
      verifiedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic>? _prepareIsolateParams(
      CameraImage image, CameraDescription camera) {
    try {
      final Map<String, dynamic> params = {
        'width': image.width,
        'height': image.height,
        'format':
            image.format.group == ImageFormatGroup.bgra8888 ? 'bgra' : 'yuv',
        'dir': camera.lensDirection == CameraLensDirection.front
            ? 'front'
            : 'back',
        'y_plane': Uint8List.fromList(image.planes[0].bytes),
      };

      if (image.format.group != ImageFormatGroup.bgra8888) {
        params['u_plane'] = image.planes.length > 1
            ? Uint8List.fromList(image.planes[1].bytes)
            : Uint8List(0);
        params['v_plane'] = image.planes.length > 2
            ? Uint8List.fromList(image.planes[2].bytes)
            : Uint8List(0);
        // FIX: bytesPerRow and bytesPerPixel are nullable — safe defaults
        params['uv_stride'] = image.planes.length > 1
            ? (image.planes[1].bytesPerRow)
            : image.width ~/ 2;
        params['uv_pixel_stride'] = image.planes.length > 1
            ? (image.planes[1].bytesPerPixel ?? 1)
            : 1;
      }
      return params;
    } catch (e) {
      debugPrint('[Controller] _prepareIsolateParams error: $e');
      return null;
    }
  }

  imglib.Image? _safeCropFace(imglib.Image full, Rect box) {
    try {
      final int x = box.left.toInt().clamp(0, full.width - 1);
      final int y = box.top.toInt().clamp(0, full.height - 1);
      final int w = box.width.toInt().clamp(1, full.width - x);
      final int h = box.height.toInt().clamp(1, full.height - y);
      if (w < 10 || h < 10) return null; // Too small to be useful
      return imglib.copyCrop(full, x: x, y: y, width: w, height: h);
    } catch (e) {
      debugPrint('[Controller] _safeCropFace error: $e');
      return null;
    }
  }

  void _updateStatus(FrameStatus s) {
    if (currentStatus != s && !_isDisposed) {
      currentStatus = s;
      _safeNotify();
    }
  }

  /// FIX: Schedule all UI updates via WidgetsBinding to ensure they run on
  /// the main thread. The image stream callback runs on a background thread,
  /// so calling notifyListeners() directly causes random crashes on iOS.
  void _scheduleUpdate(FrameStatus s) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateStatus(s);
    });
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void _resetLiveness() {
    _currentPromptIndex = 0;
    _hasClosedEyes = false;
    _safeNotify();
  }
}