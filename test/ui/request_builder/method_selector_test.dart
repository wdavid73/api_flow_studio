import 'package:api_flow_studio/ui/request_builder/method_selector.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:api_flow_studio/ui/theme/widgets/method_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpSelector(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: Center(child: MethodSelector()))),
      ),
    );
  }

  Color? selectedColor(WidgetTester tester, String label) => tester
      .widget<Text>(find.descendant(of: find.byKey(const Key('method-selector')), matching: find.text(label)))
      .style
      ?.color;

  testWidgets('shows the current method in its verb color', (tester) async {
    await pumpSelector(tester);

    expect(selectedColor(tester, 'GET'), MethodBadge.colorForMethod('GET'));

    container.read(requestDraftProvider.notifier).setMethod('DELETE');
    await tester.pump();

    expect(selectedColor(tester, 'DELETE'), MethodBadge.colorForMethod('DELETE'));
  });

  testWidgets('picking another method updates the draft', (tester) async {
    await pumpSelector(tester);

    await tester.tap(find.byKey(const Key('method-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PUT').last);
    await tester.pumpAndSettle();

    expect(container.read(requestDraftProvider).method, 'PUT');
  });

  testWidgets('lists all five methods', (tester) async {
    await pumpSelector(tester);

    await tester.tap(find.byKey(const Key('method-selector')));
    await tester.pumpAndSettle();

    for (final method in ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
      expect(find.text(method), findsWidgets);
    }
  });
}
