import 'package:flutter/foundation.dart'; // Required for WriteBuffer
import 'dart:math';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;

/// Utility class for handling image conversions and vector math.
class ScannerUtils {
  ScannerUtils._();

  /// Converts a live CameraImage directly into an ML Kit InputImage
  static InputImage buildMetaData(CameraImage image, CameraLensDirection direction) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    
    final imageRotation = InputImageRotationValue.fromRawValue(
      direction == CameraLensDirection.front ? 270 : 90
    ) ?? InputImageRotation.rotation0deg;

    final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    final planeData = image.planes.map((Plane plane) {
      return InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: plane.bytesPerRow,
      );
    }).toList();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: planeData.first, 
    );
  }

  /// Normalizes an image for the TFLite MobileFaceNet Model
  static Float32List imageToByteListFloat32(imglib.Image image, int inputSize, double mean, double std) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r - mean) / std;
        buffer[pixelIndex++] = (pixel.g - mean) / std;
        buffer[pixelIndex++] = (pixel.b - mean) / std;
      }
    }
    return convertedBytes.buffer.asFloat32List();
  }

  /// Calculates the mathematical similarity between two face embeddings
  static double euclideanDistance(List<double> e1, List<double> e2) {
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum += pow((e1[i] - e2[i]), 2);
    }
    return sqrt(sum);
  }
}