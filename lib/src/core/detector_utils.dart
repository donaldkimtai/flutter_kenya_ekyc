import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;

/// Utility class for handling image conversions and vector math.
class ScannerUtils {
  ScannerUtils._();

  /// Converts a live CameraImage into an ML Kit InputImage with correct
  /// rotation for both Android (YUV420/NV21) and iOS (BGRA8888).
  ///
  /// FIX: Previously hardcoded 270/90 degrees which was wrong for iOS and
  /// caused face detection to process upside-down images, breaking blink
  /// and head-turn liveness checks.
  static InputImage? buildMetaData(
    CameraImage image,
    CameraLensDirection direction,
    int sensorOrientation,
  ) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize =
          Size(image.width.toDouble(), image.height.toDouble());

      // FIX: Compute correct rotation from actual sensor orientation
      // instead of hardcoded values that break on iPhone and landscape mode.
      final InputImageRotation imageRotation =
          _resolveRotation(direction, sensorOrientation);

      final InputImageFormat inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              (Platform.isAndroid
                  ? InputImageFormat.nv21
                  : InputImageFormat.bgra8888);

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('[ScannerUtils] buildMetaData error: $e');
      return null;
    }
  }

  /// Resolves the correct [InputImageRotation] from the camera sensor
  /// orientation and lens direction for both Android and iOS.
  static InputImageRotation _resolveRotation(
    CameraLensDirection direction,
    int sensorOrientation,
  ) {
    if (Platform.isIOS) {
      // iOS: sensor orientation maps directly
      switch (sensorOrientation) {
        case 90:
          return InputImageRotation.rotation90deg;
        case 180:
          return InputImageRotation.rotation180deg;
        case 270:
          return InputImageRotation.rotation270deg;
        default:
          return InputImageRotation.rotation0deg;
      }
    }

    // Android: front camera mirrors, so we compensate
    if (direction == CameraLensDirection.front) {
      switch (sensorOrientation) {
        case 90:
          return InputImageRotation.rotation270deg;
        case 270:
          return InputImageRotation.rotation90deg;
        default:
          return InputImageRotation.rotation0deg;
      }
    }

    // Android back camera
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  /// Normalizes an image for the TFLite MobileFaceNet model (112x112, range -1 to 1).
  static Float32List imageToByteListFloat32(
    imglib.Image image,
    int inputSize,
    double mean,
    double std,
  ) {
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

  /// Calculates the Euclidean distance between two face embeddings.
  /// Lower = more similar. Threshold ~0.8 for same person.
  static double euclideanDistance(List<double> e1, List<double> e2) {
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum += pow((e1[i] - e2[i]), 2);
    }
    return sqrt(sum);
  }
}