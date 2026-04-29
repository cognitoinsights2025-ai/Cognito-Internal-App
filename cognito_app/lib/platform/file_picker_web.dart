// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'file_picker_interface.dart';

/// Web implementation using dart:html <input type="file">.
class PlatformFilePickerImpl implements PlatformFilePicker {
  Future<PickedFileData?> _pick({String? accept}) async {
    final completer = Completer<PickedFileData?>();
    final input = html.FileUploadInputElement();
    if (accept != null && accept.isNotEmpty) input.accept = accept;

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) { completer.complete(null); return; }
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is Uint8List) {
          completer.complete(PickedFileData(name: file.name, bytes: result, size: file.size));
        } else if (result is List<int>) {
          completer.complete(PickedFileData(name: file.name, bytes: Uint8List.fromList(result), size: file.size));
        } else {
          completer.complete(null);
        }
      });
      reader.onError.listen((_) => completer.complete(null));
    });

    input.click();
    return completer.future;
  }

  @override
  Future<PickedFileData?> pickImage() => _pick(accept: 'image/*');
  @override
  Future<PickedFileData?> pickPdf() => _pick(accept: 'application/pdf,.pdf');
  @override
  Future<PickedFileData?> pickDocument() => _pick(
      accept: '.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv,.rtf,.odt,'
          'application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,'
          'application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,'
          'text/plain,text/csv');
  @override
  Future<PickedFileData?> pickArchive() => _pick(accept: '.zip,.rar,.7z,.tar,.gz,application/zip');
  @override
  Future<PickedFileData?> pickAnyFile() => _pick();
}
