import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppDestination {
  workspace('Workspace'),
  environments('Environments'),
  flows('Flows'),
  history('History');

  const AppDestination(this.label);

  final String label;
}

final selectedDestinationProvider = StateProvider<AppDestination>(
  (ref) => AppDestination.workspace,
);
