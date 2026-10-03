import 'package:api_flow_studio/ui/shell/app_banner.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:api_flow_studio/ui/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpHost(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: Column(children: [BannerHost()])),
        ),
      ),
    );
  }

  Container box(WidgetTester tester) => tester.widget<Container>(find.byKey(const Key('app-banner')));

  testWidgets('takes no space when there is no banner', (tester) async {
    await pumpHost(tester);

    expect(tester.getSize(find.byType(BannerHost)).height, 0);
    expect(find.byKey(const Key('app-banner')), findsNothing);
  });

  testWidgets('a warning banner uses the banner background and warning text', (tester) async {
    await pumpHost(tester);

    container.read(bannerProvider.notifier).state =
        const AppBanner(message: 'URL mal armada', kind: BannerKind.warning);
    await tester.pump();

    expect((box(tester).decoration! as BoxDecoration).color, AppColors.bannerBackground);
    expect(DefaultTextStyle.of(tester.element(find.byKey(const Key('app-banner-text')))).style.color, AppColors.warning);
    expect(find.textContaining('URL mal armada', findRichText: true), findsOneWidget);
  });

  testWidgets('an info banner uses the info background and muted text', (tester) async {
    await pumpHost(tester);

    container.read(bannerProvider.notifier).state = const AppBanner(message: 'Nota', kind: BannerKind.info);
    await tester.pump();

    expect((box(tester).decoration! as BoxDecoration).color, AppColors.infoBackground);
    expect(
      DefaultTextStyle.of(tester.element(find.byKey(const Key('app-banner-text')))).style.color,
      AppColors.onSurfaceVariant,
    );
  });

  testWidgets('text between backticks is drawn in the code font', (tester) async {
    await pumpHost(tester);

    container.read(bannerProvider.notifier).state = const AppBanner(
      message: 'Corre `python3 server.py` y abre localhost',
      kind: BannerKind.warning,
    );
    await tester.pump();

    final rich = tester.widget<RichText>(find.descendant(
      of: find.byKey(const Key('app-banner-text')),
      matching: find.byType(RichText),
    ));
    final spans = <TextSpan>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    final code = spans.singleWhere((s) => s.text == 'python3 server.py');

    expect(code.style?.fontFamily, AppTypography.codeFontFamily);
    expect(rich.text.toPlainText(), isNot(contains('`')));
  });

  testWidgets('clearing the provider hides the banner again', (tester) async {
    await pumpHost(tester);

    container.read(bannerProvider.notifier).state = const AppBanner(message: 'Hola', kind: BannerKind.info);
    await tester.pump();
    expect(find.byKey(const Key('app-banner')), findsOneWidget);

    container.read(bannerProvider.notifier).state = null;
    await tester.pump();

    expect(find.byKey(const Key('app-banner')), findsNothing);
    expect(tester.getSize(find.byType(BannerHost)).height, 0);
  });
}
