import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum BannerKind { warning, info }

/// A one-line notice shown under the header. Text between backticks is
/// drawn in the code font.
class AppBanner {
  const AppBanner({required this.message, required this.kind});

  final String message;
  final BannerKind kind;
}

/// The banner currently shown, or null for none. Any screen sets it via
/// `ref.read(bannerProvider.notifier).state = ...`.
final bannerProvider = StateProvider<AppBanner?>((ref) => null);

/// Draws [bannerProvider] full width under the header; collapses to nothing
/// when there is no banner.
class BannerHost extends ConsumerWidget {
  const BannerHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banner = ref.watch(bannerProvider);
    if (banner == null) return const SizedBox.shrink();

    final isWarning = banner.kind == BannerKind.warning;
    final textStyle = AppTypography.bodyMd.copyWith(
      color: isWarning ? AppColors.warning : AppColors.onSurfaceVariant,
    );

    return Container(
      key: const Key('app-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin + 4, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: isWarning ? AppColors.bannerBackground : AppColors.infoBackground,
        border: const Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: DefaultTextStyle(
        key: const Key('app-banner-text'),
        style: textStyle,
        child: Text.rich(TextSpan(children: _spans(banner.message, textStyle))),
      ),
    );
  }

  /// Splits [message] on backticks: odd-numbered segments are code.
  List<TextSpan> _spans(String message, TextStyle base) {
    final parts = message.split('`');
    return [
      for (var i = 0; i < parts.length; i++)
        if (parts[i].isNotEmpty)
          TextSpan(
            text: parts[i],
            style: i.isOdd ? base.copyWith(fontFamily: AppTypography.codeFontFamily, fontSize: 12) : null,
          ),
    ];
  }
}
