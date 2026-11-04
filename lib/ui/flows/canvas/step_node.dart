import 'package:flutter/material.dart' hide Flow;

import '../../../engine/flows/response_fields.dart';
import '../../../engine/models/models.dart';
import '../../../engine/session/token_finder.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/widgets/method_badge.dart';
import '../step_response.dart';
import 'canvas_metrics.dart';
import 'node_model.dart';
import 'origin_label.dart';
import 'relative_age.dart';

enum StepNodeAction { runUntil, rerunFrom, changeRequest, moveLeft, moveRight, delete }

const double _pinSize = 10;

/// One step on the canvas: header (method, name, status, menu), the request
/// path, its INPUTS with where each comes from, and the fields of its last
/// RESPONSE. Every section has the fixed height [canvas_metrics] gives it, so
/// the pins drawn on the edges sit where the wires expect them.
class StepNode extends StatelessWidget {
  const StepNode({
    super.key,
    required this.model,
    required this.flow,
    required this.endpoints,
    required this.selected,
    required this.captureTokens,
    required this.onSelect,
    required this.onAction,
    this.status,
    this.locked = false,
    this.hasRunResults = false,
  });

  final NodeModel model;
  final Flow flow;
  final Map<String, Endpoint> endpoints;
  final bool selected;

  /// Whether the session picks tokens out of responses (tags token fields).
  final bool captureTokens;
  final VoidCallback onSelect;
  final ValueChanged<StepNodeAction> onAction;

  /// What the header shows on the right: the last run's outcome.
  final Widget? status;

  /// A run is in progress: actions that change the flow are disabled.
  final bool locked;

  /// The flow has results in this session, so it can be run again from here.
  final bool hasRunResults;

  int get _index => model.index;

  @override
  Widget build(BuildContext context) {
    final index = _index;
    return SizedBox(
      key: ValueKey('step-node-$index'),
      width: nodeWidth,
      height: model.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: AppColors.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                side: BorderSide(
                  color: selected ? AppColors.primaryContainer : AppColors.outlineVariant,
                  width: selected ? 1.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onSelect,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context),
                    SizedBox(
                      height: pathHeight,
                      child: _padded(Text(
                        model.endpoint?.url ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.codeSm.copyWith(color: AppColors.onSurfaceVariant),
                      )),
                    ),
                    _sectionLabel(context.l10n.canvasInputs),
                    for (final row in model.inputs) _inputRow(context, row),
                    const SizedBox(height: sectionGap, child: Divider(height: sectionGap)),
                    _sectionLabel(_responseLabel(context)),
                    ..._responseRows(context),
                    const SizedBox(height: nodeBottomPadding),
                  ],
                ),
              ),
            ),
          ),
          for (var row = 0; row < model.inputs.length; row++)
            if (model.inputs[row].kind == InputRowKind.variable)
              _pin(Offset(0, inputRowCenterY(row)), color: AppColors.primary),
          for (var k = 0; k < model.visibleFields.length; k++)
            _pin(
              Offset(nodeWidth, fieldRowCenterY(model.inputs.length, k)),
              key: ValueKey('step-field-pin-$index-$k'),
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _padded(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Align(alignment: Alignment.centerLeft, child: child),
      );

  Widget _header(BuildContext context) {
    final endpoint = model.endpoint;
    final index = _index;
    return SizedBox(
      height: headerHeight,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
        child: Row(
          children: [
            if (endpoint != null) ...[
              MethodBadge(method: endpoint.method),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(endpoint.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.headlineSm),
              ),
            ] else
              Expanded(
                child: Text(
                  context.l10n.canvasMissingRequest,
                  key: ValueKey('step-node-missing-$index'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSm.copyWith(color: AppColors.error),
                ),
              ),
            ?status,
            SizedBox(
              width: 32,
              height: 32,
              child: PopupMenuButton<StepNodeAction>(
                key: ValueKey('step-node-menu-$index'),
                enabled: !locked,
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: const Icon(Icons.more_vert),
                onSelected: onAction,
                itemBuilder: (context) => [
                  _item(StepNodeAction.runUntil, 'run-until', context.l10n.canvasRunUntilHere),
                  if (hasRunResults)
                    _item(StepNodeAction.rerunFrom, 'rerun-from', context.l10n.canvasRerunFromHere),
                  _item(StepNodeAction.changeRequest, 'change-request', context.l10n.stepChangeRequest),
                  _item(StepNodeAction.moveLeft, 'move-left', context.l10n.canvasMoveLeft, enabled: index > 0),
                  _item(
                    StepNodeAction.moveRight,
                    'move-right',
                    context.l10n.canvasMoveRight,
                    enabled: index < flow.steps.length - 1,
                  ),
                  _item(StepNodeAction.delete, 'delete', context.l10n.canvasDeleteStep),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<StepNodeAction> _item(StepNodeAction action, String key, String label, {bool enabled = true}) =>
      PopupMenuItem(
        key: ValueKey('step-node-$key-$_index'),
        value: action,
        enabled: enabled,
        child: Text(label),
      );

  Widget _sectionLabel(String text) => SizedBox(
        height: sectionLabelHeight,
        child: _padded(Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
        )),
      );

  String _responseLabel(BuildContext context) {
    final response = model.response;
    final at = response?.at;
    if (response == null || at == null) return context.l10n.canvasResponse;
    final age = relativeAge(context, at);
    final source = response.source == StepResponseSource.run
        ? context.l10n.canvasSourceRun(age)
        : context.l10n.canvasSourceHistory(age);
    return '${context.l10n.canvasResponse} · $source';
  }

  Widget _inputRow(BuildContext context, InputRow row) {
    final index = _index;
    final (String origin, Color color) = switch (row.kind) {
      InputRowKind.variable => (
          originLabel(context, row.origin!, flow, endpoints),
          originColor(row.origin!),
        ),
      InputRowKind.generated => (context.l10n.canvasOriginGenerated, AppColors.onSurfaceVariant),
      InputRowKind.session => (context.l10n.canvasOriginSession, AppColors.warning),
      InputRowKind.none => ('', AppColors.onSurfaceVariant),
    };
    final isVariable = row.kind == InputRowKind.variable;
    return SizedBox(
      key: isVariable ? ValueKey('step-input-$index-${row.label}') : null,
      height: rowHeight,
      child: _padded(Row(
        children: [
          Expanded(
            child: Text(
              row.kind == InputRowKind.none ? context.l10n.canvasNoInputs : row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: row.kind == InputRowKind.none
                  ? AppTypography.bodySm.copyWith(color: AppColors.outline)
                  : AppTypography.codeSm.copyWith(
                      color: row.kind == InputRowKind.session ? AppColors.onSurfaceVariant : AppColors.primary,
                    ),
            ),
          ),
          if (origin.isNotEmpty)
            KeyedSubtree(
              key: isVariable ? ValueKey('step-input-origin-$index-${row.label}') : null,
              child: Text(origin, style: AppTypography.bodySm.copyWith(color: color)),
            ),
        ],
      )),
    );
  }

  List<Widget> _responseRows(BuildContext context) {
    final response = model.response;
    if (response == null) {
      return [
        SizedBox(
          height: emptyResponseHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(context.l10n.canvasNotSent, style: AppTypography.bodySm.copyWith(color: AppColors.outline)),
              TextButton(
                key: ValueKey('run-until-$_index'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
                onPressed: locked || model.endpoint == null ? null : () => onAction(StepNodeAction.runUntil),
                child: Text('▶ ${context.l10n.canvasRunUntilHere}', style: AppTypography.bodySm),
              ),
            ],
          ),
        ),
      ];
    }
    final fields = model.visibleFields;
    final extractedAs = {for (final entry in model.extract.entries) entry.value: entry.key};
    return [
      if (fields.isEmpty)
        SizedBox(
          height: rowHeight,
          child: _padded(Text(
            response.truncated ? context.l10n.canvasTruncated : context.l10n.canvasNotJson,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySm.copyWith(color: AppColors.warning),
          )),
        ),
      for (var k = 0; k < fields.length; k++) _fieldRow(context, k, fields[k], extractedAs[fields[k].path]),
      if (model.hiddenFieldCount > 0)
        SizedBox(
          height: rowHeight,
          child: _padded(Text(
            context.l10n.canvasMoreFields(model.hiddenFieldCount),
            style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          )),
        ),
    ];
  }

  Widget _fieldRow(BuildContext context, int k, ResponseField field, String? extractedAs) {
    final key = field.path.split('.').last;
    final (String tag, Color color) = extractedAs != null
        ? ('→ {{$extractedAs}}', AppColors.primary)
        : captureTokens && isSessionTokenKey(key)
            ? (context.l10n.canvasTokenToSession, AppColors.warning)
            : (field.preview, AppColors.onSurfaceVariant);
    return SizedBox(
      key: ValueKey('step-field-$_index-$k'),
      height: rowHeight,
      child: _padded(Row(
        children: [
          Flexible(
            child: Text(
              displayPath(field.path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.codeSm.copyWith(color: AppColors.onSurface),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              tag,
              maxLines: 1,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.codeSm.copyWith(color: color),
            ),
          ),
        ],
      )),
    );
  }

  Widget _pin(Offset center, {Key? key, required Color color}) => Positioned(
        key: key,
        left: center.dx - _pinSize / 2,
        top: center.dy - _pinSize / 2,
        width: _pinSize,
        height: _pinSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surfaceContainerLowest, width: 2),
          ),
        ),
      );
}
