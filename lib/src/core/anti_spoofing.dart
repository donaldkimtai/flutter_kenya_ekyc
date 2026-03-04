import 'dart:core';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as imglib;

/// Utility class for handling Passive Liveness checks via TFLite.
class FaceAntiSpoofing {
  FaceAntiSpoofing._();

  static const String MODEL_FILE = "FaceAntiSpoofing.tflite";
  static const int INPUT_IMAGE_SIZE = 256; 
  static const double THRESHOLD = 0.2; 
  static const int LAPLACE_THRESHOLD = 50; 
  static const int LAPLACIAN_THRESHOLD = 1000; 
  
  static late tfl.Interpreter interpreter;
  static bool isModelLoaded = false;

  /// Loads the anti-spoofing model from assets.
  static Future<void> loadSpoofModel() async {
    try {
      interpreter = await tfl.Interpreter.fromAsset(MODEL_FILE);
      isModelLoaded = true;
    } catch (e) {
      isModelLoaded = false;
    }
  }

  /// Analyzes a cropped face image to determine if it is a live person or a spoof.
  static String antiSpoofing(imglib.Image? bitmapCrop) {
    if (bitmapCrop == null || !isModelLoaded) return "Initialization Error";

    int laplaceScore = laplacian(bitmapCrop);
    if (laplaceScore < LAPLACIAN_THRESHOLD) return "Too Blurry";

    double spoofScore = _runAntiSpoofingModel(bitmapCrop);
    
    if (spoofScore < 0) return "Error Processing Face";
    return spoofScore < THRESHOLD ? "Live Person Detected" : "Spoofing Detected";
  }

  static double _runAntiSpoofingModel(imglib.Image bitmap) {
    imglib.Image bitmapScale = imglib.copyResizeCropSquare(bitmap, size: INPUT_IMAGE_SIZE);
    var imgBytes = normalizeImage(bitmapScale);

    var input = [imgBytes.reshape([1, INPUT_IMAGE_SIZE, INPUT_IMAGE_SIZE, 3])];
    var clssPred = List.generate(1, (_) => List.filled(8, 0.0));
    var leafNodeMask = List.generate(1, (_) => List.filled(8, 0.0));

    Map<int, Object> outputs = {
      interpreter.getOutputIndex("Identity"): clssPred,
      interpreter.getOutputIndex("Identity_1"): leafNodeMask,
    };

    try {
      interpreter.runForMultipleInputs(input, outputs);
      return _calculateLeafScore(clssPred, leafNodeMask);
    } catch (e) {
      return -1.0;
    }
  }

  static double _calculateLeafScore(List<List<double>> clssPred, List<List<double>> leafNodeMask) {
    double score = 0.0;
    for (var i = 0; i < 8; i++) {
      double absVar = (clssPred[0][i]).abs();
      score += absVar * leafNodeMask[0][i];
    }
    return score;
  }

  static Float32List normalizeImage(imglib.Image bitmap) {
    var h = bitmap.height;
    var w = bitmap.width;
    var convertedBytes = Float32List(1 * h * w * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    var imageStd = 128.0;
    var pixelIndex = 0;

    for (var i = 0; i < h; i++) { 
      for (var j = 0; j < w; j++) {
        var pixel = bitmap.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r - imageStd) / imageStd;
        buffer[pixelIndex++] = (pixel.g - imageStd) / imageStd;
        buffer[pixelIndex++] = (pixel.b - imageStd) / imageStd;
      }
    }
    return convertedBytes.buffer.asFloat32List();
  }

  static int laplacian(imglib.Image bitmap) {
    imglib.Image bitmapScale = imglib.copyResizeCropSquare(bitmap, size: INPUT_IMAGE_SIZE);
    var laplace = [[0, 1, 0], [1, -4, 1], [0, 1, 0]];
    int size = laplace.length;
    var img = imglib.grayscale(bitmapScale);
    int height = img.height;
    int width = img.width;

    int score = 0;
    for (int x = 0; x < height - size + 1; x++){
      for (int y = 0; y < width - size + 1; y++){
        int result = 0;
        for (int i = 0; i < size; i++){
          for (int j = 0; j < size; j++){
            result += (img.getPixel(x + i, y + j).r.toInt() & 0xFF) * laplace[i][j];
          }
        }
        if (result > LAPLACE_THRESHOLD) score++;
      }
    }
    return score;
  }
}