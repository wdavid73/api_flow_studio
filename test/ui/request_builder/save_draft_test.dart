import 'package:api_flow_studio/engine/curl/curl_parser.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/collections_provider.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_bar.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpBar(WidgetTester tester, {List<Group> groups = const []}) async {
    final store = JsonStore.inMemory();
    await store.writeCollections(groups: groups, endpoints: const []);
    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    await container.read(collectionsProvider.future);
    // What pasting a curl does: an unsaved draft.
    container
        .read(requestDraftProvider.notifier)
        .loadEndpoint(parseCurl("curl 'https://api.test/users' -H 'X-A: 1'").copyWith(id: draftEndpointId));

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: RequestBar())),
      ),
    );
  }

  testWidgets('Save on a pasted curl asks for a folder and saves it there', (tester) async {
    await pumpBar(tester, groups: const [Group(id: 'g-1', name: 'Users')]);

    await tester.tap(find.byKey(const Key('save-request-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-save-draft-button')));
    await tester.pumpAndSettle();

    final saved = container.read(collectionsProvider).value!.endpoints.single;
    expect(saved.groupId, 'g-1');
    expect(saved.url, 'https://api.test/users');
    expect(saved.id, isNot(draftEndpointId));
    // The saved copy is now the draft, so the next Save updates it in place.
    expect(container.read(requestDraftProvider).id, saved.id);
  });

  testWidgets('with no folders yet, a new one is created from the dialog', (tester) async {
    await pumpBar(tester);

    await tester.tap(find.byKey(const Key('save-request-button')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('confirm-save-draft-button'))).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('save-draft-new-folder-field')), 'Imported');
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-save-draft-button')));
    await tester.pumpAndSettle();

    final state = container.read(collectionsProvider).value!;
    expect(state.groups.single.name, 'Imported');
    expect(state.endpoints.single.groupId, state.groups.single.id);
  });

  testWidgets('cancelling the dialog saves nothing', (tester) async {
    await pumpBar(tester, groups: const [Group(id: 'g-1', name: 'Users')]);

    await tester.tap(find.byKey(const Key('save-request-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(container.read(collectionsProvider).value!.endpoints, isEmpty);
    expect(container.read(requestDraftProvider).id, draftEndpointId);
  });
}
