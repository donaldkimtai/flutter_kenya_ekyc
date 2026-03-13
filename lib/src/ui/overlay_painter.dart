import 'dart:math';
import 'package:flutter/material.dart';
import '../core/frame_status.dart';
import '../models/document_types.dart';

/// Draws the transparent cutout overlay and animated border for the camera UI.
///
/// Because this is nested inside the AspectRatio widget with the CameraPreview,
/// the [size] variable perfectly matches the camera feed dimensions.
class OverlayPainter extends CustomPainter {
  final FrameStatus status;
  final bool isLivenessPhase;
  final KenyanDocumentType documentType;
  final double livenessProgress;

  const OverlayPainter({
    required this.status,
    required this.isLivenessPhase,
    required this.documentType,
    required this.livenessProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double previewW = size.width;
    final double previewH = size.height;

    // ── Cutout geometry ────────────────────────────────────────────────────
    double boxWidth = previewW * 0.85;
    double boxHeight;
    switch (documentType) {
      case KenyanDocumentType.ntsaLogbook:
        boxHeight = boxWidth / 1.4;
        break;
      case KenyanDocumentType.psvBadge:
        boxHeight = boxWidth * 0.9;
        break;
      default: // nationalIdFront, nationalIdBack, drivingLicense
        boxHeight = boxWidth / 1.585;
    }

    // Cap height so the box never exceeds 80% of the preview height
    if (boxHeight > previewH * 0.80) {
      boxHeight = previewH * 0.80;
      boxWidth = boxHeight * 1.585;
    }

    final double livenessRadius = previewW * 0.40;

    final Path cutout = Path();
    if (isLivenessPhase) {
      cutout.addOval(
          Rect.fromCircle(center: center, radius: livenessRadius));
    } else {
      cutout.addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: center, width: boxWidth, height: boxHeight),
        const Radius.circular(16),
      ));
    }

    // ── Full-screen dark overlay with transparent hole punch ──────────────
    canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawPaint(Paint()..color = Colors.black.withOpacity(0.80));
    canvas.drawPath(cutout, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // ── Border colour ─────────────────────────────────────────────────────
    Color stroke = Colors.white;
    if (status == FrameStatus.success) stroke = Colors.greenAccent;
    if (status == FrameStatus.eyesClosed ||
        status == FrameStatus.processing) {
      stroke = Colors.amber;
    }
    if (status == FrameStatus.spoofingDetected ||
        status == FrameStatus.documentNotFound ||
        status == FrameStatus.timeout) {
      stroke = Colors.redAccent;
    }

    final Paint borderPaint = Paint()
      ..color = stroke
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // ── Draw border / progress arc ────────────────────────────────────────
    if (isLivenessPhase) {
      canvas.drawPath(cutout, borderPaint);

      if (livenessProgress > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: livenessRadius),
          -pi / 2,
          2 * pi * livenessProgress,
          false,
          Paint()
            ..color = Colors.greenAccent
            ..strokeWidth = 7.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
    } else {
      final Rect docRect = Rect.fromCenter(
          center: center, width: boxWidth, height: boxHeight);
      _drawCornerBrackets(canvas, docRect, borderPaint);
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Paint paint) {
    const double len = 24.0;
    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(len, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, len), paint);
    // Top-right
    canvas.drawLine(
        rect.topRight, rect.topRight + const Offset(-len, 0), paint);
    canvas.drawLine(
        rect.topRight, rect.topRight + const Offset(0, len), paint);
    // Bottom-left
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft + const Offset(len, 0), paint);
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft + const Offset(0, -len), paint);
    // Bottom-right
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight + const Offset(-len, 0), paint);
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight + const Offset(0, -len), paint);
  }

  @override
  bool shouldRepaint(covariant OverlayPainter old) {
    return old.status != status ||
        old.isLivenessPhase != isLivenessPhase ||
        old.livenessProgress != livenessProgress ||
        old.documentType != documentType;
  }
}