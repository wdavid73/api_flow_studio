import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where failure screenshots go when no other directory is given.
Directory get defaultFailureDirectory => Directory('build/integration_failures');

/// [testName] turned into something safe to use as a file name on Windows:
/// letters, digits, `-` and `_` only, separators collapsed, never empty, at most
/// 120 characters.
String safeFileName(String testName) {
  final cleaned = testName
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (cleaned.isEmpty) return 'unnamed_test';
  return cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned;
}

/// Renders what is on screen right now into `<directory>/<test name>.png` and
/// returns the file, or null if nothing could be captured. It draws the root
/// render layer, so it works the same in `flutter_test` and on a real desktop
/// window (under `flutter_test` text appears as blocks, because the test font
/// is not a real one; the layout is still what matters).
Future<File?> saveFailureScreenshot(WidgetTester tester, String testName, {Directory? directory}) async {
  final RenderView view;
  final OffsetLayer layer;
  try {
    view = tester.binding.renderViews.first;
    final candidate = view.debugLayer;
    if (candidate is! OffsetLayer) return null;
    layer = candidate;
  } catch (_) {
    return null;
  }

  // Everything that can throw happens inside one runAsync with its own
  // try/catch: an error escaping a runAsync closure would be reported as a
  // failure of the test itself and hide the real one.
  return tester.runAsync<File?>(() async {
    try {
      final image = await layer.toImage(view.paintBounds);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final bytes = data?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) return null;

      final dir = directory ?? defaultFailureDirectory;
      await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}${safeFileName(testName)}.png');
      await file.writeAsBytes(bytes);
      return file;
    } catch (_) {
      // A screenshot is a debugging aid: never let it replace the real failure.
      return null;
    }
  });
}

/// Runs [body]; if it fails (a failed `expect` or any thrown error) it saves a
/// screenshot named after [testName] and rethrows the original error.
Future<void> runWithFailureCapture(
  WidgetTester tester,
  String testName,
  Future<void> Function() body, {
  Directory? directory,
}) async {
  try {
    await body();
  } catch (_) {
    final file = await saveFailureScreenshot(tester, testName, directory: directory);
    if (file != null) {
      // ignore: avoid_print
      print('Failure screenshot: ${file.absolute.path}');
    }
    rethrow;
  }
}
