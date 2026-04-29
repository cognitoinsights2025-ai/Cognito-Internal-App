import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Cross-platform image widget that works on both web and mobile.
/// On web: converts to base64 data URL for reliable rendering.
/// On mobile: uses standard Image.memory.
class PlatformImage extends StatelessWidget {
  final Uint8List bytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const PlatformImage({
    super.key,
    required this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image;

    if (kIsWeb) {
      // On web, use base64 data URL to avoid ImageDecoder API issues
      final base64 = _bytesToBase64(bytes);
      image = Image.network(
        'data:image/jpeg;base64,$base64',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _errorWidget(),
      );
    } else {
      // On mobile, Image.memory works fine
      image = Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _errorWidget(),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _errorWidget() => Container(
    width: width,
    height: height,
    color: Colors.grey[200],
    child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 32),
  );

  static String _bytesToBase64(Uint8List bytes) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buf = StringBuffer();
    int i = 0;
    while (i < bytes.length) {
      final b0 = bytes[i++];
      final b1 = i < bytes.length ? bytes[i++] : -1;
      final b2 = i < bytes.length ? bytes[i++] : -1;
      buf.write(chars[b0 >> 2]);
      buf.write(chars[((b0 & 3) << 4) | (b1 == -1 ? 0 : (b1 >> 4))]);
      buf.write(b1 == -1 ? '=' : chars[((b1 & 0xF) << 2) | (b2 == -1 ? 0 : (b2 >> 6))]);
      buf.write(b2 == -1 ? '=' : chars[b2 & 0x3F]);
    }
    return buf.toString();
  }
}
