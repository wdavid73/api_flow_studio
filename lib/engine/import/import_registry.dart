import 'app_collections_importer.dart';
import 'importer.dart';
import 'postman/postman_environment_importer.dart';

/// The formats the Import button understands, in the order they are tried. A new
/// format is one more entry here: nothing else has to change.
const List<Importer> importers = [
  AppCollectionsImporter(),
  PostmanEnvironmentImporter(),
];
