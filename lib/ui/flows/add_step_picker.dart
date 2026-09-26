import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../collections/collections_provider.dart';
import '../theme/widgets/method_badge.dart';

/// A dialog listing every saved [Endpoint] across all collections, letting
/// the user pick one to append as the flow's next step. Returns the
/// chosen [Endpoint], or null if cancelled.
Future<Endpoint?> showAddStepPicker(BuildContext context, WidgetRef ref) {
  final state = ref.read(collectionsProvider).value;
  final endpoints = state?.endpoints ?? const <Endpoint>[];

  return showDialog<Endpoint>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add step'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: endpoints.isEmpty
            ? const Center(
                key: Key('add-step-picker-empty'),
                child: Text('No saved endpoints yet — save a request first.'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: endpoints.length,
                itemBuilder: (context, index) {
                  final endpoint = endpoints[index];
                  return ListTile(
                    key: ValueKey('add-step-picker-item-${endpoint.id}'),
                    leading: MethodBadge(method: endpoint.method),
                    title: Text(endpoint.name),
                    subtitle: Text(endpoint.url, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(context).pop(endpoint),
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      ],
    ),
  );
}
