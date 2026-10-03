import 'package:api_flow_studio/ui/shell/app_toast.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpHost(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    var tapped = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: ToastHost(
            child: Scaffold(
              body: Center(
                child: Consumer(
                  builder: (context, ref, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        key: const Key('show-a'),
                        onPressed: () => showToast(ref, 'Respuesta copiada'),
                        child: const Text('A'),
                      ),
                      TextButton(
                        key: const Key('show-b'),
                        onPressed: () => showToast(ref, 'curl copiado'),
                        child: const Text('B'),
                      ),
                      TextButton(
                        key: const Key('under-toast'),
                        onPressed: () => tapped++,
                        child: Text('tapped $tapped'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double opacity(WidgetTester tester) => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

  testWidgets('is hidden until a toast is shown', (tester) async {
    await pumpHost(tester);

    expect(opacity(tester), 0);
  });

  testWidgets('showToast displays the message in a lime pill', (tester) async {
    await pumpHost(tester);

    await tester.tap(find.byKey(const Key('show-a')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Respuesta copiada'), findsOneWidget);
    expect(opacity(tester), 1);

    final pill = tester.widget<Container>(find.byKey(const Key('toast-pill')));
    expect((pill.decoration! as BoxDecoration).color, AppColors.primary);

    await tester.pump(toastDuration);
  });

  testWidgets('hides itself after 2200ms', (tester) async {
    await pumpHost(tester);

    await tester.tap(find.byKey(const Key('show-a')));
    await tester.pump(const Duration(milliseconds: 2100));
    expect(opacity(tester), 1);

    await tester.pump(const Duration(milliseconds: 200));
    expect(opacity(tester), 0);
  });

  testWidgets('a new toast replaces the previous one and restarts the timer', (tester) async {
    await pumpHost(tester);

    await tester.tap(find.byKey(const Key('show-a')));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.byKey(const Key('show-b')));
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('curl copiado'), findsOneWidget);
    expect(find.text('Respuesta copiada'), findsNothing);
    expect(opacity(tester), 1);

    await tester.pump(const Duration(milliseconds: 800));
    expect(opacity(tester), 0);
  });

  testWidgets('never intercepts pointer events', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('show-a')));
    await tester.pump(const Duration(milliseconds: 200));

    final ignore = tester.widget<IgnorePointer>(find.byKey(const Key('toast-ignore-pointer')));

    expect(ignore.ignoring, isTrue);

    await tester.pump(toastDuration);
  });
}
