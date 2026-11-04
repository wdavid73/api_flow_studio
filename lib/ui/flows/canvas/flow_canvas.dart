import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/flows/flow_step_result.dart';
import '../../../engine/flows/flow_wiring.dart';
import '../../../engine/flows/input_origin.dart';
import '../../../engine/models/models.dart';
import '../../../l10n/l10n.dart';
import '../../environments/environments_provider.dart';
import '../../session/session_provider.dart';
import '../../shell/app_toast.dart';
import '../../shell/header_ghost_button.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/widgets/status_badge.dart';
import '../add_step_picker.dart';
import '../flow_run_provider.dart';
import '../flows_provider.dart';
import '../flows_screen.dart' show selectedStepIndexProvider, stepPanelTabProvider;
import '../step_response.dart';
import 'canvas_metrics.dart';
import 'node_model.dart';
import 'run_actions.dart';
import 'step_node.dart';
import 'step_panel.dart';
import 'wire_geometry.dart';
import 'wire_painter.dart';

/// The flow's steps as nodes in one row, left to right in run order, on a
/// dotted canvas that scrolls both ways and zooms (buttons, or Ctrl + wheel).
/// The layout is automatic: nodes cannot be placed by hand, only moved
/// left/right from their menu. Wires show which response field feeds which
/// input; dragging a field's pin onto an input of a later step connects them.
class FlowCanvas extends ConsumerStatefulWidget {
  const FlowCanvas({super.key, required this.flow, required this.endpoints});

  final Flow flow;
  final Map<String, Endpoint> endpoints;

  @override
  ConsumerState<FlowCanvas> createState() => _FlowCanvasState();
}

class _FlowCanvasState extends ConsumerState<FlowCanvas> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  final _contentKey = GlobalKey();
  double _zoom = 1;

  /// The field whose pin is being dragged (its step and row), and where the
  /// pointer is, in canvas coordinates.
  ({int step, int field})? _drag;
  Offset? _ghostTo;

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  void _setZoom(double zoom) => setState(() => _zoom = ((zoom.clamp(minZoom, maxZoom)) * 100).round() / 100);

  Flow get _flow => widget.flow;

  FlowsNotifier get _flows => ref.read(flowsProvider.notifier);

  FlowRunNotifier get _run => ref.read(flowRunProvider(_flow.id).notifier);

  StateController<int?> get _selection => ref.read(selectedStepIndexProvider.notifier);

  Future<void> _addStep() async {
    final endpoint = await showAddStepPicker(context, ref);
    if (endpoint != null) await _flows.addStep(_flow.id, FlowStep(endpointId: endpoint.id));
  }

  void _dragUpdate(int step, int field, Offset globalPosition) {
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() {
      _drag = (step: step, field: field);
      _ghostTo = box.globalToLocal(globalPosition);
    });
  }

  void _dragEnd() => setState(() {
        _drag = null;
        _ghostTo = null;
      });

  /// Connects [drag]'s field to the input [variable] of step [toStep], or says
  /// why not when a step in between already sets that name.
  Future<void> _connect(FieldDrag drag, int toStep, String variable) async {
    switch (connectField(_flow, fromStep: drag.stepIndex, path: drag.path, toStep: toStep, variable: variable)) {
      case Connected(:final step):
        await _flows.updateStep(_flow.id, drag.stepIndex, step);
      case Shadowed(:final stepIndex):
        final name = widget.endpoints[_flow.steps[stepIndex].endpointId]?.name ?? '${stepIndex + 1}';
        showToast(ref, context.l10n.wireShadowed(name, '{{$variable}}'));
    }
  }

  /// The menu of an input fed by an earlier step: Disconnect, saying how many
  /// steps lose that value.
  Future<void> _showDisconnect(int toStep, String variable, Offset globalPosition) async {
    final environment = ref.read(environmentsProvider).value?.active?.resolvedVariables ?? const <String, String>{};
    final origin = resolveInputOrigin(_flow, toStep, variable, environment);
    if (origin is! FromStep) return;
    final consumers =
        consumersOf(_flow, widget.endpoints, environment, fromStep: origin.stepIndex, variable: variable);
    final l10n = context.l10n;
    final disconnect = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy, globalPosition.dx, globalPosition.dy),
      items: [
        PopupMenuItem(
          key: ValueKey('disconnect-$toStep-$variable'),
          value: true,
          child: Text(consumers > 1 ? '${l10n.wireDisconnect} · ${l10n.wireUsedBy(consumers)}' : l10n.wireDisconnect),
        ),
      ],
    );
    if (disconnect != true) return;
    await _flows.updateStep(
      _flow.id,
      origin.stepIndex,
      disconnectVariable(_flow, fromStep: origin.stepIndex, variable: variable),
    );
  }

  void _select(int index) {
    ref.read(stepPanelTabProvider.notifier).state = StepPanelTab.step;
    _selection.state = index;
  }

  Future<void> _onAction(int index, StepNodeAction action) async {
    switch (action) {
      case StepNodeAction.runUntil:
        await runAndShow(ref, _flow.id, (run) => run.runUntil(_flow, widget.endpoints, index));
      case StepNodeAction.rerunFrom:
        await runAndShow(ref, _flow.id, (run) => run.rerunFrom(_flow, widget.endpoints, index));
      case StepNodeAction.changeRequest:
        final picked = await showAddStepPicker(context, ref);
        if (picked == null) return;
        await _flows.updateStep(_flow.id, index, _flow.steps[index].copyWith(endpointId: picked.id));
        _run.clearFrom(index);
      case StepNodeAction.moveLeft:
        await _move(index, index - 1);
      case StepNodeAction.moveRight:
        await _move(index, index + 1);
      case StepNodeAction.delete:
        await _flows.removeStep(_flow.id, index);
        _run.clearFrom(index);
        final selected = _selection.state;
        if (selected == index) {
          _selection.state = null;
        } else if (selected != null && selected > index) {
          _selection.state = selected - 1;
        }
    }
  }

  Future<void> _move(int from, int to) async {
    await _flows.reorderStep(_flow.id, from, to);
    _run.clearFrom(math.min(from, to));
    final selected = _selection.state;
    if (selected == from) {
      _selection.state = to;
    } else if (selected == to) {
      _selection.state = from;
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    final environment = ref.watch(environmentsProvider).value?.active?.resolvedVariables ?? const <String, String>{};
    final session = ref.watch(activeSessionProvider);
    final selected = ref.watch(selectedStepIndexProvider);
    final run = ref.watch(flowRunProvider(flow.id));
    final running = run.running;

    final models = [
      for (var i = 0; i < flow.steps.length; i++)
        buildNodeModel(
          flow: flow,
          index: i,
          endpoint: widget.endpoints[flow.steps[i].endpointId],
          response: ref
              .watch(stepResponseProvider((flowId: flow.id, index: i, endpointId: flow.steps[i].endpointId)))
              .value,
          environmentVariables: environment,
          sessionAttachAuth: session.attachAuth,
        ),
    ];

    final count = models.length;
    final contentWidth = nodeLeft(count) + addNodeWidth + canvasPadding;
    final tallest = models.fold<double>(addNodeHeight + 48, (h, m) => math.max(h, m.height));
    final contentHeight = canvasPadding * 2 + tallest;
    final wires = computeWires(models);
    final drag = _drag;

    Widget content(double width, double height) => SizedBox(
          key: const Key('flow-canvas-content'),
          width: width,
          height: height,
          child: Stack(
            key: _contentKey,
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
              Positioned.fill(
                child: CustomPaint(
                  painter: WirePainter(
                    wires: wires,
                    ghostFrom: drag == null ? null : _ghostStart(models, drag),
                    ghostTo: _ghostTo,
                  ),
                ),
              ),
              for (final wire in wires)
                Positioned(
                  key: ValueKey('wire-${wire.fromStep}-${wire.toStep}-${wire.variable}'),
                  left: wire.midpoint.dx - 6,
                  top: wire.midpoint.dy - 6,
                  width: 12,
                  height: 12,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _showDisconnect(wire.toStep, wire.variable, details.globalPosition),
                    child: const MouseRegion(cursor: SystemMouseCursors.click),
                  ),
                ),
              for (var i = 0; i + 1 < count; i++)
                Positioned(
                  left: nodeLeft(i) + nodeWidth + (nodeGap - 20) / 2,
                  top: canvasPadding + headerHeight / 2 - 10,
                  child: const Icon(Icons.arrow_forward, size: 20, color: AppColors.outline),
                ),
              for (final model in models)
                Positioned(
                  left: nodeLeft(model.index) - pinOverhang,
                  top: canvasPadding,
                  child: StepNode(
                    model: model,
                    flow: flow,
                    endpoints: widget.endpoints,
                    selected: selected == model.index,
                    captureTokens: session.captureTokens,
                    locked: running,
                    hasRunResults: run.results.any((r) => r != null),
                    status: _status(context, run, model),
                    dragFromStep: drag?.step,
                    onSelect: () => _select(model.index),
                    onAction: (action) => _onAction(model.index, action),
                    onFieldDragUpdate: (field, position) => _dragUpdate(model.index, field, position),
                    onFieldDragEnd: _dragEnd,
                    onConnect: (variable, fieldDrag) => _connect(fieldDrag, model.index, variable),
                    onOriginTap: (variable, position) => _showDisconnect(model.index, variable, position),
                  ),
                ),
              Positioned(
                left: nodeLeft(count),
                top: canvasPadding,
                width: addNodeWidth,
                height: addNodeHeight,
                child: Center(
                  child: HeaderGhostButton(
                    key: const Key('add-step-button'),
                    label: count == 0 ? context.l10n.canvasAddFirstStep : context.l10n.canvasAddStep,
                    onPressed: running ? () {} : _addStep,
                  ),
                ),
              ),
              if (count == 0)
                Positioned(
                  left: canvasPadding,
                  top: canvasPadding + addNodeHeight + AppSpacing.sm,
                  child: Text(
                    context.l10n.flowsNoSteps,
                    key: const Key('empty-flow-state'),
                    style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        // The canvas fills the view (dots everywhere) and grows past it when the row is longer.
        final width = math.max(contentWidth, constraints.maxWidth / _zoom);
        final height = math.max(contentHeight, constraints.maxHeight / _zoom);
        return Stack(
          key: const Key('flow-canvas'),
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.surfaceContainerLowest,
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent && HardwareKeyboard.instance.isControlPressed) {
                      _setZoom(_zoom + (event.scrollDelta.dy < 0 ? zoomStep : -zoomStep));
                    }
                  },
                  child: Scrollbar(
                    controller: _vertical,
                    notificationPredicate: (notification) => notification.depth == 1,
                    child: Scrollbar(
                      controller: _horizontal,
                      child: SingleChildScrollView(
                        controller: _horizontal,
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _vertical,
                          child: SizedBox(
                            width: width * _zoom,
                            height: height * _zoom,
                            child: FittedBox(
                              fit: BoxFit.fill,
                              alignment: Alignment.topLeft,
                              child: content(width, height),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: _ZoomControls(
                zoom: _zoom,
                onZoom: _setZoom,
                onFit: () => _setZoom(constraints.maxWidth / contentWidth),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Where the ghost wire of a drag starts: the dragged field's pin.
  Offset? _ghostStart(List<NodeModel> models, ({int step, int field}) drag) {
    if (drag.step >= models.length) return null;
    final model = models[drag.step];
    if (drag.field >= model.visibleFields.length) return null;
    return fieldPinOffset(model, drag.field);
  }
}

/// The right of a node's header: a spinner while its result is on the way,
/// then the status code (or a mark for a failure without one, or "Skipped"),
/// or "not sent" when there is nothing to show at all.
Widget? _status(BuildContext context, FlowRunState run, NodeModel model) {
  final index = model.index;
  final result = index < run.results.length ? run.results[index] : null;
  final Widget? child;
  if (run.isPending(index)) {
    child = const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2));
  } else if (result?.status == FlowStepStatus.skipped) {
    child = Text(context.l10n.runSkippedStep, style: AppTypography.bodySm.copyWith(color: AppColors.outline));
  } else if (result?.response?.status != null) {
    child = StatusBadge(statusCode: result!.response!.status!);
  } else if (result?.status == FlowStepStatus.failure) {
    child = const Icon(Icons.error_outline, size: 16, color: AppColors.error);
  } else if (!model.hasResponse) {
    child = Text(context.l10n.canvasNotRun, style: AppTypography.bodySm.copyWith(color: AppColors.outline));
  } else {
    child = null;
  }
  if (child == null) return null;
  return Padding(
    padding: const EdgeInsets.only(left: AppSpacing.xs),
    child: KeyedSubtree(key: ValueKey('step-node-status-$index'), child: child),
  );
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.zoom, required this.onZoom, required this.onFit});

  final double zoom;
  final ValueChanged<double> onZoom;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('zoom-out'),
                tooltip: context.l10n.canvasZoomOut,
                iconSize: 16,
                icon: const Icon(Icons.remove),
                onPressed: () => onZoom(zoom - zoomStep),
              ),
              Text('${(zoom * 100).round()}%', key: const Key('zoom-level'), style: AppTypography.codeSm),
              IconButton(
                key: const Key('zoom-in'),
                tooltip: context.l10n.canvasZoomIn,
                iconSize: 16,
                icon: const Icon(Icons.add),
                onPressed: () => onZoom(zoom + zoomStep),
              ),
              TextButton(key: const Key('zoom-fit'), onPressed: onFit, child: Text(context.l10n.canvasZoomFit)),
            ],
          ),
        ),
      );
}

/// The canvas background: a faint dot every 16 px.
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.outlineVariant;
    for (double x = 8; x < size.width; x += 16) {
      for (double y = 8; y < size.height; y += 16) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) => false;
}
