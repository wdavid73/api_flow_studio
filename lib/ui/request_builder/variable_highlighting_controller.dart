import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/widgets/json_syntax.dart';

/// A [TextEditingController] that colors `{{var}}` tokens cyan (resolved)
/// or amber (unresolved) against [resolvedVariables] -- the active
/// environment's variables, kept in sync by [updateResolvedVariables].
class VariableHighlightingController extends TextEditingController {
  VariableHighlightingController({super.text});

  Map<String, String> resolvedVariables = const {};

  /// Updates the resolved-variable set and repaints if it actually
  /// changed. Comparing before notifying avoids an unnecessary rebuild on
  /// every provider tick when the active environment hasn't changed.
  void updateResolvedVariables(Map<String, String> variables) {
    if (mapEquals(resolvedVariables, variables)) return;
    resolvedVariables = variables;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    return TextSpan(
      children: tokenizeVariablesOnly(
        text,
        baseStyle: baseStyle,
        resolvedVariables: resolvedVariables,
      ),
      style: baseStyle,
    );
  }
}
