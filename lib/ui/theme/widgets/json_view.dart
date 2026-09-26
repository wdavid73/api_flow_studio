import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import 'json_syntax.dart';

/// Read-only, syntax-highlighted, line-numbered display of a JSON-ish
/// string (falls back to plain un-colorized text for non-JSON bodies --
/// [tokenizeJsonLike] just won't match much, which is fine).
class JsonView extends StatelessWidget {
  const JsonView({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final baseStyle = jsonBaseStyle();
    final lines = text.split('\n');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicWidth(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Text(
                      '${i + 1}',
                      style: baseStyle.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Text.rich(TextSpan(children: tokenizeJsonLike(line, baseStyle: baseStyle))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
