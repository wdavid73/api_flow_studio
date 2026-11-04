import 'package:flutter/material.dart';

import '../../engine/flows/response_fields.dart' show previewValue;
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The most items of a list the tree lists before cutting it with `…`.
const int _maxListItems = 20;

/// A step's whole response -- status, headers and body -- as an indented tree
/// whose every value can be tapped. [onValueTap] gets the value's full path
/// (`response.status`, `response.headers.content-type`, `response.body.user.id`)
/// and where it was tapped, to open a menu there. A body that is not JSON is
/// shown as plain text.
class ResponseTree extends StatelessWidget {
  const ResponseTree({
    super.key,
    required this.status,
    required this.headers,
    required this.body,
    this.onValueTap,
  });

  final int? status;
  final Map<String, String> headers;
  final Object? body;
  final void Function(String path, Offset globalPosition)? onValueTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (status != null) _leaf('status', '$status', 'response.status', 0),
      if (headers.isNotEmpty) ...[
        _label('headers', 0),
        for (final entry in headers.entries) _leaf(entry.key, previewValue(entry.value), 'response.headers.${entry.key}', 1),
      ],
    ];
    final value = body;
    if (value is Map || value is List) {
      rows
        ..add(_label('body', 0))
        ..addAll(_children(value, 'response.body', 1));
    } else if (value is String && value.isNotEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: SelectableText(value, style: AppTypography.codeSm),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  List<Widget> _children(Object? value, String path, int depth) {
    final rows = <Widget>[];
    void add(String key, Object? child, String childPath) {
      if (child is Map && child.isNotEmpty || child is List && child.isNotEmpty) {
        rows
          ..add(_label(child is List ? '$key [${child.length}]' : key, depth))
          ..addAll(_children(child, childPath, depth + 1));
      } else {
        rows.add(_leaf(key, child is List ? '[0]' : previewValue(child), childPath, depth));
      }
    }

    if (value is Map) {
      for (final entry in value.entries) {
        add('${entry.key}', entry.value, '$path.${entry.key}');
      }
    } else if (value is List) {
      for (var i = 0; i < value.length && i < _maxListItems; i++) {
        add('$i', value[i], '$path.$i');
      }
      if (value.length > _maxListItems) rows.add(_label('…', depth));
    }
    return rows;
  }

  Widget _label(String text, int depth) => Padding(
        padding: EdgeInsets.only(left: depth * AppSpacing.md, top: AppSpacing.xs, bottom: 2),
        child: Text(text, style: AppTypography.codeSm.copyWith(color: AppColors.onSurfaceVariant)),
      );

  Widget _leaf(String key, String preview, String path, int depth) {
    final tap = onValueTap;
    return InkWell(
      key: ValueKey('response-tree-value-$path'),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: tap == null ? null : () {},
      onTapUp: tap == null ? null : (details) => tap(path, details.globalPosition),
      child: Padding(
        padding: EdgeInsets.only(left: depth * AppSpacing.md, top: 2, bottom: 2),
        child: Row(
          children: [
            Text(key, style: AppTypography.codeSm.copyWith(color: AppColors.jsonKey)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                preview,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.codeSm.copyWith(color: AppColors.jsonString),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
