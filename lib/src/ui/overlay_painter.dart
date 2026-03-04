import 'dart:math';
import 'package:flutter/material.dart';
import '../core/frame_status.dart';
import '../models/document_types.dart';

/// Draws the transparent cutout overlay and animated border for the camera UI.
///
/// Receives [previewRect] — the exact pixel bounds where the camera preview
/// renders on screen (accounting for letterboxing). All cutout geometry is
/// computed relative to this rect so the document box and face oval always
/// align with what the camera actually sees, regardless of screen aspect ratio.
class OverlayPainter extends CustomPainter {
  final FrameStatus status;
  final bool isLivenessPhase;
  final KenyanDocumentType documentType;
  final double livenessProgress;

  /// The exact screen rect where the camera image is rendered.
  /// Provided by the view using LayoutBuilder so we can align the cutout.
  final Rect previewRect;

  const OverlayPainter({
    required this.status,
    required this.isLivenessPhase,
    required this.documentType,
    required this.livenessProgress,
    required this.previewRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Work in preview-relative coordinates so the cutout sits inside
    // the actual camera feed, not the full screen (which includes black bars).
    final Offset center = previewRect.center;
    final double previewW = previewRect.width;
    final double previewH = previewRect.height;

    // ── Cutout geometry ────────────────────────────────────────────────────

    // Document aspect ratios (width / height):
    //   ID card / licence: ISO/IEC 7810 ID-1 = 85.6 × 54 mm ≈ 1.585
    //   PSV badge: roughly square
    //   Logbook: A5-ish landscape ≈ 1.4
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
        old.documentType != documentType ||
        old.previewRect != previewRect;
  }
}