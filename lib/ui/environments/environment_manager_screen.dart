import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'environments_provider.dart';

/// Which environment is currently shown in the right-hand editor. UI-only,
/// not persisted (distinct from [EnvironmentsState.activeEnvironmentId],
/// which is the one requests actually resolve variables against).
final selectedEnvironmentIdProvider = StateProvider<String?>((ref) => null);

const _dotColors = [AppColors.tertiary, AppColors.secondary, AppColors.error];

class EnvironmentManagerScreen extends ConsumerWidget {
  const EnvironmentManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(environmentsProvider);

    return asyncState.when(
      data: (state) => _Loaded(state: state),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Failed to load environments: $error')),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.state});

  final EnvironmentsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestedId = ref.watch(selectedEnvironmentIdProvider);
    final selectedId =
        state.environments.any((e) => e.id == requestedId)
            ? requestedId
            : (state.environments.isNotEmpty ? state.environments.first.id : null);
    Environment? selected;
    for (final e in state.environments) {
      if (e.id == selectedId) {
        selected = e;
        break;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 260,
          child: _EnvironmentList(environments: state.environments, selectedId: selectedId),
        ),
        Expanded(
          child: selected == null
              ? const Center(
                  key: Key('no-environment-selected'),
                  child: Text('Create your first environment to get started'),
                )
              : _VariableEditor(environment: selected),
        ),
      ],
    );
  }
}

class _EnvironmentList extends ConsumerWidget {
  const _EnvironmentList({required this.environments, required this.selectedId});

  final List<Environment> environments;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          key: const Key('new-environment-button'),
          onPressed: () => ref.read(environmentsProvider.notifier).create('New Environment'),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('New Environment'),
        ),
        Expanded(
          child: environments.isEmpty
              ? const Center(
                  key: Key('empty-environments-state'),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('No environments yet — create your first one above.'),
                  ),
                )
              : ListView.builder(
                  itemCount: environments.length,
                  itemBuilder: (context, index) {
                    final env = environments[index];
                    return ListTile(
                      key: ValueKey('env-list-item-${env.id}'),
                      selected: env.id == selectedId,
                      leading: CircleAvatar(
                        radius: 5,
                        backgroundColor: _dotColors[index % _dotColors.length],
                      ),
                      title: Text(env.name),
                      subtitle: Text('${env.variables.length} variables'),
                      onTap: () => ref.read(selectedEnvironmentIdProvider.notifier).state = env.id,
                      trailing: IconButton(
                        key: ValueKey('delete-env-button-${env.id}'),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        onPressed: () => ref.read(environmentsProvider.notifier).delete(env.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _VariableEditor extends ConsumerWidget {
  const _VariableEditor({required this.environment});

  final Environment environment;

  /// The freshest known copy of [environment] at call time, via `ref.read`
  /// -- never the build-time `environment` parameter. Two edits fired
  /// back-to-back (e.g. typing in one field then immediately toggling
  /// another, both before a rebuild happens) must each build on the
  /// other's result, not a stale snapshot from when this widget was built.
  Environment _fresh(WidgetRef ref) {
    final state = ref.read(environmentsProvider).value;
    if (state == null) return environment;
    for (final e in state.environments) {
      if (e.id == environment.id) return e;
    }
    return environment;
  }

  void _mutate(
    WidgetRef ref,
    Map<String, EnvironmentVariable> Function(Map<String, EnvironmentVariable> current) update,
  ) {
    final fresh = _fresh(ref);
    final next = update(fresh.variables);
    ref.read(environmentsProvider.notifier).updateEnvironment(fresh.copyWith(variables: next));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = environment.variables.entries.toList();

    // A row's index identifies "which entry" even if a concurrent edit
    // renamed it before this callback runs (rename preserves position --
    // see onNameChanged below).
    MapEntry<String, EnvironmentVariable>? entryAt(
      Map<String, EnvironmentVariable> current,
      int index,
    ) {
      final list = current.entries.toList();
      return index < list.length ? list[index] : null;
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(environment.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < entries.length; i++)
            _VariableRow(
              // Index-keyed, not name-keyed: renaming a variable must not
              // change this row's widget identity mid-edit (the same
              // lesson as KeyValueTable's rows).
              key: ValueKey('var-row-$i'),
              name: entries[i].key,
              variable: entries[i].value,
              onNameChanged: (newName) => _mutate(ref, (current) {
                final entry = entryAt(current, i);
                if (entry == null) return current;
                final next = <String, EnvironmentVariable>{};
                for (final e in current.entries) {
                  next[e.key == entry.key ? newName : e.key] = e.value;
                }
                return next;
              }),
              onVariableChanged: (variable) => _mutate(ref, (current) {
                final entry = entryAt(current, i);
                if (entry == null) return current;
                return {...current, entry.key: variable};
              }),
              onDelete: () => _mutate(ref, (current) {
                final entry = entryAt(current, i);
                if (entry == null) return current;
                return {...current}..remove(entry.key);
              }),
            ),
          TextButton.icon(
            key: const Key('add-variable-button'),
            onPressed: () => _mutate(ref, (current) {
              var name = 'new_variable';
              var suffix = 1;
              while (current.containsKey(name)) {
                name = 'new_variable_$suffix';
                suffix++;
              }
              return {...current, name: const EnvironmentVariable(value: '')};
            }),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add variable'),
          ),
        ],
      ),
    );
  }
}

class _VariableRow extends StatelessWidget {
  const _VariableRow({
    super.key,
    required this.name,
    required this.variable,
    required this.onNameChanged,
    required this.onVariableChanged,
    required this.onDelete,
  });

  final String name;
  final EnvironmentVariable variable;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<EnvironmentVariable> onVariableChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              key: const Key('variable-name-field'),
              initialValue: name,
              decoration: const InputDecoration(hintText: 'Variable', isDense: true),
              onChanged: onNameChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextFormField(
              key: const Key('variable-value-field'),
              initialValue: variable.value,
              obscureText: variable.secret,
              decoration: const InputDecoration(hintText: 'Value', isDense: true),
              onChanged: (value) => onVariableChanged(variable.copyWith(value: value)),
            ),
          ),
          Checkbox(
            key: const Key('variable-secret-checkbox'),
            value: variable.secret,
            onChanged: (v) => onVariableChanged(variable.copyWith(secret: v ?? false)),
          ),
          IconButton(
            key: const Key('variable-delete-button'),
            icon: const Icon(Icons.close, size: 16),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
