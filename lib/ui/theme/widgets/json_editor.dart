import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import 'json_syntax.dart';

/// A [TextEditingController] that paints its text through
/// [tokenizeJsonLike] instead of a flat color, so an editable JSON body
/// field is syntax-highlighted as you type.
class JsonEditingController extends TextEditingController {
  JsonEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return TextSpan(children: tokenizeJsonLike(text, baseStyle: style ?? jsonBaseStyle()));
  }
}

/// An editable, syntax-highlighted, line-numbered JSON body field, sharing
/// [JsonView]'s token colors so the request body editor and response body
/// viewer read as the same component.
class JsonEditorField extends StatefulWidget {
  const JsonEditorField({super.key, required this.text, required this.onChanged});

  final String text;
  final ValueChanged<String> onChanged;

  @override
  State<JsonEditorField> createState() => _JsonEditorFieldState();
}

class _JsonEditorFieldState extends State<JsonEditorField> {
  late final JsonEditingController _controller = JsonEditingController(text: widget.text);
  late int _lineCount = _controller.text.split('\n').length;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = jsonBaseStyle();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm, top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _lineCount; i++)
                Text('${i + 1}', style: baseStyle.copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
        Expanded(
          child: TextField(
            key: const Key('json-body-field'),
            controller: _controller,
            style: baseStyle,
            maxLines: null,
            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
            onChanged: (value) {
              setState(() => _lineCount = value.split('\n').length);
              widget.onChanged(value);
            },
          ),
        ),
      ],
    );
  }
}
