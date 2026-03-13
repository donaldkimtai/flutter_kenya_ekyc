import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../controllers/ekyc_wizard_controller.dart';
import '../core/frame_status.dart';
import '../models/document_types.dart';
import 'overlay_painter.dart';

/// The camera-based UI for the full eKYC verification flow.
class EkycWizardView extends StatefulWidget {
  final KenyanDocumentType targetDocumentType;

  const EkycWizardView({
    super.key,
    required this.targetDocumentType,
  });

  @override
  State<EkycWizardView> createState() => _EkycWizardViewState();
}

class _EkycWizardViewState extends State<EkycWizardView> {
  late final EkycWizardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EkycWizardController(
        targetDocumentType: widget.targetDocumentType);
    _controller.initializeWizard();
    _controller.addListener(_onStateChange);
  }

  void _onStateChange() {
    // Success → pop with result after brief visual confirmation
    if (_controller.currentStatus == FrameStatus.success &&
        _controller.isFinalizing) {
      _controller.removeListener(_onStateChange);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          Navigator.of(context).pop(_controller.getFinalResult());
        }
      });
      return;
    }

    // Timeout → pop with manual-review result immediately
    if (_controller.currentStatus == FrameStatus.timeout) {
      _controller.removeListener(_onStateChange);
      if (mounted) {
        Navigator.of(context).pop(_controller.getFinalResult());
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    super.dispose();
  }

  // ── Status text (Swahili / English bilingual) ─────────────────────────────

  String _statusText(FrameStatus status) {
    switch (status) {
      case FrameStatus.initializing:
        return 'Kuwasha Kamera...\n(Initializing...)';
      case FrameStatus.processing:
        return _controller.promptInstruction;
      case FrameStatus.documentNotFound:
        return _controller.promptInstruction;
      case FrameStatus.documentTooSmall:
        return 'Karibishe zaidi\n(Move closer to the document)';
      case FrameStatus.documentTooBig:
        return 'Ondoa nyuma kidogo\n(Move further from the document)';
      case FrameStatus.documentNotInCenter:
        return 'Weka katikati\n(Centre the document)';
      case FrameStatus.noFaceFound:
        return 'Sura haionekani\n(Face not visible — look at camera)';
      case FrameStatus.eyesClosed:
        return 'Vizuri! Fungua macho\n(Good! Now open your eyes)';
      case FrameStatus.headTurnedLeft:
        return 'Vizuri!\n(Great!)';
      case FrameStatus.headTurnedRight:
        return 'Vizuri!\n(Great!)';
      case FrameStatus.spoofingDetected:
        return '⚠️ Picha bandia imegunduliwa!\n(Spoofing detected — use your real face)';
      case FrameStatus.timeout:
        return 'Muda umekwisha\n(Time up — routing to manual review)';
      case FrameStatus.success:
        return '✅ Imethibitishwa!\n(Verification Successful!)';
    }
  }

  Color _statusColor(FrameStatus status) {
    switch (status) {
      case FrameStatus.success:
        return Colors.green.shade700;
      case FrameStatus.spoofingDetected:
      case FrameStatus.timeout:
        return Colors.red.shade700;
      case FrameStatus.eyesClosed:
      case FrameStatus.processing:
        return Colors.amber.shade800;
      default:
        return const Color(0xFF1A237E);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final bool isInitialised =
              _controller.cameraController?.value.isInitialized ?? false;

          // Camera error (sensor privacy, permission denied, etc.)
          if (_controller.cameraError != null) {
            return _buildCameraErrorScreen(_controller.cameraError!);
          }

          if (!isInitialised || _controller.isSwitchingCamera) {
            return _buildSwitchingScreen();
          }

          final bool isLivenessPhase =
              _controller.cameraController!.description.lensDirection ==
                  CameraLensDirection.front;

          // 🔥 THE ASPECT RATIO FIX 🔥
          // Get the raw aspect ratio from the camera sensor
          double camAspect = _controller.cameraController!.value.aspectRatio;
          
          // Flutter's camera plugin always returns width > height (landscape ratio).
          // If the phone is held in portrait, we must invert the ratio to prevent zooming!
          final bool isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
          if (isPortrait && camAspect > 1.0) {
            camAspect = 1.0 / camAspect;
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Black background covers the letterboxed edges
              Container(color: Colors.black),

              // Center the AspectRatio so it fits perfectly on screen without cropping
              Center(
                child: AspectRatio(
                  aspectRatio: camAspect,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_controller.cameraController!),
                      
                      // The overlay is now drawn EXACTLY over the preview area
                      CustomPaint(
                        painter: OverlayPainter(
                          status: _controller.currentStatus,
                          isLivenessPhase: isLivenessPhase,
                          documentType: widget.targetDocumentType,
                          livenessProgress: _controller.livenessProgress,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Status banner
              Positioned(
                top: 72,
                left: 16,
                right: 16,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 18),
                  decoration: BoxDecoration(
                    color: _statusColor(_controller.currentStatus)
                        .withOpacity(0.92),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    _statusText(_controller.currentStatus),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ),

              // Liveness step indicator dots (only during liveness phase)
              if (isLivenessPhase)
                Positioned(
                  bottom: 110,
                  left: 0,
                  right: 0,
                  child: _buildStepIndicator(),
                ),

              // Close button
              Positioned(
                bottom: 36,
                left: 0,
                right: 0,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 36),
                    tooltip: 'Cancel verification',
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCameraErrorScreen(String message) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_photography_outlined,
                    color: Colors.redAccent, size: 72),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, height: 1.6),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  onPressed: () {
                    _controller.initializeWizard();
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.greenAccent),
          SizedBox(height: 20),
          Text(
            'Inabadilisha Kamera...\n(Switching to Selfie Camera)',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    const prompts = ['Turn Left', 'Turn Right', 'Blink'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(prompts.length, (i) {
        final bool done = i < _controller.livenessProgress *
            3; // 3 = total prompts
        final bool active =
            i == (_controller.livenessProgress * 3).floor();
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: active ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? Colors.greenAccent
                : active
                    ? Colors.white
                    : Colors.white30,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}