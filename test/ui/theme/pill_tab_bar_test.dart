import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:api_flow_studio/ui/theme/widgets/pill_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const DefaultTabController(
            length: 2,
            child: Scaffold(body: PillTabBar(labels: ['Params', 'Body'])),
          ),
        ),
      );

  testWidgets('renders one Tab per label', (tester) async {
    await pumpBar(tester);

    expect(find.widgetWithText(Tab, 'Params'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Body'), findsOneWidget);
  });

  testWidgets('the selected tab is a surfaceContainerHigh pill with no underline', (tester) async {
    await pumpBar(tester);

    final bar = tester.widget<TabBar>(find.byType(TabBar));
    final indicator = bar.indicator! as BoxDecoration;

    expect(indicator.color, AppColors.surfaceContainerHigh);
    expect(indicator.borderRadius, BorderRadius.circular(8));
    expect(bar.dividerColor, Colors.transparent);
    expect(bar.indicatorSize, TabBarIndicatorSize.tab);
  });

  testWidgets('selected and unselected labels use the on-surface colors', (tester) async {
    await pumpBar(tester);

    final bar = tester.widget<TabBar>(find.byType(TabBar));

    expect(bar.labelColor, AppColors.onSurface);
    expect(bar.unselectedLabelColor, AppColors.onSurfaceVariant);
  });
}
