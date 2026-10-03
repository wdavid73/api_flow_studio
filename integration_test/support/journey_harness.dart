import 'package:api_flow_studio/app.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_executor_provider.dart';
import 'package:api_flow_studio/ui/session/session_button.dart';
import 'package:api_flow_studio/ui/shell/app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'failure_screenshot.dart';
import 'fake_backend.dart';
import 'seed_data.dart';

/// A journey test: `testWidgets` that, when it fails, also saves a screenshot of
/// the app to `build/integration_failures/<description>.png` before the failure
/// is reported. Use it instead of `testWidgets` in every journey.
void journeyTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) => runWithFailureCapture(tester, description, () => body(tester)));
}

/// What differs between the two ways of running a journey: where the data
/// lives (memory or a real temporary folder) and, through [launchApp], how the
/// app is mounted. Journeys only talk to this and to the [AppDriver].
abstract class JourneyHarness {
  /// A new, empty store that nothing else shares. Disk-backed harnesses create
  /// a fresh temporary folder and delete it when the test ends.
  Future<JsonStore> newStore();

  /// The logical window every journey runs in.
  Size get windowSize => const Size(1440, 900);

  /// Mounts the whole app and waits for it to settle.
  ///
  /// With no [store] a new one is created and filled with the standard demo
  /// data (see `seedStore`); pass `seed: false` for an empty one, or your own
  /// [store] to reuse data. [backend] is the fake server (a plain one by
  /// default) and [now] the clock the session expiry is read against.
  Future<AppDriver> launchApp(
    WidgetTester tester, {
    JsonStore? store,
    FakeBackend? backend,
    bool seed = true,
    DateTime? now,
  }) async {
    tester.view.physicalSize = windowSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final theStore = store ?? await newStore();
    if (store == null && seed) await seedStore(theStore);

    final driver = AppDriver(
      tester,
      store: theStore,
      backend: backend ?? FakeBackend(),
      clock: now ?? DateTime.utc(2026, 10, 2, 12),
    );
    await driver.mount();
    return driver;
  }
}

/// The user's hands: small helpers over the running app, so a journey reads as
/// what a person does. Widgets are found by their existing `Key`s.
class AppDriver {
  AppDriver(this.tester, {required this.store, required this.backend, required this.clock});

  final WidgetTester tester;

  /// The store the app was mounted on; also what a restart reuses.
  final JsonStore store;

  /// The fake server every request goes to.
  final FakeBackend backend;

  /// The time the session expiry is computed against. Move it to age a token.
  DateTime clock;

  /// Mounts the app on [store] and [backend].
  Future<void> mount() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          requestExecutorProvider.overrideWithValue(backend),
          sessionClockProvider.overrideWithValue(() => clock),
        ],
        child: const ApiFlowStudioApp(),
      ),
    );
    await settle();
  }

  /// Closes the app and opens it again on the same store: everything kept in
  /// memory (the session among it) is gone, everything stored stays.
  Future<void> restart() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await mount();
  }

  /// Lets frames and pending async work (store reads, responses) finish.
  Future<void> settle() async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
    }
  }

  /// Taps the widget with [key] and settles.
  Future<void> tapKey(Key key) async {
    await tester.tap(find.byKey(key));
    await settle();
  }

  /// Opens a header destination by its label (`Flows`, `History`, ...).
  Future<void> goTo(String label) async {
    await tester.tap(find.descendant(of: find.byType(AppHeader), matching: find.text(label)));
    await settle();
  }

  /// Expands the sidebar folder [groupId] if it is collapsed.
  Future<void> expandFolder(String groupId) async {
    final toggle = find.byKey(ValueKey('toggle-group-$groupId'));
    expect(toggle, findsOneWidget, reason: 'folder $groupId');
    await tester.tap(toggle);
    await settle();
  }
}
