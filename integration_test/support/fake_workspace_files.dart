import 'package:api_flow_studio/ui/workspace_transfer/workspace_file_dialogs.dart';

/// Stands in for the system save and open dialogs during a journey: what the app
/// "saves" is kept here, and what it "opens" is whatever the journey puts in
/// [textToOpen]. A journey never touches a real file picker.
class FakeWorkspaceFiles implements WorkspaceFileDialogs {
  /// The name the app suggested for the last file it saved, or null.
  String? savedName;

  /// The text of the last file the app saved, or null.
  String? savedText;

  /// The text the next open dialog returns; null means the person cancels.
  String? textToOpen;

  @override
  Future<bool> saveText(String suggestedName, String text) async {
    savedName = suggestedName;
    savedText = text;
    return true;
  }

  @override
  Future<String?> openText() async => textToOpen;
}
