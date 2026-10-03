import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/hosts/host_matrix.dart';
import '../../engine/models/models.dart';
import '../environments/environments_provider.dart';
import '../shell/environment_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'host_matrix_provider.dart';
import 'host_notes_provider.dart';

const double _nameWidth = 240;
const double _environmentWidth = 230;
const double _noteWidth = 260;

/// The table: a fixed first column with each base's name and usage, one column
/// per environment with that environment's value, scrolling sideways when
/// there are many environments.
class HostMatrixTable extends ConsumerWidget {
  const HostMatrixTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = ref.watch(hostMatrixProvider);
    final activeId = ref.watch(environmentsProvider).value?.activeEnvironmentId;

    if (matrix.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          key: const Key('hosts-empty'),
          child: Text(
            'No hosts yet — add an environment variable whose value is a URL, or use Add host.',
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }

    final width = _nameWidth + _environmentWidth * matrix.environments.length + _noteWidth;

    return SingleChildScrollView(
      key: const Key('hosts-table-scroll'),
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderRow(environments: matrix.environments, activeId: activeId),
            for (final row in matrix.rows) _HostRowView(row: row, environments: matrix.environments),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.environments, required this.activeId});

  final List<Environment> environments;
  final String? activeId;

  @override
  Widget build(BuildContext context) {
    final kicker = AppTypography.kicker.copyWith(color: AppColors.outline);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outlineVariant))),
      child: Row(
        children: [
          SizedBox(width: _nameWidth, child: Text('HOST', style: kicker)),
          for (final environment in environments)
            SizedBox(
              key: Key('host-env-header-${environment.id}'),
              width: _environmentWidth,
              child: Row(
                children: [
                  if (environment.id == activeId) ...[
                    CircleAvatar(
                      key: Key('host-env-active-${environment.id}'),
                      radius: 4,
                      backgroundColor: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(child: Text(environment.name.toUpperCase(), style: kicker, overflow: TextOverflow.ellipsis)),
                  if (isProductionEnvironment(environment.name)) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      key: Key('host-env-prod-tag-${environment.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text('PROD', style: AppTypography.badgeMono.copyWith(color: AppColors.error)),
                    ),
                  ],
                ],
              ),
            ),
          SizedBox(width: _noteWidth, child: Text('NOTE', style: kicker)),
        ],
      ),
    );
  }
}

class _HostRowView extends StatelessWidget {
  const _HostRowView({required this.row, required this.environments});

  final HostRow row;
  final List<Environment> environments;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('host-row-${row.name}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outlineVariant))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _nameWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name, style: AppTypography.codeMd.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  'Used by ${row.usedBy} ${row.usedBy == 1 ? 'request' : 'requests'}',
                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          for (final environment in environments)
            _HostCell(
              key: Key('host-cell-${row.name}-${environment.id}'),
              hostName: row.name,
              environmentId: environment.id,
              value: row.valueIn(environment.id) ?? '',
            ),
          _NoteCell(key: Key('host-note-cell-${row.name}'), hostName: row.name, note: row.note),
        ],
      ),
    );
  }
}

/// One editable cell: the value of a base in one environment. Typing saves it
/// to that environment (blank removes the variable there).
class _HostCell extends ConsumerStatefulWidget {
  const _HostCell({super.key, required this.hostName, required this.environmentId, required this.value});

  final String hostName;
  final String environmentId;
  final String value;

  @override
  ConsumerState<_HostCell> createState() => _HostCellState();
}

class _HostCellState extends ConsumerState<_HostCell> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_HostCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow changes made elsewhere, but never fight what is being typed
    // (blank text and an absent value are the same thing).
    final typed = _controller.text;
    final sameBlank = typed.trim().isEmpty && widget.value.isEmpty;
    if (typed != widget.value && !sameBlank) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    // Read the freshest copy: two quick edits must each build on the other.
    final environments = ref.read(environmentsProvider).value?.environments ?? const <Environment>[];
    final environment = environments.where((e) => e.id == widget.environmentId).firstOrNull;
    if (environment == null) return;

    ref.read(pinnedHostsProvider.notifier).update((pinned) => {...pinned, widget.hostName});
    ref.read(environmentsProvider.notifier).updateEnvironment(setHostValue(environment, widget.hostName, text));
  }

  @override
  Widget build(BuildContext context) {
    final missing = widget.value.trim().isEmpty;

    return SizedBox(
      width: _environmentWidth,
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: TextField(
          key: Key('host-field-${widget.hostName}-${widget.environmentId}'),
          controller: _controller,
          style: AppTypography.codeSm,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            isDense: true,
            hintText: missing ? 'missing' : null,
            hintStyle: AppTypography.bodySm.copyWith(color: AppColors.warning),
            enabledBorder: missing
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.field),
                    borderSide: const BorderSide(color: AppColors.warning),
                  )
                : null,
          ),
          onChanged: _onChanged,
        ),
      ),
    );
  }
}

/// The note of one base, shared by all environments. Typing saves it.
class _NoteCell extends ConsumerStatefulWidget {
  const _NoteCell({super.key, required this.hostName, required this.note});

  final String hostName;
  final String note;

  @override
  ConsumerState<_NoteCell> createState() => _NoteCellState();
}

class _NoteCellState extends ConsumerState<_NoteCell> {
  late final TextEditingController _controller = TextEditingController(text: widget.note);

  @override
  void didUpdateWidget(_NoteCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final typed = _controller.text;
    final sameBlank = typed.trim().isEmpty && widget.note.isEmpty;
    if (typed != widget.note && !sameBlank) _controller.text = widget.note;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _noteWidth,
      child: TextField(
        key: Key('host-note-${widget.hostName}'),
        controller: _controller,
        style: AppTypography.bodySm,
        decoration: const InputDecoration(isDense: true, hintText: 'Note…'),
        onChanged: (text) => ref.read(hostNotesProvider.notifier).setNote(widget.hostName, text),
      ),
    );
  }
}
