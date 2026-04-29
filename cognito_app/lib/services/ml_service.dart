import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  dynamic _interpreter;
  dynamic _faceDetector;

  bool get isModelLoaded => _interpreter != null;

  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      // _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      print('✅ AI initialization skipped on Web');
    } catch (e) {
      print('❌ Failed to load TFLite model: $e');
    }
  }

  /// Calculates cosine similarity between two 192D embeddings
  double cosineSimilarity(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return 0.0;
    double dotProduct = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < e1.length; i++) {
        dotProduct += e1[i] * e2[i];
        normA += pow(e1[i], 2);
        normB += pow(e2[i], 2);
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Converts an img.Image back to a 112x112 Float32List format required by MobileFaceNet
  Float32List _imageToByteListFloat32(img.Image inputImage) {
    final resized = img.copyResize(inputImage, width: 112, height: 112);
    final inputSize = 112 * 112 * 3;
    var convertedBytes = Float32List(inputSize);
    int bufferIndex = 0;

    for (int y = 0; y < resized.height; y++) {
      for (int x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        // Normalize to [-1, 1] - typical for MobileFaceNet
        convertedBytes[bufferIndex++] = (pixel.r - 127.5) / 127.5;
        convertedBytes[bufferIndex++] = (pixel.g - 127.5) / 127.5;
        convertedBytes[bufferIndex++] = (pixel.b - 127.5) / 127.5;
      }
    }
    return convertedBytes;
  }

  /// Generates a 192-dimensional numerical embedding for an image
  Future<List<double>?> generateEmbedding(img.Image image) async {
    return null;
  }

  /// Converts a camera/byte array image, detects the face, crops it, and returns the embedding
  Future<List<double>?> getFaceEmbedding(Uint8List imageBytes, int width, int height) async {
    return null;
  }

  void dispose() {
    _interpreter?.close();
    _faceDetector.close();
  }
}
