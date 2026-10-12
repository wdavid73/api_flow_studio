import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'engine/projects/projects_repository.dart';
import 'engine/storage/json_store.dart';
import 'engine/storage/local_storage_backend.dart';
import 'ui/l10n/locale_provider.dart';
import 'ui/projects/projects_provider.dart';
import 'ui/shell/storage_full_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(overrides: [...await _projectOverrides(), ...await _languageOverrides()]);
  PlatformDispatcher.instance.onError = storageFullHandler(container);
  runApp(UncontrolledProviderScope(container: container, child: const ApiFlowStudioApp()));
}

/// The browser's storage, where the web keeps projects and settings (one backend, so the keys
/// of the project list, each project and the settings never meet).
final _browserStorage = LocalStorageBackend();

/// The language saved last time (kept in the data folder's root, or in the browser's storage on
/// the web; shared by every project). If it cannot be read the app follows the system language.
Future<List<Override>> _languageOverrides() async {
  final store = kIsWeb ? JsonStore.backed(_browserStorage, prefix: 'app:') : JsonStore(directory: JsonStore.defaultDirectory());
  Locale? saved;
  try {
    saved = localeFromCode(await store.readAppLocale());
  } catch (error) {
    debugPrint('Could not read the saved language: $error');
  }
  return [appSettingsStoreProvider.overrideWithValue(store), initialLocaleProvider.overrideWithValue(saved)];
}

/// Opens the projects (moving data kept by older versions into a Default
/// project the first time). If that fails the app still starts, as a single
/// project over the old data, which a failed migration never touches.
Future<List<Override>> _projectOverrides() async {
  try {
    final repository = kIsWeb ? ProjectsRepository.web(_browserStorage) : ProjectsRepository.disk(JsonStore.defaultDirectory());
    await repository.ensureDefaultProject();
    final state = await ProjectsController.load(repository);
    return [
      projectsRepositoryProvider.overrideWithValue(repository),
      initialProjectsStateProvider.overrideWithValue(state),
    ];
  } catch (error, stack) {
    debugPrint('Could not open the projects, running as a single project: $error\n$stack');
    return const [];
  }
}
