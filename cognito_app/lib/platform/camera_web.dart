// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'camera_interface.dart';

/// Web camera capture using getUserMedia API.
class PlatformCameraCaptureImpl implements PlatformCameraCapture {
  @override
  Future<Uint8List?> capturePhoto(BuildContext context) async {
    return await Navigator.of(context).push<Uint8List?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _WebCameraScreen(),
      ),
    );
  }
}

class _WebCameraScreen extends StatefulWidget {
  const _WebCameraScreen();
  @override
  State<_WebCameraScreen> createState() => _WebCameraScreenState();
}

class _WebCameraScreenState extends State<_WebCameraScreen> {
  html.VideoElement? _video;
  html.MediaStream? _stream;
  String? _viewType;
  bool _ready = false;
  String? _error;
  bool _capturing = false;

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    try {
      final md = html.window.navigator.mediaDevices;
      if (md == null) { setState(() => _error = 'Camera not supported'); return; }
      _stream = await md.getUserMedia({
        'video': {'facingMode': 'user', 'width': {'ideal': 1280}, 'height': {'ideal': 720}},
        'audio': false,
      });
      _video = html.VideoElement()
        ..srcObject = _stream ..autoplay = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%' ..style.height = '100%'
        ..style.objectFit = 'cover' ..style.transform = 'scaleX(-1)';
      await _video!.play();
      _viewType = 'cam-${DateTime.now().microsecondsSinceEpoch}';
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(_viewType!, (_) => _video!);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera access denied.\nPlease allow permissions.');
    }
  }

  Future<void> _capture() async {
    if (_video == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final c = html.CanvasElement(width: _video!.videoWidth, height: _video!.videoHeight);
      final ctx = c.context2D..translate(c.width!, 0)..scale(-1, 1)..drawImage(_video!, 0, 0);
      final blob = await c.toBlob('image/jpeg', 0.92);
      final reader = html.FileReader();
      final comp = Completer<Uint8List>();
      reader.onLoadEnd.listen((_) {
        final r = reader.result;
        comp.complete(r is Uint8List ? r : r is List<int> ? Uint8List.fromList(r) : null);
      });
      reader.readAsArrayBuffer(blob);
      final bytes = await comp.future;
      _stop();
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (e) { setState(() { _capturing = false; _error = 'Capture failed: $e'; }); }
  }

  void _stop() { _stream?.getTracks().forEach((t) => t.stop()); _stream = null; }
  @override
  void dispose() { _stop(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (_ready && _viewType != null) Positioned.fill(child: HtmlElementView(viewType: _viewType!)),
        if (!_ready && _error == null) const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Colors.white), SizedBox(height: 16),
          Text('Opening camera...', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ])),
        if (_error != null) Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 64), const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: () => Navigator.of(context).pop(null), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Go Back'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white)),
        ]))),
        Positioned(top: MediaQuery.of(context).padding.top + 8, left: 12,
          child: IconButton(onPressed: () { _stop(); Navigator.of(context).pop(null); },
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            style: IconButton.styleFrom(backgroundColor: Colors.black38))),
        if (_ready) Positioned(bottom: MediaQuery.of(context).padding.bottom + 24, left: 0, right: 0,
          child: Column(children: [
            const Text('Tap to capture', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            GestureDetector(onTap: _capture, child: Container(width: 72, height: 72,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
              child: Container(margin: const EdgeInsets.all(4), decoration: BoxDecoration(
                shape: BoxShape.circle, color: _capturing ? Colors.red : Colors.white)),
            )),
          ])),
      ]),
    );
  }
}
