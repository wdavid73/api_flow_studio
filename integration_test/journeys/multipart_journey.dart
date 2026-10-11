import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/workspace/workspace_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/journey_harness.dart';

/// Journey 13: send a Form Data body with a text field and a file, and import a
/// workspace that tries to bring a file path along.
void defineMultipartJourney(JourneyHarness Function() harness) {
  group('Multipart journey', () {
    journeyTest('a request with a text field and a chosen file is sent as a form', (tester) async {
      final app = await harness().launchApp(tester);
      app.filePicker.pathToPick = '/home/ana/photo.png';

      await app.setUrl('{{base_url}}/upload');
      await tester.tap(find.widgetWithText(Tab, 'Body'));
      await app.settle();
      await tester.tap(find.text('Form Data'));
      await app.settle();

      await app.tapKey(const Key('add-multipart-field'));
      await tester.enterText(find.byKey(const Key('multipart-name-0')), 'title');
      await tester.enterText(find.byKey(const Key('multipart-value-0')), 'Hello');
      await app.settle();

      await app.tapKey(const Key('add-multipart-field'));
      await tester.enterText(find.byKey(const Key('multipart-name-1')), 'avatar');
      await app.tapKey(const Key('multipart-kind-1'));
      await tester.tap(find.text('File').last);
      await app.settle();
      expect(find.byKey(const Key('multipart-no-file-1')), findsOneWidget);

      await app.tapKey(const Key('multipart-choose-1'));
      expect(find.byKey(const Key('multipart-no-file-1')), findsNothing);
      await app.send();

      expect(app.backend.calls, hasLength(1));
      expect(app.backend.lastCall.url, 'https://dev.api.test/upload');
      expect(app.backend.lastCall.body, 'title=Hello&avatar=@photo.png');
    });

    journeyTest('a workspace that brings a file path along arrives with no path, and says what is left to fill in', (tester) async {
      final app = await harness().launchApp(tester);
      final shared = WorkspaceFile(
        name: 'shared',
        groups: const [Group(id: 'g', name: 'Uploads')],
        endpoints: const [
          Endpoint(
            id: 'e-up',
            groupId: 'g',
            name: 'Upload',
            method: 'POST',
            url: '{{base_url}}/upload',
            body: RequestBody.multipart([
              MultipartField(name: 'loot', kind: MultipartFieldKind.file, value: '/Users/victim/.ssh/id_rsa'),
            ]),
          ),
        ],
        exportedAt: DateTime.utc(2026, 10, 11),
      );

      await app.importWorkspaceFile(shared.encode());

      expect(find.text('Imported "shared" — 1 value to fill in'), findsOneWidget);
      final fields = (await app.activeStore().then((s) => s.readCollections())).endpoints.single.body
          .maybeMap(multipart: (b) => b.fields, orElse: () => throw StateError('not multipart'));
      expect(fields.single.kind, MultipartFieldKind.file);
      expect(fields.single.value, isEmpty);
    });
  });
}
