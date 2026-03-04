import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as imglib;
import 'package:flutter/foundation.dart';

import 'detector_utils.dart';

/// Service for extracting 192-dimension face embeddings using MobileFaceNet.
///
/// Embeddings are compared with [ScannerUtils.euclideanDistance] to determine
/// if the live selfie matches the face on the scanned document.
class FaceNetService {
  FaceNetService._();

  static const String _modelFile = 'assets/mobilefacenet.tflite';
  static tfl.Interpreter? _interpreter;
  static bool _isModelLoaded = false;

  /// Loads the MobileFaceNet TFLite model from app assets.
  static Future<void> loadModel() async {
    try {
      _interpreter = await tfl.Interpreter.fromAsset(_modelFile);
      _isModelLoaded = true;
      debugPrint('[FaceNetService] Model loaded successfully.');
    } catch (e) {
      _isModelLoaded = false;
      debugPrint('[FaceNetService] Model load error: $e');
    }
  }

  /// Extracts a 192-float embedding from a cropped face image.
  /// Returns null if the model is not loaded or the image is invalid.
  static List<double>? getFaceEmbedding(imglib.Image faceImage) {
    if (!_isModelLoaded || _interpreter == null) return null;

    try {
      final imglib.Image resized =
          imglib.copyResizeCropSquare(faceImage, size: 112);
      final Float32List imageAsList =
          ScannerUtils.imageToByteListFloat32(resized, 112, 127.5, 127.5);
      final input = imageAsList.reshape([1, 112, 112, 3]);
      final output = List.generate(1, (_) => List.filled(192, 0.0));

      _interpreter!.run(input, output);
      return output[0];
    } catch (e) {
      debugPrint('[FaceNetService] Embedding error: $e');
      return null;
    }
  }

  /// Releases the TFLite interpreter.
  static void close() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
  }
}