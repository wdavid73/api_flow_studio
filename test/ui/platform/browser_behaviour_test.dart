import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/engine/storage/key_value_backend.dart';
import 'package:api_flow_studio/l10n/l10n.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/l10n/locale_provider.dart';
import 'package:api_flow_studio/ui/platform/platform_capabilities.dart';
import 'package:api_flow_studio/ui/request_builder/multipart_table.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:api_flow_studio/ui/response_viewer/browser_hint.dart';
import 'package:api_flow_studio/ui/response_viewer/response_cookies_tab.dart';
import 'package:api_flow_studio/ui/response_viewer/response_panel.dart';
import 'package:api_flow_studio/ui/shell/app_toast.dart';
import 'package:api_flow_studio/ui/shell/storage_full_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('browserNetworkHint', () {
    test('is nothing on the desktop', () {
      expect(browserNetworkHint(en, isBrowser: false, url: 'https://api.example.com'), isNull);
    });

    test('points at CORS for an https address', () {
      expect(browserNetworkHint(en, isBrowser: true, url: 'https://api.example.com/x'), en.browserHintCors);
      expect(browserNetworkHint(en, isBrowser: true), en.browserHintCors);
    });

    test('points at mixed content for plain http that is not the local machine', () {
      expect(browserNetworkHint(en, isBrowser: true, url: 'http://api.example.com/x'), en.browserHintMixedContent);
    });

    test('plain http to the local machine is allowed by the browser, so it is CORS if anything', () {
      for (final url in ['http://localhost:3000/x', 'http://127.0.0.1/x', 'http://[::1]:8080/x']) {
        expect(browserNetworkHint(en, isBrowser: true, url: url), en.browserHintCors, reason: url);
      }
    });
  });

  group('the response panel in a browser', () {
    Widget wrap(PlatformCapabilities capabilities, ExecutedResponse response) => ProviderScope(
          overrides: [
            jsonStoreProvider.overrideWithValue(JsonStore.inMemory()),
            platformCapabilitiesProvider.overrideWithValue(capabilities),
          ],
          child: MaterialApp(home: Scaffold(body: ResponsePanel(sendState: SendState(response: response)))),
        );

    const failed = ExecutedResponse(error: 'The connection errored', requestUrl: 'https://api.example.com/x');

    testWidgets('a failed request gets the CORS hint', (tester) async {
      await tester.pumpWidget(wrap(PlatformCapabilities.browser, failed));

      expect(find.byKey(const Key('response-browser-hint')), findsOneWidget);
      expect(find.text(en.browserHintCors), findsOneWidget);
    });

    testWidgets('on the desktop the same failure has no hint', (tester) async {
      await tester.pumpWidget(wrap(PlatformCapabilities.desktop, failed));

      expect(find.byKey(const Key('response-error')), findsOneWidget);
      expect(find.byKey(const Key('response-browser-hint')), findsNothing);
    });

    testWidgets('the Cookies tab says cookies are hidden instead of "No cookies"', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [platformCapabilitiesProvider.overrideWithValue(PlatformCapabilities.browser)],
        child: const MaterialApp(home: Scaffold(body: ResponseCookiesTab(headers: {}))),
      ));

      expect(find.byKey(const Key('cookies-hidden-in-browser')), findsOneWidget);
      expect(find.text(en.responseNoCookies), findsNothing);
    });

    testWidgets('on the desktop an empty Cookies tab still says "No cookies"', (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ResponseCookiesTab(headers: {}))),
      ));

      expect(find.text(en.responseNoCookies), findsOneWidget);
    });
  });

  group('Form Data in a browser', () {
    Future<void> pump(WidgetTester tester, PlatformCapabilities capabilities, List<MultipartField> fields) {
      return tester.pumpWidget(ProviderScope(
        overrides: [platformCapabilitiesProvider.overrideWithValue(capabilities)],
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: MultipartTable(fields: fields, onChanged: (_) {}))),
        ),
      ));
    }

    const file = MultipartField(name: 'doc', kind: MultipartFieldKind.file, value: r'C:\a.pdf');

    testWidgets('a file field says it cannot be sent and its Choose button is off', (tester) async {
      await pump(tester, PlatformCapabilities.browser, const [file]);

      expect(find.byKey(const ValueKey('multipart-browser-note-0')), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('multipart-choose-0'))).onPressed, isNull);
    });

    testWidgets('on the desktop there is no note and the button works', (tester) async {
      await pump(tester, PlatformCapabilities.desktop, const [file]);

      expect(find.byKey(const ValueKey('multipart-browser-note-0')), findsNothing);
      expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('multipart-choose-0'))).onPressed, isNotNull);
    });

    testWidgets('a text field is not affected', (tester) async {
      await pump(tester, PlatformCapabilities.browser, const [MultipartField(name: 'a', value: 'x')]);

      expect(find.byKey(const ValueKey('multipart-value-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('multipart-browser-note-0')), findsNothing);
    });
  });

  group('storageFullHandler', () {
    test('says the browser is full in a toast, in the chosen language, and handles the error', () {
      final container = ProviderContainer(overrides: [initialLocaleProvider.overrideWithValue(const Locale('es'))]);
      addTearDown(container.dispose);

      final handled = storageFullHandler(container)(const StorageFullException(), StackTrace.empty);

      expect(handled, isTrue);
      expect(container.read(toastProvider), lookupAppLocalizations(const Locale('es')).storageFull);
    });

    test('leaves every other error to the default handling', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(storageFullHandler(container)(StateError('x'), StackTrace.empty), isFalse);
      expect(container.read(toastProvider), isNull);
    });
  });
}
