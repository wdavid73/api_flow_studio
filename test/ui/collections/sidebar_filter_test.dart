import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/collections_provider.dart';
import 'package:api_flow_studio/ui/collections/endpoint_filter.dart';
import 'package:api_flow_studio/ui/collections/method_filter_chips.dart';
import 'package:api_flow_studio/ui/collections/sidebar_tree.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _auth = Group(id: 'g-auth', name: 'Auth');
const _billing = Group(id: 'g-bill', name: 'Billing');
const _inner = Group(id: 'g-inner', name: 'Inner', parentGroupId: 'g-bill');

const _list = Endpoint(
  id: 'e-list',
  groupId: 'g-auth',
  name: 'List users',
  method: 'GET',
  url: 'https://x.test/users',
  description: 'Returns every account.',
);
const _create = Endpoint(id: 'e-create', groupId: 'g-auth', name: 'Create user', method: 'POST', url: 'https://x.test/users');
const _remove = Endpoint(id: 'e-remove', groupId: 'g-auth', name: 'Remove user', method: 'DELETE', url: 'https://x.test/users/1');
const _invoice = Endpoint(id: 'e-invoice', groupId: 'g-inner', name: 'Get invoice', method: 'GET', url: 'https://x.test/invoices');

List<String> endpointNames(List<GroupTreeNode> nodes) => [
      for (final n in nodes) ...[...n.endpoints.map((e) => e.name), ...endpointNames(n.children)],
    ];

void main() {
  final tree = buildGroupTree(
    [_auth, _billing, _inner],
    [_list, _create, _remove, _invoice],
  );

  group('filterTree', () {
    test('with no filters everything is kept', () {
      expect(endpointNames(filterTree(tree, query: '', method: 'ALL')), hasLength(4));
    });

    test('with no filters an empty folder is still shown', () {
      final withEmpty = buildGroupTree(
        [_auth, const Group(id: 'g-empty', name: 'Empty Folder')],
        [_list],
      );

      expect(filterTree(withEmpty, query: '', method: 'ALL').map((n) => n.group.name), ['Auth', 'Empty Folder']);
      expect(filterTree(withEmpty, query: 'users', method: 'ALL').map((n) => n.group.name), ['Auth']);
    });

    test('a method filter keeps only that method', () {
      expect(endpointNames(filterTree(tree, query: '', method: 'POST')), ['Create user']);
    });

    test('the text filter matches name, method, url and description, case-insensitively', () {
      expect(endpointNames(filterTree(tree, query: 'REMOVE', method: 'ALL')), ['Remove user']);
      expect(endpointNames(filterTree(tree, query: 'delete', method: 'ALL')), ['Remove user']);
      expect(endpointNames(filterTree(tree, query: 'invoices', method: 'ALL')), ['Get invoice']);
      expect(endpointNames(filterTree(tree, query: 'every account', method: 'ALL')), ['List users']);
    });

    test('method and text combine', () {
      expect(endpointNames(filterTree(tree, query: 'user', method: 'GET')), ['List users']);
      expect(endpointNames(filterTree(tree, query: 'invoice', method: 'POST')), isEmpty);
    });

    test('a folder with no passing descendant disappears; a nested match keeps its parents', () {
      final result = filterTree(tree, query: '', method: 'GET');

      expect(result.map((n) => n.group.name), ['Auth', 'Billing']);
      expect(result.last.children.single.group.name, 'Inner');
      expect(filterTree(tree, query: 'zzz', method: 'ALL'), isEmpty);
    });
  });

  group('SidebarTree filters', () {
    late ProviderContainer container;

    Future<void> pumpSidebar(WidgetTester tester) async {
      final store = JsonStore.inMemory();
      await store.writeCollections(
        groups: const [_auth, _billing, _inner],
        endpoints: const [_list, _create, _remove, _invoice],
      );
      container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
      addTearDown(container.dispose);
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

    Finder row(String id) => find.byKey(ValueKey('endpoint-row-$id'));

    testWidgets('shows the six chips with All selected by default', (tester) async {
      await pumpSidebar(tester);

      for (final m in ['ALL', 'GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
        expect(find.byKey(Key('method-filter-$m')), findsOneWidget);
      }
      expect(container.read(sidebarMethodFilterProvider), 'ALL');
      final selected = tester.widget<Container>(find.byKey(const Key('method-filter-ALL')));
      expect((selected.decoration! as BoxDecoration).color, AppColors.onSurface);
    });

    testWidgets('choosing POST shows only POST endpoints, even in collapsed folders', (tester) async {
      await pumpSidebar(tester);

      await tester.tap(find.byKey(const Key('method-filter-POST')));
      await tester.pump();

      expect(row('e-create'), findsOneWidget);
      expect(row('e-list'), findsNothing);
      expect(row('e-remove'), findsNothing);
      expect(find.text('Billing'), findsNothing);
    });

    testWidgets('only one chip is active at a time and All restores everything', (tester) async {
      await pumpSidebar(tester);

      await tester.tap(find.byKey(const Key('method-filter-POST')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('method-filter-GET')));
      await tester.pump();

      expect(container.read(sidebarMethodFilterProvider), 'GET');
      expect(row('e-create'), findsNothing);
      expect(row('e-list'), findsOneWidget);
      expect(row('e-invoice'), findsOneWidget);

      await tester.tap(find.byKey(const Key('method-filter-ALL')));
      await tester.pump();
      // Back to no filters: folders collapse again, so only the folders show.
      expect(find.text('Auth'), findsOneWidget);
      expect(row('e-list'), findsNothing);
    });

    testWidgets('the method chip and the search text combine', (tester) async {
      await pumpSidebar(tester);

      await tester.tap(find.byKey(const Key('method-filter-GET')));
      await tester.enterText(find.byKey(const Key('sidebar-search-field')), 'invoice');
      await tester.pump();

      expect(row('e-invoice'), findsOneWidget);
      expect(row('e-list'), findsNothing);
    });
  });
}
