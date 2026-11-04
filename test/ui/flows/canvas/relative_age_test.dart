import 'package:api_flow_studio/ui/flows/canvas/relative_age.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('relativeAge says how long ago, in the largest whole unit', (tester) async {
    final now = DateTime(2026, 11, 4, 12);
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      context = c;
      return const SizedBox();
    })));

    expect(relativeAge(context, now.subtract(const Duration(seconds: 30)), now: now), 'just now');
    expect(relativeAge(context, now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
    expect(relativeAge(context, now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
    expect(relativeAge(context, now.subtract(const Duration(days: 1)), now: now), '1 day ago');
    expect(relativeAge(context, now.subtract(const Duration(days: 3)), now: now), '3 days ago');
  });
}
