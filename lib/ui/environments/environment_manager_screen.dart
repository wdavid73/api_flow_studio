import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../shared/list_detail_layout.dart';
import '../shell/environment_kind.dart';
import '../shell/header_ghost_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'environments_provider.dart';
import '../projects/projects_provider.dart';

/// Which environment is currently shown in the right-hand editor. UI-only,
/// not persisted (distinct from [EnvironmentsState.activeEnvironmentId],
/// which is the one requests actually resolve variables against).
final selectedEnvironmentIdProvider = StateProvider<String?>((ref) {
  ref.watch(activeProjectIdProvider); // an id from another project would select nothing
  return null;
});

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

    return ListDetailLayout(
      header: ListPanelHeader(
        title: 'ENVIRONMENTS',
        actionLabel: 'New Environment',
        actionKey: const Key('new-environment-button'),
        onAction: () => ref.read(environmentsProvider.notifier).create('New Environment'),
      ),
      list: _EnvironmentList(
        environments: state.environments,
        selectedId: selectedId,
        activeId: state.activeEnvironmentId,
      ),
      detail: selected == null
          ? const Center(
              key: Key('no-environment-selected'),
              child: Text('Create your first environment to get started'),
            )
          : _VariableEditor(environment: selected),
    );
  }
}

class _EnvironmentList extends ConsumerWidget {
  const _EnvironmentList({required this.environments, required this.selectedId, required this.activeId});

  final List<Environment> environments;
  final String? selectedId;
  final String? activeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  itemCount: environments.length,
                  itemBuilder: (context, index) {
                    final env = environments[index];
                    final isSelected = env.id == selectedId;
                    final color = environmentDotColorFor(env, index);
                    final isActive = env.id == activeId;
                    final isProd = isProductionEnvironment(env.name);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Material(
                        key: Key('env-row-surface-${env.id}'),
                        color: isSelected ? AppColors.surfaceContainerHigh : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        child: InkWell(
                          key: ValueKey('env-list-item-${env.id}'),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          hoverColor: AppColors.surfaceContainer,
                          onTap: () => ref.read(selectedEnvironmentIdProvider.notifier).state = env.id,
                          child: Container(
                            key: Key('env-row-body-${env.id}'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(key: Key('env-dot-${env.id}'), radius: 5, backgroundColor: color),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(env.name, style: AppTypography.headlineSm),
                                      Text(
                                        '${env.variables.length} variables',
                                        style: AppTypography.bodySm.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isProd) _Tag(key: Key('env-prod-tag-${env.id}'), label: 'PROD', color: AppColors.error),
                                if (isActive) ...[
                                  if (isProd) const SizedBox(width: AppSpacing.xs),
                                  _Tag(key: Key('env-active-tag-${env.id}'), label: 'ACTIVE', color: color),
                                ],
                                IconButton(
                                  key: ValueKey('delete-env-button-${env.id}'),
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  onPressed: () => ref.read(environmentsProvider.notifier).delete(env.id),
                                ),
                              ],
                            ),
                          ),
                        ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(environment.name, key: const Key('env-editor-title'), style: AppTypography.title),
          const SizedBox(height: AppSpacing.md),
          if (entries.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'NAME',
                      style: AppTypography.kicker.copyWith(color: AppColors.outline),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'VALUE',
                      style: AppTypography.kicker.copyWith(color: AppColors.outline),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      'SECRET',
                      textAlign: TextAlign.center,
                      style: AppTypography.kicker.copyWith(color: AppColors.outline),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
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
          Align(
            alignment: Alignment.centerLeft,
            child: HeaderGhostButton(
              key: const Key('add-variable-button'),
              label: 'Add variable',
              onPressed: () => _mutate(ref, (current) {
                var name = 'new_variable';
                var suffix = 1;
                while (current.containsKey(name)) {
                  name = 'new_variable_$suffix';
                  suffix++;
                }
                return {...current, name: const EnvironmentVariable(value: '')};
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lightbulb_outline, size: 18, color: AppColors.secondary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pro tip: Syntax & Resolution', style: AppTypography.headlineSm),
                      const SizedBox(height: AppSpacing.xs),
                      Text.rich(
                        TextSpan(
                          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                          children: [
                            const TextSpan(
                              text: 'Reference variables anywhere across URLs, headers, and '
                                  'payloads using the ',
                            ),
                            TextSpan(
                              text: '{{variable_name}}',
                              style: AppTypography.codeSm.copyWith(color: AppColors.secondary),
                            ),
                            const TextSpan(text: ' syntax.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

/// Small uppercase status tag (`ACTIVE`, `PROD`) on an environment row.
class _Tag extends StatelessWidget {
  const _Tag({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(label, style: AppTypography.badgeMono.copyWith(color: color)),
    );
  }
}
