import 'dart:convert';
import 'dart:io';

import 'package:api_flow_studio/app.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/l10n/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> readArb(String name) =>
    jsonDecode(File('lib/l10n/$name.arb').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('the .arb files', () {
    final en = readArb('app_en');
    final es = readArb('app_es');
    Iterable<String> keysOf(Map<String, dynamic> arb) => arb.keys.where((k) => !k.startsWith('@'));

    test('Spanish has exactly the keys English has', () {
      expect(keysOf(es).toSet(), keysOf(en).toSet());
    });

    test('no text is empty and each one uses the same {placeholders} in both languages', () {
      final placeholder = RegExp(r'\{(\w+)[,}]');
      for (final key in keysOf(en)) {
        expect((en[key] as String).trim(), isNotEmpty, reason: 'en $key');
        expect((es[key] as String).trim(), isNotEmpty, reason: 'es $key');
        Set<String> names(String text) => {for (final m in placeholder.allMatches(text)) m.group(1)!};
        expect(names(es[key] as String), names(en[key] as String), reason: key);
      }
    });
  });

  testWidgets('the language button switches the app to Spanish and remembers it', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = JsonStore.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          appSettingsStoreProvider.overrideWithValue(store),
          initialLocaleProvider.overrideWithValue(const Locale('en')),
        ],
        child: const ApiFlowStudioApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hosts & notes'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-option-es')));
    await tester.pumpAndSettle();

    expect(find.text('Hosts y notas'), findsOneWidget);
    expect(find.text('Espacio de trabajo'), findsOneWidget);
    expect(find.text('Hosts & notes'), findsNothing);
    expect(await store.readAppLocale(), 'es');

    await tester.tap(find.byKey(const Key('language-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-option-system')));
    await tester.pumpAndSettle();
    expect(await store.readAppLocale(), isNull);
  });

  test('a saved language that the app no longer has is ignored', () {
    expect(localeFromCode('es'), const Locale('es'));
    expect(localeFromCode('xx'), isNull);
    expect(localeFromCode(null), isNull);
  });
}
