import 'package:api_flow_studio/ui/shared/list_detail_layout.dart';
import 'package:api_flow_studio/ui/shell/header_ghost_button.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLayout(WidgetTester tester, {VoidCallback? onAction}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ListDetailLayout(
            header: ListPanelHeader(
              title: 'THINGS',
              actionLabel: 'New thing',
              actionKey: const Key('new-thing'),
              onAction: onAction ?? () {},
            ),
            list: const Center(child: Text('the list')),
            detail: const Center(child: Text('the detail')),
          ),
        ),
      ),
    );
  }

  testWidgets('the list panel is 300px wide and the detail takes the rest', (tester) async {
    await pumpLayout(tester);

    expect(tester.getSize(find.byKey(const Key('list-detail-list-panel'))).width, 300);
    expect(tester.getSize(find.byKey(const Key('list-detail-detail-panel'))).width, 900);
    expect(find.text('the list'), findsOneWidget);
    expect(find.text('the detail'), findsOneWidget);
  });

  testWidgets('the list panel has an outlineVariant right border', (tester) async {
    await pumpLayout(tester);

    final panel = tester.widget<Container>(find.byKey(const Key('list-detail-list-panel')));
    final border = (panel.decoration! as BoxDecoration).border! as Border;

    expect(border.right.color, AppColors.outlineVariant);
  });

  testWidgets('the header shows the kicker title and a ghost action that fires its callback', (tester) async {
    var pressed = 0;
    await pumpLayout(tester, onAction: () => pressed++);

    expect(find.text('THINGS'), findsOneWidget);
    expect(find.byType(HeaderGhostButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('new-thing')));

    expect(pressed, 1);
  });
}
