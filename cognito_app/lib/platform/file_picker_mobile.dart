import 'dart:typed_data';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:image_picker/image_picker.dart';
import 'file_picker_interface.dart';

/// Mobile implementation using file_picker and image_picker packages.
class PlatformFilePickerImpl implements PlatformFilePicker {
  @override
  Future<PickedFileData?> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return PickedFileData(name: picked.name, bytes: bytes, size: bytes.length);
  }

  Future<PickedFileData?> _pick(fp.FileType type, {List<String>? ext}) async {
    final result = await fp.FilePicker.pickFiles(type: type, allowedExtensions: ext, withData: true);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes == null) return null;
    return PickedFileData(name: file.name, bytes: file.bytes!, size: file.bytes!.length);
  }

  @override
  Future<PickedFileData?> pickPdf() => _pick(fp.FileType.custom, ext: ['pdf']);
  @override
  Future<PickedFileData?> pickDocument() => _pick(fp.FileType.custom,
      ext: ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv']);
  @override
  Future<PickedFileData?> pickArchive() => _pick(fp.FileType.custom,
      ext: ['zip', 'rar', '7z', 'tar', 'gz']);
  @override
  Future<PickedFileData?> pickAnyFile() => _pick(fp.FileType.any);
}
