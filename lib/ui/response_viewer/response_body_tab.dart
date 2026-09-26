import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/widgets/json_view.dart';

enum BodyViewMode { format, raw, preview }

/// Format = syntax-highlighted, pretty-printed, line-numbered ([JsonView]).
/// Raw = the exact response text, unformatted, uncolored.
/// Preview = pretty-printed for readability but without syntax color --
/// a lighter middle ground, not a full HTML/image renderer (out of scope).
class ResponseBodyTab extends StatefulWidget {
  const ResponseBodyTab({super.key, required this.body});

  final dynamic body;

  @override
  State<ResponseBodyTab> createState() => _ResponseBodyTabState();
}

class _ResponseBodyTabState extends State<ResponseBodyTab> {
  BodyViewMode _mode = BodyViewMode.format;

  String get _raw => rawResponseBody(widget.body);

  String get _pretty => prettyResponseBody(widget.body);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SegmentedButton<BodyViewMode>(
            key: const Key('body-view-mode-selector'),
            segments: const [
              ButtonSegment(value: BodyViewMode.format, label: Text('Format')),
              ButtonSegment(value: BodyViewMode.raw, label: Text('Raw')),
              ButtonSegment(value: BodyViewMode.preview, label: Text('Preview')),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) => setState(() => _mode = selection.first),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('response-body'),
            child: switch (_mode) {
              BodyViewMode.format => JsonView(text: _pretty),
              BodyViewMode.raw => SelectableText(
                  _raw,
                  style: AppTypography.codeMd.copyWith(color: AppColors.onSurface),
                ),
              BodyViewMode.preview => SelectableText(
                  _pretty,
                  style: AppTypography.codeMd.copyWith(color: AppColors.onSurface),
                ),
            },
          ),
        ),
      ],
    );
  }
}

/// The exact response text: as-is for a string body, compact JSON encoding
/// for a decoded Map/List, `toString()` as a last resort.
String rawResponseBody(dynamic body) {
  if (body == null) return '';
  if (body is String) return body;
  try {
    return jsonEncode(body);
  } catch (_) {
    return body.toString();
  }
}

/// Pretty-printed (2-space indent) JSON, whether [body] already decoded to
/// a Map/List or arrived as a JSON string. Falls back to the raw text for
/// a non-JSON body rather than throwing.
String prettyResponseBody(dynamic body) {
  const encoder = JsonEncoder.withIndent('  ');
  if (body == null) return '';
  if (body is String) {
    try {
      return encoder.convert(jsonDecode(body));
    } catch (_) {
      return body;
    }
  }
  try {
    return encoder.convert(body);
  } catch (_) {
    return body.toString();
  }
}
