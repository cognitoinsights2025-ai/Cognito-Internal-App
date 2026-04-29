import 'dart:typed_data';

/// Result from picking a file — platform agnostic.
class PickedFileData {
  final String name;
  final Uint8List bytes;
  final int size;

  PickedFileData({required this.name, required this.bytes, required this.size});
}

/// Abstract file picker interface.
/// Implementations: WebFilePickerImpl (web), MobileFilePickerImpl (mobile)
abstract class PlatformFilePicker {
  Future<PickedFileData?> pickImage();
  Future<PickedFileData?> pickPdf();
  Future<PickedFileData?> pickDocument();
  Future<PickedFileData?> pickArchive();
  Future<PickedFileData?> pickAnyFile();
}
