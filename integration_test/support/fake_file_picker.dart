import 'package:api_flow_studio/ui/request_builder/file_picker_service.dart';

/// Stands in for the system "choose a file" dialog during a journey: the app
/// "picks" whatever the journey puts in [pathToPick] (null = the person cancels).
class FakeFilePickerService implements FilePickerService {
  String? pathToPick;

  @override
  Future<String?> pickFile() async => pathToPick;
}
