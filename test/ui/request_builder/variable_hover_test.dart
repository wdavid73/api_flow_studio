import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/request_builder/variable_hover.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late TextEditingController text;

  Future<void> pumpField(WidgetTester tester, {bool withEnvironment = true}) async {
    final store = JsonStore.inMemory();
    if (withEnvironment) {
      await store.writeEnvironments(const [
        Environment(id: 'env-1', name: 'Dev', variables: {'base_url': EnvironmentVariable(value: 'https://dev.test')}),
      ]);
      await store.writeActiveEnvironmentId('env-1');
    }
    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    await container.read(environmentsProvider.future);

    text = TextEditingController(text: '{{base_url}}/users/{{missing}}');
    addTearDown(text.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(40),
              child: VariableHover(child: TextField(key: const Key('field'), controller: text)),
            ),
          ),
        ),
      ),
    );
  }

  Future<TestGesture> hoverAt(WidgetTester tester, Offset position) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(position);
    await tester.pump();
    return mouse;
  }

  Offset startOfField(WidgetTester tester) => tester.getTopLeft(find.byKey(const Key('field'))) + const Offset(24, 20);

  testWidgets('hovering a resolved variable shows its value in an editable input', (tester) async {
    await pumpField(tester);

    await hoverAt(tester, startOfField(tester));

    expect(find.byKey(const Key('variable-hover-card')), findsOneWidget);
    expect(find.text('{{base_url}}'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('variable-hover-field'))).controller!.text, 'https://dev.test');

    await tester.enterText(find.byKey(const Key('variable-hover-field')), 'https://qa.test');
    await tester.pump();

    final active = container.read(environmentsProvider).value!.active!;
    expect(active.variables['base_url']!.value, 'https://qa.test');
  });

  testWidgets('moving off the variable closes the card', (tester) async {
    await pumpField(tester);

    final mouse = await hoverAt(tester, startOfField(tester));
    expect(find.byKey(const Key('variable-hover-card')), findsOneWidget);

    // Past the end of the text: nothing to show.
    await mouse.moveTo(tester.getTopRight(find.byKey(const Key('field'))) + const Offset(-10, 20));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('variable-hover-card')), findsNothing);
  });

  testWidgets('an undefined variable starts empty and typing a value creates it', (tester) async {
    await pumpField(tester);
    text.text = '{{missing}}';
    await tester.pump();

    await hoverAt(tester, startOfField(tester));
    expect(tester.widget<TextField>(find.byKey(const Key('variable-hover-field'))).controller!.text, '');

    await tester.enterText(find.byKey(const Key('variable-hover-field')), 'now defined');
    await tester.pump();

    final active = container.read(environmentsProvider).value!.active!;
    expect(active.variables['missing']!.value, 'now defined');
  });

  testWidgets('without an active environment the input is disabled', (tester) async {
    await pumpField(tester, withEnvironment: false);

    await hoverAt(tester, startOfField(tester));

    expect(tester.widget<TextField>(find.byKey(const Key('variable-hover-field'))).enabled, isFalse);
  });
}
