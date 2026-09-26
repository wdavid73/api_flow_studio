import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/ui/flows/step_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('adding an extract row and filling it in reports the updated step', (tester) async {
    FlowStep? updated;
    const step = FlowStep(endpointId: 'e-1');
    const endpoint = Endpoint(id: 'e-1', groupId: 'g-1', name: 'Check user', method: 'GET', url: '/exists');

    await tester.pumpWidget(wrap(StepCard(
      index: 0,
      step: step,
      endpoint: endpoint,
      isFirst: true,
      isLast: true,
      onMoveUp: () {},
      onMoveDown: () {},
      onRemove: () {},
      onUpdateStep: (s) => updated = s,
    )));

    await tester.tap(find.byKey(const Key('add-extract-0')));
    await tester.pump();
    expect(updated, isNotNull);
    expect(updated!.extract, {'variable': ''});

    await tester.pumpWidget(wrap(StepCard(
      index: 0,
      step: updated!,
      endpoint: endpoint,
      isFirst: true,
      isLast: true,
      onMoveUp: () {},
      onMoveDown: () {},
      onRemove: () {},
      onUpdateStep: (s) => updated = s,
    )));

    await tester.enterText(find.byKey(const Key('extract-name-0-0')), 'user_id');
    await tester.pump();
    expect(updated!.extract, {'user_id': ''});

    await tester.pumpWidget(wrap(StepCard(
      index: 0,
      step: updated!,
      endpoint: endpoint,
      isFirst: true,
      isLast: true,
      onMoveUp: () {},
      onMoveDown: () {},
      onRemove: () {},
      onUpdateStep: (s) => updated = s,
    )));

    await tester.enterText(find.byKey(const Key('extract-path-0-0')), 'response.body.id');
    await tester.pump();
    expect(updated!.extract, {'user_id': 'response.body.id'});
  });

  testWidgets('removing an extract row drops it from the map', (tester) async {
    FlowStep? updated;
    const step = FlowStep(endpointId: 'e-1', extract: {'user_id': 'response.body.id'});
    const endpoint = Endpoint(id: 'e-1', groupId: 'g-1', name: 'Check user', method: 'GET', url: '/exists');

    await tester.pumpWidget(wrap(StepCard(
      index: 0,
      step: step,
      endpoint: endpoint,
      isFirst: true,
      isLast: true,
      onMoveUp: () {},
      onMoveDown: () {},
      onRemove: () {},
      onUpdateStep: (s) => updated = s,
    )));

    await tester.tap(find.byKey(const Key('remove-extract-0-0')));
    await tester.pump();

    expect(updated!.extract, isEmpty);
  });

  testWidgets('toggling stop on failure reports the flipped value', (tester) async {
    FlowStep? updated;
    const step = FlowStep(endpointId: 'e-1');
    const endpoint = Endpoint(id: 'e-1', groupId: 'g-1', name: 'Check user', method: 'GET', url: '/exists');

    await tester.pumpWidget(wrap(StepCard(
      index: 0,
      step: step,
      endpoint: endpoint,
      isFirst: true,
      isLast: true,
      onMoveUp: () {},
      onMoveDown: () {},
      onRemove: () {},
      onUpdateStep: (s) => updated = s,
    )));

    expect(step.stopOnFailure, isTrue);
    await tester.tap(find.byKey(const Key('stop-on-failure-0')));
    await tester.pump();

    expect(updated!.stopOnFailure, isFalse);
  });

  testWidgets('filling assert field and expected value reports both', (tester) async {
    FlowStep? updated;
    const step = FlowStep(endpointId: 'e-1');
    const endpoint = Endpoint(id: 'e-1', groupId: 'g-1', name: 'Check user', method: 'GET', url: '/exists');

    await tester.pumpWidget(wrap(StepCard(
      index: 0,
      step: step,
      endpoint: endpoint,
      isFirst: true,
      isLast: true,
      onMoveUp: () {},
      onMoveDown: () {},
      onRemove: () {},
      onUpdateStep: (s) => updated = s,
    )));

    await tester.enterText(find.byKey(const Key('assert-field-0')), 'response.status');
    await tester.pump();
    expect(updated!.assertField, 'response.status');

    await tester.pumpWidget(wrap(StepCard(
      index: 0,
      step: updated!,
      endpoint: endpoint,
      isFirst: true,
      isLast: true,
      onMoveUp: () {},
      onMoveDown: () {},
      onRemove: () {},
      onUpdateStep: (s) => updated = s,
    )));

    await tester.enterText(find.byKey(const Key('assert-expected-0')), '200');
    await tester.pump();
    expect(updated!.assertExpected, '200');
  });
}
