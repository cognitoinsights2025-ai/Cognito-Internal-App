// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// A widget that renders an image on Flutter Web using a native HTML <img> element.
/// This bypasses Flutter's ImageDecoder API which can fail with certain image formats.
class WebImage extends StatefulWidget {
  /// Raw bytes of the image
  final Uint8List? bytes;

  /// Blob URL or data URL (alternative to bytes)
  final String? url;

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const WebImage({
    super.key,
    this.bytes,
    this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  }) : assert(bytes != null || url != null, 'Either bytes or url must be provided');

  @override
  State<WebImage> createState() => _WebImageState();
}

class _WebImageState extends State<WebImage> {
  late String _viewType;
  String? _blobUrl;

  @override
  void initState() {
    super.initState();
    _viewType = 'web-image-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
    _registerView();
  }

  void _registerView() {
    String imageUrl;
    if (widget.url != null) {
      imageUrl = widget.url!;
    } else {
      final blob = html.Blob([widget.bytes!]);
      _blobUrl = html.Url.createObjectUrlFromBlob(blob);
      imageUrl = _blobUrl!;
    }

    final fitCss = _boxFitToCss(widget.fit);

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final img = html.ImageElement()
        ..src = imageUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = fitCss
        ..style.display = 'block';
      
      if (widget.borderRadius != null) {
        final r = widget.borderRadius!.topLeft.x;
        img.style.borderRadius = '${r}px';
      }

      return img;
    });
  }

  String _boxFitToCss(BoxFit fit) {
    switch (fit) {
      case BoxFit.cover: return 'cover';
      case BoxFit.contain: return 'contain';
      case BoxFit.fill: return 'fill';
      case BoxFit.fitWidth: return 'cover';
      case BoxFit.fitHeight: return 'cover';
      case BoxFit.none: return 'none';
      case BoxFit.scaleDown: return 'scale-down';
    }
  }

  @override
  void dispose() {
    if (_blobUrl != null) {
      html.Url.revokeObjectUrl(_blobUrl!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = SizedBox(
      width: widget.width,
      height: widget.height,
      child: HtmlElementView(viewType: _viewType),
    );

    if (widget.borderRadius != null) {
      child = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: child,
      );
    }

    return child;
  }
}
