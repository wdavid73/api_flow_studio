import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'engine/projects/projects_repository.dart';
import 'engine/storage/json_store.dart';
import 'ui/projects/projects_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(overrides: await _projectOverrides(), child: const ApiFlowStudioApp()));
}

/// Opens the projects (moving data kept by older versions into a Default
/// project the first time). If that fails the app still starts, as a single
/// project over the old data, which a failed migration never touches.
Future<List<Override>> _projectOverrides() async {
  try {
    final repository = kIsWeb ? ProjectsRepository.inMemory() : ProjectsRepository.disk(JsonStore.defaultDirectory());
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
