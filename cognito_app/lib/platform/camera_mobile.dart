import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_interface.dart';

/// Mobile camera capture using image_picker.
class PlatformCameraCaptureImpl implements PlatformCameraCapture {
  @override
  Future<Uint8List?> capturePhoto(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null) return null;
    return await picked.readAsBytes();
  }
}
