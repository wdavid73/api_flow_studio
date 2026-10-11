import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file the person picked to import: its name and size are known up front, its
/// text is read only when asked for (so a file that is too large is never loaded).
class PickedImportFile {
  const PickedImportFile({required this.name, required this.sizeBytes, required this.read});

  /// A file that already is text (tests, and anything that has the text at hand).
  factory PickedImportFile.fromText(String name, String text) =>
      PickedImportFile(name: name, sizeBytes: text.length, read: () async => text);

  final String name;
  final int sizeBytes;
  final Future<String> Function() read;
}

/// The system dialog the Import button goes through, behind an interface so tests
/// and journeys can answer it without a real dialog.
abstract interface class ImportFileDialogs {
  /// Asks for a file with one of [extensions] (no dot), or null when cancelled.
  Future<PickedImportFile?> pickFile(List<String> extensions);
}

/// The native "open file" dialog.
class FilePickerImportFileDialogs implements ImportFileDialogs {
  const FilePickerImportFileDialogs();

  @override
  Future<PickedImportFile?> pickFile(List<String> extensions) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      dialogTitle: 'Import',
    );
    final path = result?.files.single.path;
    if (path == null) return null;

    final file = File(path);
    return PickedImportFile(
      name: file.uri.pathSegments.isEmpty ? path : file.uri.pathSegments.last,
      sizeBytes: await file.length(),
      read: file.readAsString,
    );
  }
}

final importFileDialogsProvider = Provider<ImportFileDialogs>((ref) => const FilePickerImportFileDialogs());
