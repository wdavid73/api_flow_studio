import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../files/file_download.dart';

/// The system dialogs the workspace export and import go through, behind an
/// interface so tests (and journeys) can answer them without a real dialog.
abstract class WorkspaceFileDialogs {
  /// Asks where to save and writes [text] there. Returns false when the person
  /// cancels the dialog.
  Future<bool> saveText(String suggestedName, String text);

  /// Asks for a file and returns its text, or null when the person cancels.
  Future<String?> openText();
}

/// The real thing: the native save and open dialogs.
class FilePickerWorkspaceDialogs implements WorkspaceFileDialogs {
  const FilePickerWorkspaceDialogs();

  @override
  Future<bool> saveText(String suggestedName, String text) async {
    // The browser downloads the file: there is no "where to save" to ask (and nothing to cancel).
    if (kIsWeb) {
      await downloadTextFile(suggestedName, text);
      return true;
    }
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export workspace',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return false;
    await File(path).writeAsString(text);
    return true;
  }

  @override
  Future<String?> openText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Import workspace',
    );
    if (kIsWeb) {
      final bytes = result?.files.single.bytes;
      return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
    }
    final path = result?.files.single.path;
    return path == null ? null : File(path).readAsString();
  }
}

final workspaceFileDialogsProvider = Provider<WorkspaceFileDialogs>((ref) => const FilePickerWorkspaceDialogs());
