// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';

/// Opens the device camera (webcam) in a full-screen dialog and captures a photo.
/// Returns [Uint8List] bytes of the captured JPEG, or null if cancelled.
class WebCameraCapture {
  static Future<Uint8List?> capturePhoto(BuildContext context) async {
    return await Navigator.of(context).push<Uint8List?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _CameraCaptureScreen(),
      ),
    );
  }
}

class _CameraCaptureScreen extends StatefulWidget {
  const _CameraCaptureScreen();
  @override
  State<_CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<_CameraCaptureScreen> {
  html.VideoElement? _video;
  html.MediaStream? _stream;
  String? _viewType;
  bool _ready = false;
  String? _error;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      // Request camera access
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        setState(() => _error = 'Camera not supported on this browser');
        return;
      }

      _stream = await mediaDevices.getUserMedia({
        'video': {
          'facingMode': 'user', // front camera
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      });

      // Create video element
      _video = html.VideoElement()
        ..srcObject = _stream
        ..autoplay = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(-1)'; // Mirror for selfie

      await _video!.play();

      // Register platform view
      _viewType = 'camera-view-${DateTime.now().microsecondsSinceEpoch}';
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(_viewType!, (int viewId) {
        return _video!;
      });

      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Camera access denied or unavailable.\n\nPlease allow camera permissions and try again.');
      }
    }
  }

  Future<void> _capture() async {
    if (_video == null || _capturing) return;
    setState(() => _capturing = true);

    try {
      // Create canvas to capture frame
      final canvas = html.CanvasElement(
        width: _video!.videoWidth,
        height: _video!.videoHeight,
      );
      final ctx = canvas.context2D;

      // Mirror the image (flip horizontal) to match the preview
      ctx.translate(canvas.width!, 0);
      ctx.scale(-1, 1);
      ctx.drawImage(_video!, 0, 0);

      // Convert to JPEG blob
      final blob = await canvas.toBlob('image/jpeg', 0.92);

      // Read blob as bytes
      final reader = html.FileReader();
      final completer = Completer<Uint8List>();
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is Uint8List) {
          completer.complete(result);
        } else if (result is List<int>) {
          completer.complete(Uint8List.fromList(result));
        } else {
          completer.complete(null);
        }
      });
      reader.readAsArrayBuffer(blob);

      final bytes = await completer.future;

      _stopCamera();
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (e) {
      setState(() {
        _capturing = false;
        _error = 'Failed to capture photo: $e';
      });
    }
  }

  void _stopCamera() {
    if (_stream != null) {
      for (final track in _stream!.getTracks()) {
        track.stop();
      }
      _stream = null;
    }
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Camera preview
        if (_ready && _viewType != null)
          Positioned.fill(
            child: HtmlElementView(viewType: _viewType!),
          ),

        // Loading state
        if (!_ready && _error == null)
          const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Opening camera...',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ]),
          ),

        // Error state
        if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 64),
                const SizedBox(height: 16),
                Text(_error!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                  ),
                ),
              ]),
            ),
          ),

        // Top bar — close button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          child: IconButton(
            onPressed: () {
              _stopCamera();
              Navigator.of(context).pop(null);
            },
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            style: IconButton.styleFrom(backgroundColor: Colors.black38),
          ),
        ),

        // Bottom controls
        if (_ready)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0, right: 0,
            child: Column(children: [
              const Text('Tap to capture',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _capture,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _capturing ? Colors.red : Colors.white,
                    ),
                    child: _capturing
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : null,
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
