import 'package:api_flow_studio/ui/import/import_file_dialogs.dart';

/// Stands in for the "open file" dialog of the Import button during a journey: the
/// app "opens" whatever the journey puts in [next] (null = the person cancels).
class FakeImportFileDialogs implements ImportFileDialogs {
  PickedImportFile? next;

  @override
  Future<PickedImportFile?> pickFile(List<String> extensions) async => next;
}
