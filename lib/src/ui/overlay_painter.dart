import 'package:flutter/material.dart';
import '../core/frame_status.dart';
import '../models/document_types.dart';

/// A custom painter that draws context-aware bounding boxes and corner brackets 
/// for the eKYC scanning interface.
class OverlayPainter extends CustomPainter {
  /// The current state of the scanning process.
  final FrameStatus status;

  /// Whether the user is currently in the selfie/liveness phase.
  final bool isLivenessPhase;

  /// The type of document being scanned (determines the aspect ratio).
  final KenyanDocumentType documentType;

  OverlayPainter({
    required this.status,
    required this.isLivenessPhase,
    required this.documentType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Determine the color based on the current frame status
    Color strokeColor = Colors.white;
    if (status == FrameStatus.success) strokeColor = Colors.greenAccent;
    if (status == FrameStatus.eyesClosed || status == FrameStatus.processing) {
      strokeColor = Colors.amber;
    }
    if (status == FrameStatus.spoofingDetected || status == FrameStatus.documentNotFound) {
      strokeColor = Colors.redAccent;
    }

    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);

    if (isLivenessPhase) {
      // Draw a sleek circular/oval frame for the Face/Liveness phase
      final radius = size.width * 0.35;
      canvas.drawCircle(center, radius, paint);
    } else {
      // Draw document-specific corner brackets
      double width;
      double height;

      if (documentType == KenyanDocumentType.ntsaLogbook) {
        // Logbooks are large A4 portrait documents
        width = size.width * 0.85;
        height = size.height * 0.65;
      } else {
        // Kenyan IDs and Driving Licenses are standard credit-card landscape
        width = size.width * 0.85;
        height = width * 0.63; // Standard ID aspect ratio
      }

      final rect = Rect.fromCenter(center: center, width: width, height: height);
      _drawCornerBrackets(canvas, rect, paint);
    }
  }

  /// Draws professional corner brackets `[ ]` instead of a full solid rectangle.
  void _drawCornerBrackets(Canvas canvas, Rect rect, Paint paint) {
    const double cornerLength = 30.0;

    // Top Left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cornerLength, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cornerLength), paint);

    // Top Right
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-cornerLength, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cornerLength), paint);

    // Bottom Left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cornerLength, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -cornerLength), paint);

    // Bottom Right
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-cornerLength, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) {
    return oldDelegate.status != status || 
           oldDelegate.isLivenessPhase != isLivenessPhase ||
           oldDelegate.documentType != documentType;
  }
}