import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../collections/collections_provider.dart';
import '../collections/method_filter_chips.dart' show MethodChip;
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/widgets/method_badge.dart';

/// Sentinel key for endpoints whose `groupId` doesn't resolve to a known
/// [Group] (shouldn't normally happen, but keeps the picker from silently
/// dropping such endpoints).
const _uncategorizedKey = '__uncategorized__';

const _methodOrder = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/// A dialog listing every saved [Endpoint] across all collections, letting
/// the user pick one to append as the flow's next step. Returns the
/// chosen [Endpoint], or null if cancelled.
///
/// Laid out as a folder rail (left) + search/method-filtered list (right),
/// same split as the workspace sidebar, so the picker stays usable once a
/// project has dozens of saved endpoints spread across many folders.
Future<Endpoint?> showAddStepPicker(BuildContext context, WidgetRef ref) {
  final state = ref.read(collectionsProvider).value;
  final endpoints = state?.endpoints ?? const <Endpoint>[];
  final groups = state?.groups ?? const <Group>[];

  return showDialog<Endpoint>(
    context: context,
    builder: (context) => _AddStepPickerDialog(endpoints: endpoints, groups: groups),
  );
}

class _AddStepPickerDialog extends StatefulWidget {
  const _AddStepPickerDialog({required this.endpoints, required this.groups});

  final List<Endpoint> endpoints;
  final List<Group> groups;

  @override
  State<_AddStepPickerDialog> createState() => _AddStepPickerDialogState();
}

class _AddStepPickerDialogState extends State<_AddStepPickerDialog> {
  String _query = '';
  String? _selectedGroupId;
  final Set<String> _activeMethods = {};

  String _categoryKey(Endpoint endpoint) =>
      widget.groups.any((g) => g.id == endpoint.groupId) ? endpoint.groupId : _uncategorizedKey;

  String _categoryName(String key) {
    if (key == _uncategorizedKey) return 'Uncategorized';
    return widget.groups.firstWhere((g) => g.id == key).name;
  }

  List<String> _sortedCategoryKeys(Iterable<String> keys) {
    final sorted = keys.toSet().toList()
      ..sort((a, b) {
        if (a == _uncategorizedKey) return 1;
        if (b == _uncategorizedKey) return -1;
        return _categoryName(a).compareTo(_categoryName(b));
      });
    return sorted;
  }

  List<String> _sortedMethods(Iterable<String> methods) {
    final remaining = methods.toSet();
    final ordered = [for (final m in _methodOrder) if (remaining.remove(m)) m];
    final rest = remaining.toList()..sort();
    return [...ordered, ...rest];
  }

  List<TextSpan> _highlightSpans(String text, String query, TextStyle base, TextStyle match) {
    if (query.isEmpty) return [TextSpan(text: text, style: base)];
    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    var index = lower.indexOf(query, start);
    while (index != -1) {
      if (index > start) spans.add(TextSpan(text: text.substring(start, index), style: base));
      spans.add(TextSpan(text: text.substring(index, index + query.length), style: match));
      start = index + query.length;
      index = lower.indexOf(query, start);
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start), style: base));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.endpoints.isEmpty) {
      return AlertDialog(
        title: const Text('Add step'),
        content: const SizedBox(
          width: 400,
          height: 200,
          child: Center(
            key: Key('add-step-picker-empty'),
            child: Text('No saved endpoints yet — save a request first.'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ],
      );
    }

    final query = _query.trim().toLowerCase();
    bool matchesQuery(Endpoint e) =>
        query.isEmpty || e.name.toLowerCase().contains(query) || e.url.toLowerCase().contains(query);
    bool matchesMethod(Endpoint e) =>
        _activeMethods.isEmpty || _activeMethods.contains(e.method.toUpperCase());
    bool matches(Endpoint e) => matchesQuery(e) && matchesMethod(e);

    final filtered = widget.endpoints.where(matches).toList();
    final filteredByCategory = <String, List<Endpoint>>{};
    for (final e in filtered) {
      filteredByCategory.putIfAbsent(_categoryKey(e), () => []).add(e);
    }

    final allCategoryKeys = _sortedCategoryKeys(widget.endpoints.map(_categoryKey));
    final allMethods = _sortedMethods(widget.endpoints.map((e) => e.method.toUpperCase()));

    final rightList = _selectedGroupId == null
        ? filtered
        : filteredByCategory[_selectedGroupId] ?? const <Endpoint>[];

    const titleStyle = AppTypography.bodyMd;
    final matchTitleStyle = titleStyle.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700);
    final subtitleStyle = AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant);
    final matchSubtitleStyle = subtitleStyle.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700);

    Widget endpointRow(Endpoint endpoint) => ListTile(
          key: ValueKey('add-step-picker-item-${endpoint.id}'),
          dense: true,
          leading: MethodBadge(method: endpoint.method),
          title: Text.rich(TextSpan(children: _highlightSpans(endpoint.name, query, titleStyle, matchTitleStyle))),
          subtitle: Text.rich(
            TextSpan(children: _highlightSpans(endpoint.url, query, subtitleStyle, matchSubtitleStyle)),
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.of(context).pop(endpoint),
        );

    Widget categoryHeader(String key) => Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
          child: Text(
            _categoryName(key).toUpperCase(),
            style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
          ),
        );

    Widget folderRow({required String? groupId, required String label, required int count}) {
      final selected = _selectedGroupId == groupId;
      return InkWell(
        key: ValueKey(groupId == null ? 'add-step-picker-folder-all' : 'add-step-picker-folder-$groupId'),
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => setState(() => _selectedGroupId = groupId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceContainerHigh : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd.copyWith(
                    color: selected ? AppColors.onSurface : AppColors.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              Text('$count', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    Widget methodChip(String method) {
      final active = _activeMethods.contains(method);
      return MethodChip(
        key: ValueKey('add-step-picker-method-chip-$method'),
        label: method,
        color: MethodBadge.colorForMethod(method),
        selected: active,
        onTap: () => setState(() {
          if (active) {
            _activeMethods.remove(method);
          } else {
            _activeMethods.add(method);
          }
        }),
      );
    }

    return AlertDialog(
      title: const Text('Add step'),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 160,
              child: ListView(
                children: [
                  folderRow(groupId: null, label: 'All endpoints', count: filtered.length),
                  for (final key in allCategoryKeys)
                    folderRow(
                      groupId: key,
                      label: _categoryName(key),
                      count: filteredByCategory[key]?.length ?? 0,
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: AppSpacing.md * 2, color: AppColors.outlineVariant),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('add-step-picker-search-field'),
                    autofocus: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Search endpoints…',
                      prefixIcon: Icon(Icons.search, size: 16),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  if (allMethods.length > 1) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [for (final method in allMethods) methodChip(method)],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Expanded(
                    child: rightList.isEmpty
                        ? const Center(
                            key: Key('add-step-picker-no-results'),
                            child: Text('No endpoints match your search.'),
                          )
                        : _selectedGroupId == null
                            ? ListView(
                                children: [
                                  for (final key in _sortedCategoryKeys(filteredByCategory.keys)) ...[
                                    categoryHeader(key),
                                    for (final endpoint in filteredByCategory[key]!) endpointRow(endpoint),
                                  ],
                                ],
                              )
                            : ListView(children: [for (final endpoint in rightList) endpointRow(endpoint)]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      ],
    );
  }
}
