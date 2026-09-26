import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_typography.dart';

final RegExp _outerPattern = RegExp(
  r'(?<key>"(?:[^"\\]|\\.)*"(?=\s*:))'
  r'|(?<string>"(?:[^"\\]|\\.)*")'
  r'|(?<number>-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)'
  r'|(?<boolean>\btrue\b|\bfalse\b|\bnull\b)'
  r'|(?<punct>[{}\[\]:,])',
);

final RegExp _variablePattern = RegExp(r'\{\{\w+\}\}');

/// Colorizes JSON-ish text per DESIGN.md Architecture Decision #3's token
/// mapping: keys -> secondary, string values -> tertiary, `{{var}}` tokens
/// -> the variable-chip cyan (even nested inside a quoted string, which is
/// where they actually appear in a request body), numbers/booleans ->
/// primary, punctuation -> on-surface-variant. Not a real JSON parser -- a
/// best-effort regex tokenizer, which is fine for coloring a request/
/// response body a user is reading or editing, not for validating it.
List<InlineSpan> tokenizeJsonLike(String text, {required TextStyle baseStyle}) {
  final spans = <InlineSpan>[];
  var lastEnd = 0;

  void addPlain(String segment, Color color, {FontWeight? weight}) {
    if (segment.isEmpty) return;
    spans.add(TextSpan(text: segment, style: baseStyle.copyWith(color: color, fontWeight: weight)));
  }

  void addWithVariables(String segment, Color color, {FontWeight? weight}) {
    var pos = 0;
    for (final varMatch in _variablePattern.allMatches(segment)) {
      if (varMatch.start > pos) {
        addPlain(segment.substring(pos, varMatch.start), color, weight: weight);
      }
      spans.add(TextSpan(
        text: varMatch[0],
        style: baseStyle.copyWith(color: AppColors.variableResolvedText),
      ));
      pos = varMatch.end;
    }
    if (pos < segment.length) {
      addPlain(segment.substring(pos), color, weight: weight);
    }
  }

  for (final match in _outerPattern.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: baseStyle));
    }

    final matched = match[0]!;
    if (match.namedGroup('key') != null) {
      addWithVariables(matched, AppColors.secondary, weight: FontWeight.w500);
    } else if (match.namedGroup('string') != null) {
      addWithVariables(matched, AppColors.tertiary);
    } else if (match.namedGroup('number') != null || match.namedGroup('boolean') != null) {
      addPlain(matched, AppColors.primary, weight: FontWeight.w600);
    } else {
      addPlain(matched, AppColors.onSurfaceVariant);
    }
    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
  }

  return spans;
}

/// Default base style for tokenized JSON-ish text: the code-md token plus
/// the neutral on-surface color for anything not specifically colorized.
TextStyle jsonBaseStyle() => AppTypography.codeMd.copyWith(color: AppColors.onSurface);
