import '../workspace/workspace_file.dart';
import 'import_result.dart';
import 'import_source.dart';

/// The file cannot be imported; [message] says why in plain words.
class ImportException implements Exception {
  const ImportException(this.message);

  final String message;

  @override
  String toString() => 'ImportException: $message';
}

/// Turns the text of one kind of file into an [ImportResult]. Knows nothing about
/// the screen or where things are stored: new formats are new implementations in
/// the list the core is given.
abstract interface class Importer {
  /// For messages: `Postman collection`.
  String get formatName;

  /// The file extensions (without the dot) the open dialog should offer for it.
  List<String> get extensions;

  /// A cheap look at the file: is it mine? Must not throw.
  bool matches(ImportSource source);

  /// The translation. Throws [ImportException] with a readable message when the
  /// file is mine but cannot be read.
  ImportResult parse(ImportSource source);
}

const String _workspaceHint = 'This is a workspace file. Use Project ▸ Import workspace… to open it as a new project.';

/// Picks the importer that owns [text] and runs it. Throws [ImportException] when
/// nobody recognises the file, when the importer cannot read it, or when there is
/// nothing in it to import. A workspace file is explained, not imported: it makes
/// a whole project, which has its own command.
ImportResult runImport(String text, List<Importer> importers, {String? fileName}) {
  final source = ImportSource(text, fileName: fileName);
  if (_isWorkspace(source)) throw const ImportException(_workspaceHint);

  for (final importer in importers) {
    if (!_matches(importer, source)) continue;

    final ImportResult result;
    try {
      result = importer.parse(source);
    } on ImportException {
      rethrow;
    } catch (_) {
      // An importer that stumbles on a shape it did not expect is a damaged file to the person.
      throw ImportException('That file looks like ${importer.formatName} but is damaged or incomplete.');
    }
    if (result.endpoints.isEmpty && result.environments.isEmpty) {
      throw ImportException('Nothing to import: ${importer.formatName} had no requests.');
    }
    return result;
  }

  if (source.json == null && (fileName ?? '').toLowerCase().endsWith('.json')) {
    throw const ImportException('That file is not valid JSON.');
  }
  throw ImportException('That file is not a format I can import. Supported: ${importers.map((i) => i.formatName).join(', ')}.');
}

/// Every extension the importers accept, in order and without repeats.
List<String> supportedExtensions(List<Importer> importers) => {for (final i in importers) ...i.extensions}.toList();

bool _matches(Importer importer, ImportSource source) {
  try {
    return importer.matches(source);
  } catch (_) {
    return false;
  }
}

bool _isWorkspace(ImportSource source) {
  final json = source.json;
  return json is Map && json['format'] == workspaceFormat;
}
