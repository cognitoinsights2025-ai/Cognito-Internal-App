import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Abstract camera capture interface.
abstract class PlatformCameraCapture {
  Future<Uint8List?> capturePhoto(BuildContext context);
}
