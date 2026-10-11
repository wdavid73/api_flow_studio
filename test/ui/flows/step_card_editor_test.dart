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

  group('assertion editor', () {
    const endpoint = Endpoint(id: 'e-1', groupId: 'g-1', name: 'Check user', method: 'GET', url: '/exists');

    /// Keeps the step in state like the flow builder does, so edits flow back in.
    Future<ValueNotifier<FlowStep>> pumpEditor(WidgetTester tester, [FlowStep step = const FlowStep(endpointId: 'e-1')]) async {
      final notifier = ValueNotifier(step);
      await tester.pumpWidget(wrap(ValueListenableBuilder<FlowStep>(
        valueListenable: notifier,
        builder: (context, current, _) => SingleChildScrollView(
          child: StepCard(
            index: 0,
            step: current,
            endpoint: endpoint,
            isFirst: true,
            isLast: true,
            onMoveUp: () {},
            onMoveDown: () {},
            onRemove: () {},
            onUpdateStep: (s) => notifier.value = s,
          ),
        ),
      )));
      return notifier;
    }

    /// What the text field with [key] is showing (a hint is not text).
    String fieldText(WidgetTester tester, String key) => tester
        .widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText)))
        .controller
        .text;

    Future<void> chooseOperator(WidgetTester tester, int row, String label) async {
      await tester.tap(find.byKey(Key('assertion-operator-0-$row')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('a step with no assertions shows only the add button', (tester) async {
      await pumpEditor(tester);

      expect(find.byKey(const Key('add-assertion-0')), findsOneWidget);
      expect(find.byKey(const Key('assertion-field-0-0')), findsNothing);
    });

    testWidgets('the first assertion proposes response.status == 200, the next ones are blank', (tester) async {
      final step = await pumpEditor(tester);

      await tester.tap(find.byKey(const Key('add-assertion-0')));
      await tester.pumpAndSettle();
      expect(step.value.assertions, [const Assertion(field: 'response.status', expected: '200')]);
      expect(fieldText(tester, 'assertion-field-0-0'), 'response.status');

      await tester.tap(find.byKey(const Key('add-assertion-0')));
      await tester.pumpAndSettle();
      expect(step.value.assertions[1], const Assertion(field: ''));
      expect(find.byKey(const Key('assertion-field-0-1')), findsOneWidget);
    });

    testWidgets('editing the field and the expected value updates that assertion', (tester) async {
      final step = await pumpEditor(tester, const FlowStep(endpointId: 'e-1', assertions: [
        Assertion(field: 'response.status', expected: '200'),
        Assertion(field: 'response.body.id'),
      ]));

      await tester.enterText(find.byKey(const Key('assertion-field-0-1')), 'response.body.name');
      await tester.enterText(find.byKey(const Key('assertion-expected-0-1')), 'Ana');
      await tester.pump();

      expect(step.value.assertions, [
        const Assertion(field: 'response.status', expected: '200'),
        const Assertion(field: 'response.body.name', expected: 'Ana'),
      ]);
    });

    testWidgets('changing the operator updates it; exists hides the expected value and == restores it', (tester) async {
      final step = await pumpEditor(tester, const FlowStep(endpointId: 'e-1', assertions: [
        Assertion(field: 'response.body.id', expected: 'u-1'),
      ]));
      expect(find.byKey(const Key('assertion-expected-0-0')), findsOneWidget);

      await chooseOperator(tester, 0, 'exists');
      expect(step.value.assertions.single.operator, AssertionOperator.exists);
      expect(find.byKey(const Key('assertion-expected-0-0')), findsNothing);

      await chooseOperator(tester, 0, '==');
      expect(step.value.assertions.single.operator, AssertionOperator.equals);
      expect(find.byKey(const Key('assertion-expected-0-0')), findsOneWidget);
      expect(fieldText(tester, 'assertion-expected-0-0'), 'u-1');
    });

    testWidgets('removing a row drops it and the next row keeps its own values', (tester) async {
      final step = await pumpEditor(tester, const FlowStep(endpointId: 'e-1', assertions: [
        Assertion(field: 'response.status', expected: '200'),
        Assertion(field: 'response.body.name', operator: AssertionOperator.contains, expected: 'Ana'),
      ]));

      await tester.tap(find.byKey(const Key('remove-assertion-0-0')));
      await tester.pumpAndSettle();

      expect(step.value.assertions, [
        const Assertion(field: 'response.body.name', operator: AssertionOperator.contains, expected: 'Ana'),
      ]);
      expect(fieldText(tester, 'assertion-field-0-0'), 'response.body.name');
      expect(fieldText(tester, 'assertion-expected-0-0'), 'Ana');
      expect(find.byKey(const Key('assertion-field-0-1')), findsNothing);
    });

    testWidgets('a different step in the same place shows its own assertions (reorder, switch flow)', (tester) async {
      Widget cardFor(FlowStep s) => wrap(SingleChildScrollView(
            child: StepCard(
              index: 0,
              step: s,
              endpoint: endpoint,
              isFirst: true,
              isLast: true,
              onMoveUp: () {},
              onMoveDown: () {},
              onRemove: () {},
              onUpdateStep: (_) {},
            ),
          ));

      await tester.pumpWidget(cardFor(const FlowStep(endpointId: 'a', assertions: [
        Assertion(field: 'response.status', expected: '200'),
      ])));
      expect(fieldText(tester, 'assertion-field-0-0'), 'response.status');

      // Same position, same number of assertions, different step.
      await tester.pumpWidget(cardFor(const FlowStep(endpointId: 'b', assertions: [
        Assertion(field: 'response.body.name', operator: AssertionOperator.contains, expected: 'Ana'),
      ])));

      expect(fieldText(tester, 'assertion-field-0-0'), 'response.body.name');
      expect(fieldText(tester, 'assertion-expected-0-0'), 'Ana');
    });

    testWidgets('typing in a field does not rebuild it (focus and cursor survive)', (tester) async {
      await pumpEditor(tester, const FlowStep(endpointId: 'e-1', assertions: [Assertion(field: 'response.status')]));
      final before = tester.state(find.byKey(const Key('assertion-field-0-0')));

      await tester.enterText(find.byKey(const Key('assertion-field-0-0')), 'response.body.id');
      await tester.pump();

      expect(tester.state(find.byKey(const Key('assertion-field-0-0'))), same(before));
    });

    testWidgets('every operator is offered', (tester) async {
      await pumpEditor(tester, const FlowStep(endpointId: 'e-1', assertions: [Assertion(field: 'response.status')]));

      await tester.tap(find.byKey(const Key('assertion-operator-0-0')));
      await tester.pumpAndSettle();

      for (final op in AssertionOperator.values) {
        expect(find.text(op.label), findsWidgets, reason: op.name);
      }
    });
  });
}
