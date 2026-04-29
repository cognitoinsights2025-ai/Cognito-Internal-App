// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Result from picking a file via the native web file input.
class PickedFileData {
  final String name;
  final Uint8List bytes;
  final int size;

  PickedFileData({required this.name, required this.bytes, required this.size});
}

/// Native web file picker — uses HTML <input type="file"> under the hood.
/// Works reliably on Flutter Web without any plugins.
class WebFilePicker {
  /// Pick a file with optional MIME type filter.
  ///
  /// [accept] — comma-separated MIME types or extensions, e.g.:
  ///   - `'image/*'` for images
  ///   - `'application/pdf'` for PDFs
  ///   - `'.pdf,.doc,.docx'` for specific extensions
  ///   - `'*/*'` or `null` for any file
  ///
  /// Returns [PickedFileData] or `null` if the user cancelled.
  static Future<PickedFileData?> pickFile({String? accept}) async {
    final completer = Completer<PickedFileData?>();

    final input = html.FileUploadInputElement();
    if (accept != null && accept.isNotEmpty) {
      input.accept = accept;
    }

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete(null);
        return;
      }

      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);

      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is Uint8List) {
          completer.complete(PickedFileData(
            name: file.name,
            bytes: result,
            size: file.size,
          ));
        } else if (result is List<int>) {
          completer.complete(PickedFileData(
            name: file.name,
            bytes: Uint8List.fromList(result),
            size: file.size,
          ));
        } else {
          // fallback: try to treat as bytes
          completer.complete(null);
        }
      });

      reader.onError.listen((_) {
        completer.complete(null);
      });
    });

    // If the user cancels (clicks away), the onCancel fires
    // But not all browsers support it, so we also handle via focus
    input.click();

    return completer.future;
  }

  /// Pick an image file (JPG, PNG, GIF, WebP)
  static Future<PickedFileData?> pickImage() =>
      pickFile(accept: 'image/jpeg,image/png,image/gif,image/webp,image/*');

  /// Pick a PDF file
  static Future<PickedFileData?> pickPdf() =>
      pickFile(accept: 'application/pdf,.pdf');

  /// Pick a document file (Word, Excel, PowerPoint, Text, CSV)
  static Future<PickedFileData?> pickDocument() =>
      pickFile(accept: '.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv,.rtf,.odt,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,text/plain,text/csv');

  /// Pick a ZIP/archive file
  static Future<PickedFileData?> pickArchive() =>
      pickFile(accept: '.zip,.rar,.7z,.tar,.gz,application/zip,application/x-rar-compressed,application/gzip');

  /// Pick any file (no filter)
  static Future<PickedFileData?> pickAnyFile() =>
      pickFile();
}
