import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/failure_screenshot.dart';

bool isPng(List<int> bytes) =>
    bytes.length > 8 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4E &&
    bytes[3] == 0x47 &&
    bytes[4] == 0x0D &&
    bytes[5] == 0x0A &&
    bytes[6] == 0x1A &&
    bytes[7] == 0x0A;

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('failure_screenshot_test_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<void> pumpSomething(WidgetTester tester) => tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Center(child: Text('something to photograph')))),
      );

  group('safeFileName', () {
    test('keeps letters, digits, dashes and underscores', () {
      expect(safeFileName('Session_journey-1'), 'Session_journey-1');
    });

    test('replaces characters Windows does not allow in a file name', () {
      expect(safeFileName(r'a<b>c:d"e/f\g|h?i*j'), 'a_b_c_d_e_f_g_h_i_j');
    });

    test('turns spaces and runs of separators into single underscores', () {
      expect(safeFileName('a login captures tokens: and more'), 'a_login_captures_tokens_and_more');
    });

    test('never returns an empty name', () {
      expect(safeFileName(''), 'unnamed_test');
      expect(safeFileName('???'), 'unnamed_test');
    });

    test('caps very long names so the path stays valid', () {
      expect(safeFileName('x' * 500).length, lessThanOrEqualTo(120));
    });
  });

  testWidgets('saveFailureScreenshot writes a valid, non-empty PNG named after the test', (tester) async {
    await pumpSomething(tester);

    final file = await saveFailureScreenshot(tester, 'Group: does a thing?', directory: dir);

    expect(file, isNotNull);
    expect(file!.path, endsWith('Group_does_a_thing.png'));
    final bytes = file.readAsBytesSync();
    expect(isPng(bytes), isTrue);
    expect(bytes.length, greaterThan(100));
  });

  testWidgets('runWithFailureCapture rethrows a failure and leaves a screenshot', (tester) async {
    await pumpSomething(tester);

    await expectLater(
      runWithFailureCapture(tester, 'failing journey', directory: dir, () async {
        expect(1 + 1, 3, reason: 'deliberate failure');
      }),
      throwsA(isA<TestFailure>()),
    );

    expect(File('${dir.path}/failing_journey.png').existsSync(), isTrue);
  });

  testWidgets('runWithFailureCapture also captures a thrown error, not only expect failures', (tester) async {
    await pumpSomething(tester);

    await expectLater(
      runWithFailureCapture(tester, 'throws', directory: dir, () async => throw StateError('boom')),
      throwsStateError,
    );

    expect(File('${dir.path}/throws.png').existsSync(), isTrue);
  });

  testWidgets('runWithFailureCapture leaves nothing behind when the body passes', (tester) async {
    await pumpSomething(tester);

    await runWithFailureCapture(tester, 'passing journey', directory: dir, () async {
      expect(1 + 1, 2);
    });

    expect(dir.listSync(), isEmpty);
  });

  testWidgets('a failure to capture never hides the original failure', (tester) async {
    // Nothing is mounted that can be photographed and the directory cannot be
    // created: the test's own error must still be the one reported.
    await expectLater(
      runWithFailureCapture(
        tester,
        'no screenshot possible',
        directory: Directory('${dir.path}/\u0000invalid'),
        () async => throw StateError('the real problem'),
      ),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'the real problem')),
    );
  });
}
