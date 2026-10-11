import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets the person pick a file for a Form Data field. A service of its own so
/// tests can answer without opening the system dialog (see also
/// `WorkspaceFileDialogs`).
abstract class FilePickerService {
  /// The path of the chosen file, or null when the dialog was cancelled.
  Future<String?> pickFile();
}

/// The system "open file" dialog.
class SystemFilePickerService implements FilePickerService {
  const SystemFilePickerService();

  @override
  Future<String?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(dialogTitle: 'Choose a file to send');
    return result?.files.single.path;
  }
}

final filePickerServiceProvider = Provider<FilePickerService>((ref) => const SystemFilePickerService());
