import 'dart:typed_data';

abstract class PlatformLauncher {
  Future<void> launchFile(String fileName, Uint8List bytes, String mimeType);
}
