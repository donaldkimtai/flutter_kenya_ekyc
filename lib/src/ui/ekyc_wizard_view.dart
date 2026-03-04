import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../controllers/ekyc_wizard_controller.dart';
import '../core/frame_status.dart';
import '../models/document_types.dart';
import 'overlay_painter.dart';

/// The beautiful, user-facing camera interface for the eKYC process.
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
    // Instantiate our State Manager and start the AI pipeline
    _controller = EkycWizardController(targetDocumentType: widget.targetDocumentType);
    _controller.initializeWizard();

    // Listen for the final success state to return data 
    _controller.addListener(_onControllerStateChanged);
  }

  void _onControllerStateChanged() {
    if (_controller.currentStatus == FrameStatus.success) {
      _controller.removeListener(_onControllerStateChanged);
      
      // Verification complete! Pop the screen and return the strictly-typed result.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pop(_controller.getFinalResult());
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerStateChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Helper method to translate the internal FrameStatus into user-friendly Swahili/English
  String _getStatusText(FrameStatus status) {
    switch (status) {
      case FrameStatus.initializing:
        return "Kuwasha Kamera...\n(Initializing...)";
      case FrameStatus.documentNotFound:
        return "Tafadhali weka kitambulisho kwenye mraba\n(Align document in frame)";
      case FrameStatus.noFaceFound:
        return "Sura haionekani. Angalia kwenye kamera.\n(Face not visible)";
      case FrameStatus.spoofingDetected:
        return "TAHADHARI: Picha bandia imegunduliwa!\n(Spoofing Detected!)";
      case FrameStatus.success:
        return "Imethibitishwa Kikamilifu!\n(Verification Successful!)";
      case FrameStatus.processing:
      default:
        return _controller.promptInstruction;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, child) {
          final isInitialized = _controller.cameraController?.value.isInitialized ?? false;

          if (!isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }

          // determines if we are scanning a document or taking a liveness selfie
          // by checking which camera is currently active.
          final isLivenessPhase = _controller.cameraController!.description.lensDirection == 
              CameraLensDirection.front;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. The Raw Camera Feed
              CameraPreview(_controller.cameraController!),

              // 2. The Dark UI Mask (Creates the see-through cutout effect)
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.75),
                  BlendMode.srcOut,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        backgroundBlendMode: BlendMode.dstOut,
                      ),
                    ),
                    Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        width: isLivenessPhase ? 280 : MediaQuery.of(context).size.width * 0.85,
                        height: isLivenessPhase ? 280 : 
                            (widget.targetDocumentType == KenyanDocumentType.ntsaLogbook ? 
                            MediaQuery.of(context).size.height * 0.65 : 
                            MediaQuery.of(context).size.width * 0.85 * 0.63),
                        decoration: BoxDecoration(
                          color: Colors.white, // This white punches a hole in the mask
                          borderRadius: BorderRadius.circular(isLivenessPhase ? 200 : 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. The Custom Bracket/Ring Painter
              CustomPaint(
                painter: OverlayPainter(
                  status: _controller.currentStatus,
                  isLivenessPhase: isLivenessPhase,
                  documentType: widget.targetDocumentType,
                ),
              ),

              // 4. The Instruction Panel (Swahili & English)
              Positioned(
                top: 80,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E).withValues(alpha: 0.9), // Corporate Blue
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Text(
                    _getStatusText(_controller.currentStatus),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),

              // 5. Cancel / Close Button
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 40),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}