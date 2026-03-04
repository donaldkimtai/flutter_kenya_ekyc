import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as imglib;

/// Utility class for Passive Liveness checks via TFLite anti-spoofing model.
///
/// Detects printed photos, phone screens, and other presentation attacks
/// before the face match step runs.
class FaceAntiSpoofing {
  FaceAntiSpoofing._();

  static const String _modelFile = 'assets/FaceAntiSpoofing.tflite';
  static const int _inputSize = 256;

  /// Score below this = live person. Above = spoofing attempt.
  static const double _spoofThreshold = 0.2;

  /// Laplacian score below this = image too blurry to analyse.
  static const int _blurThreshold = 1000;

  /// Per-pixel edge intensity threshold for the Laplacian kernel.
  static const int _lapEdgeThreshold = 50;

  static tfl.Interpreter? _interpreter;
  static bool isModelLoaded = false;

  /// Loads the anti-spoofing TFLite model from app assets.
  static Future<void> loadSpoofModel() async {
    try {
      _interpreter = await tfl.Interpreter.fromAsset(_modelFile);
      isModelLoaded = true;
      debugPrint('[FaceAntiSpoofing] Model loaded successfully.');
    } catch (e) {
      isModelLoaded = false;
      debugPrint('[FaceAntiSpoofing] Model load error: $e');
    }
  }

  /// Analyses a cropped face image. Returns one of:
  /// - `"Live Person Detected"` — passes liveness
  /// - `"Spoofing Detected"` — printed/screen attack
  /// - `"Too Blurry"` — image quality too low
  /// - `"Not Ready"` — model not loaded yet
  /// - `"Error Processing Face"` — unexpected runtime error
  static String antiSpoofing(imglib.Image? bitmapCrop) {
    if (bitmapCrop == null) return 'Error Processing Face';
    if (!isModelLoaded || _interpreter == null) return 'Not Ready';

    final int sharpness = _laplacianSharpness(bitmapCrop);
    if (sharpness < _blurThreshold) return 'Too Blurry';

    final double score = _runModel(bitmapCrop);
    if (score < 0) return 'Error Processing Face';

    return score < _spoofThreshold ? 'Live Person Detected' : 'Spoofing Detected';
  }

  static double _runModel(imglib.Image bitmap) {
    try {
      final imglib.Image scaled =
          imglib.copyResizeCropSquare(bitmap, size: _inputSize);
      final Float32List imgBytes = _normalizeImage(scaled);

      // Input tensor: [1, 256, 256, 3]
      final input = [
        imgBytes.reshape([1, _inputSize, _inputSize, 3])
      ];

      final List<List<double>> clssPred =
          List.generate(1, (_) => List.filled(8, 0.0));
      final List<List<double>> leafNodeMask =
          List.generate(1, (_) => List.filled(8, 0.0));

      // FIX: Use index-based output lookup instead of getOutputIndex("Identity")
      // which throws if the model uses unnamed/quantized tensors.
      final Map<int, Object> outputs = {
        0: clssPred,
        1: leafNodeMask,
      };

      _interpreter!.runForMultipleInputs(input, outputs);
      return _leafScore(clssPred, leafNodeMask);
    } catch (e) {
      debugPrint('[FaceAntiSpoofing] Model run error: $e');
      return -1.0;
    }
  }

  static double _leafScore(
    List<List<double>> clssPred,
    List<List<double>> leafNodeMask,
  ) {
    double score = 0.0;
    for (int i = 0; i < 8; i++) {
      score += clssPred[0][i].abs() * leafNodeMask[0][i];
    }
    return score;
  }

  static Float32List _normalizeImage(imglib.Image bitmap) {
    const double imageStd = 128.0;
    final h = bitmap.height;
    final w = bitmap.width;
    final convertedBytes = Float32List(h * w * 3);
    int pixelIndex = 0;
    for (int i = 0; i < h; i++) {
      for (int j = 0; j < w; j++) {
        final pixel = bitmap.getPixel(j, i);
        convertedBytes[pixelIndex++] = (pixel.r - imageStd) / imageStd;
        convertedBytes[pixelIndex++] = (pixel.g - imageStd) / imageStd;
        convertedBytes[pixelIndex++] = (pixel.b - imageStd) / imageStd;
      }
    }
    return convertedBytes;
  }

  /// Computes the Laplacian sharpness score of an image.
  /// Higher = sharper. Used to reject blurry/low-quality frames.
  static int _laplacianSharpness(imglib.Image bitmap) {
    final imglib.Image scaled =
        imglib.copyResizeCropSquare(bitmap, size: _inputSize);
    final imglib.Image grey = imglib.grayscale(scaled);

    const kernel = [
      [0, 1, 0],
      [1, -4, 1],
      [0, 1, 0]
    ];
    const kSize = 3;
    final h = grey.height;
    final w = grey.width;
    int score = 0;

    for (int x = 0; x < h - kSize + 1; x++) {
      for (int y = 0; y < w - kSize + 1; y++) {
        int result = 0;
        for (int i = 0; i < kSize; i++) {
          for (int j = 0; j < kSize; j++) {
            result +=
                (grey.getPixel(x + i, y + j).r.toInt() & 0xFF) * kernel[i][j];
          }
        }
        if (result > _lapEdgeThreshold) score++;
      }
    }
    return score;
  }

  /// Releases the TFLite interpreter.
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    isModelLoaded = false;
  }
}