import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class ResponseHeadersTab extends StatelessWidget {
  const ResponseHeadersTab({super.key, required this.headers});

  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty) {
      return const Center(child: Text('No headers'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: headers.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final entry = headers.entries.elementAt(index);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 220,
              child: Text(entry.key, style: AppTypography.codeSm),
            ),
            Expanded(child: Text(entry.value, style: AppTypography.codeSm)),
          ],
        );
      },
    );
  }
}
