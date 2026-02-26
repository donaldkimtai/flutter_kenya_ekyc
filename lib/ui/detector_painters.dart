import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class ScannerOverlayPainter extends CustomPainter {
  final Size absoluteImageSize;
  final List<Face> faces;
  final bool isFrontCamera;
  final bool isSuccess;

  ScannerOverlayPainter({
    required this.absoluteImageSize,
    required this.faces,
    required this.isFrontCamera,
    this.isSuccess = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = isSuccess ? Colors.greenAccent : Colors.amber;

    for (final Face face in faces) {
      Rect rect = face.boundingBox;
      double left = isFrontCamera ? size.width - (rect.right * scaleX) : rect.left * scaleX;
      double right = isFrontCamera ? size.width - (rect.left * scaleX) : rect.right * scaleX;
      Rect scaledRect = Rect.fromLTRB(left, rect.top * scaleY, right, rect.bottom * scaleY);
      canvas.drawRRect(RRect.fromRectAndRadius(scaledRect, const Radius.circular(16)), paint);
    }
  }

  @override
  bool shouldRepaint(ScannerOverlayPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize || 
           oldDelegate.faces != faces || 
           oldDelegate.isSuccess != isSuccess;
  }
}