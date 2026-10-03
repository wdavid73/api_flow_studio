import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/method_filter_chips.dart';
import 'package:api_flow_studio/ui/collections/sidebar_tree.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:api_flow_studio/ui/theme/app_typography.dart';
import 'package:api_flow_studio/ui/theme/widgets/method_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _auth = Group(id: 'g-auth', name: 'Auth');
const _inner = Group(id: 'g-inner', name: 'Inner', parentGroupId: 'g-auth');

const _list = Endpoint(id: 'e-list', groupId: 'g-auth', name: 'List users', method: 'GET', url: 'https://x.test/users');
const _create = Endpoint(id: 'e-create', groupId: 'g-auth', name: 'Create user', method: 'POST', url: 'https://x.test/users');
const _nested = Endpoint(id: 'e-nested', groupId: 'g-inner', name: 'Nested one', method: 'GET', url: 'https://x.test/n');

void main() {
  late ProviderContainer container;

  Future<void> pumpSidebar(WidgetTester tester, {bool withGroups = true}) async {
    final store = JsonStore.inMemory();
    if (withGroups) {
      await store.writeCollections(groups: const [_auth, _inner], endpoints: const [_list, _create, _nested]);
    }
    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    container.read(expandedGroupIdsProvider.notifier).state = {'g-auth', 'g-inner'};
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: SizedBox(width: 300, child: SidebarTree())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('an endpoint row has the method in a 54px column then the name in mono 12px', (tester) async {
    await pumpSidebar(tester);

    final column = find.byKey(const Key('endpoint-method-e-list'));
    expect(tester.getSize(column).width, 54);
    expect(find.descendant(of: column, matching: find.byType(MethodBadge)), findsOneWidget);

    final name = tester.widget<Text>(find.byKey(const Key('endpoint-name-e-list')));
    expect(name.data, 'List users');
    expect(name.style?.fontFamily, AppTypography.codeFontFamily);
    expect(name.style?.fontSize, 12);
    expect(name.overflow, TextOverflow.ellipsis);
  });

  testWidgets('the loaded endpoint is highlighted and the others are not', (tester) async {
    await pumpSidebar(tester);

    Color? fill(String id) => tester.widget<Material>(find.byKey(Key('endpoint-surface-$id'))).color;

    expect(fill('e-list'), Colors.transparent);

    container.read(requestDraftProvider.notifier).loadEndpoint(_list);
    await tester.pump();

    expect(fill('e-list'), AppColors.surfaceContainerHigh);
    expect(fill('e-create'), Colors.transparent);
  });

  testWidgets('a top-level folder header shows how many endpoints it holds, nested folders do not', (tester) async {
    await pumpSidebar(tester);

    expect(tester.widget<Text>(find.byKey(const Key('group-count-g-auth'))).data, '3');
    expect(find.byKey(const Key('group-count-g-inner')), findsNothing);
  });

  testWidgets('the folder count follows the active filter', (tester) async {
    await pumpSidebar(tester);

    container.read(sidebarMethodFilterProvider.notifier).state = 'POST';
    await tester.pump();

    expect(tester.widget<Text>(find.byKey(const Key('group-count-g-auth'))).data, '1');
  });

  testWidgets('a search with no matches says so', (tester) async {
    await pumpSidebar(tester);

    await tester.enterText(find.byKey(const Key('sidebar-search-field')), 'zzzz');
    await tester.pump();

    expect(find.byKey(const Key('no-results-state')), findsOneWidget);
    expect(find.text('Nothing matches that search.'), findsOneWidget);
    expect(find.byKey(const Key('empty-workspace-state')), findsNothing);
  });

  testWidgets('no message appears when nothing is filtered, and the empty workspace keeps its own', (tester) async {
    await pumpSidebar(tester);
    expect(find.byKey(const Key('no-results-state')), findsNothing);

    await pumpSidebar(tester, withGroups: false);
    expect(find.byKey(const Key('empty-workspace-state')), findsOneWidget);
    expect(find.byKey(const Key('no-results-state')), findsNothing);
  });
}
