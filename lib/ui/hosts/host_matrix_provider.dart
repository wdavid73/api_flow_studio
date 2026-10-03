import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/hosts/host_matrix.dart';
import '../collections/collections_provider.dart';
import '../environments/environments_provider.dart';

/// The hosts-by-environment matrix, rebuilt whenever the environments or the
/// saved requests change.
final hostMatrixProvider = Provider<HostMatrix>((ref) {
  final environments = ref.watch(environmentsProvider).value?.environments ?? const [];
  final endpoints = ref.watch(collectionsProvider).value?.endpoints ?? const [];
  return buildHostMatrix(environments, endpoints, const {});
});
