import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/hosts/host_matrix.dart';
import '../collections/collections_provider.dart';
import '../environments/environments_provider.dart';

/// Base names being edited in the open dialog. They stay as rows even when
/// their value stops being a URL, so a row never vanishes mid-keystroke. It is
/// auto-disposed with the dialog: reopening it starts from scratch.
final pinnedHostsProvider = StateProvider.autoDispose<Set<String>>((ref) => const {});

/// The hosts-by-environment matrix, rebuilt whenever the environments, the
/// saved requests or the pinned names change.
final hostMatrixProvider = Provider.autoDispose<HostMatrix>((ref) {
  final environments = ref.watch(environmentsProvider).value?.environments ?? const [];
  final endpoints = ref.watch(collectionsProvider).value?.endpoints ?? const [];
  return buildHostMatrix(environments, endpoints, const {}, pinnedNames: ref.watch(pinnedHostsProvider));
});
