import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../platform/platform_image.dart';
import '../platform/launcher.dart';
import '../core/theme.dart';

class InAppViewer extends StatefulWidget {
  final String fileName;
  final Uint8List bytes;
  final String fileType;

  const InAppViewer({
    super.key,
    required this.fileName,
    required this.bytes,
    required this.fileType,
  });

  @override
  State<InAppViewer> createState() => _InAppViewerState();
}

class _InAppViewerState extends State<InAppViewer> {
  VideoPlayerController? _videoController;
  bool _isVideoInit = false;

  @override
  void initState() {
    super.initState();
    if (_isVideo(widget.fileType)) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    if (kIsWeb) {
      // For web, we can't easily play bytes natively with video_player without a blob URL.
      // So on web we will fallback to download/launching the video.
      return; 
    }
    
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.fileName}');
      await file.writeAsBytes(widget.bytes, flush: true);
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      setState(() => _isVideoInit = true);
      _videoController!.play();
    } catch (e) {
      debugPrint('Video init error: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  bool _isImage(String type) => ['jpg', 'jpeg', 'png', 'heic', 'gif', 'webp'].contains(type.toLowerCase());
  bool _isPdf(String type) => type.toLowerCase() == 'pdf';
  bool _isVideo(String type) => ['mp4', 'mov', 'avi'].contains(type.toLowerCase());

  void _launchExternally() {
    PlatformLauncherImpl().launchFile(widget.fileName, widget.bytes, '*/*');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.fileName, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _launchExternally,
            tooltip: 'Download / Open Externally',
          ),
        ],
      ),
      body: Center(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final t = widget.fileType.toLowerCase();
    
    if (_isImage(t)) {
      return InteractiveViewer(
        child: PlatformImage(
          bytes: widget.bytes,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    } 
    
    if (_isPdf(t)) {
      return SfPdfViewer.memory(widget.bytes);
    }

    if (_isVideo(t) && !kIsWeb && _isVideoInit) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_videoController!),
            VideoProgressIndicator(_videoController!, allowScrubbing: true, padding: const EdgeInsets.all(10)),
            Center(
              child: IconButton(
                icon: Icon(
                  _videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 64,
                ),
                onPressed: () {
                  setState(() {
                    _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
                  });
                },
              ),
            ),
          ],
        ),
      );
    }

    // Unsupported natively in app (CSV, XLSX, PPT, or Web video)
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.insert_drive_file_rounded, size: 80, color: Colors.white.withValues(alpha: 0.5)),
        const SizedBox(height: 20),
        Text('Preview not available for ${t.toUpperCase()}', 
          style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _launchExternally,
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Open Externally'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
