import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/session/jwt_claims.dart';
import '../../engine/session/session.dart';
import '../environments/environments_provider.dart';
import '../shell/header_ghost_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'session_label.dart';
import 'session_provider.dart';
import 'session_clock.dart';

/// The session popover, drawn over the app by [SessionButton] under the
/// header's right edge: a click outside or `Esc` closes it ([onClose]).
class SessionPopover extends ConsumerWidget {
  const SessionPopover({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environmentName = ref.watch(environmentsProvider).value?.active?.name ?? 'No environment';

    return Stack(
      children: [
        // Everything outside the panel: swallow the click and close.
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose),
        ),
        Positioned(
          top: 58,
          right: AppSpacing.lg + 2,
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                onClose();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                key: const Key('session-popover'),
                width: 420,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.dialog),
                  border: Border.all(color: AppColors.outlineVariant),
                  boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 18))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Session · $environmentName', style: AppTypography.headlineSm),
                    const SizedBox(height: AppSpacing.md),
                    const _SessionForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Token fields, switches and metadata for the active environment's session.
class _SessionForm extends ConsumerStatefulWidget {
  const _SessionForm();

  @override
  ConsumerState<_SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends ConsumerState<_SessionForm> {
  late final TextEditingController _access;
  late final TextEditingController _refresh;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(activeSessionProvider);
    _access = TextEditingController(text: session.accessToken);
    _refresh = TextEditingController(text: session.refreshToken);
  }

  @override
  void dispose() {
    _access.dispose();
    _refresh.dispose();
    super.dispose();
  }

  void _update(Session Function(Session current) change) {
    final key = ref.read(activeEnvironmentKeyProvider);
    final notifier = ref.read(sessionsProvider.notifier);
    notifier.update(key, change(notifier.sessionFor(key)));
  }

  /// `sub … · Expires in 12 min`, the not-a-JWT hint, or null without a token.
  String? _metadata(Session session, DateTime now) {
    if (!session.hasToken) return null;
    final claims = JwtClaims.tryParse(session.accessToken);
    if (claims == null) return "Doesn't look like a JWT. It is still sent as a Bearer.";

    final parts = [
      if (claims.subject != null) 'sub ${claims.subject}',
      if (claims.expiresAt != null) sessionLabel(session, now).top,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);

    // Keep the fields in step with changes made elsewhere (a captured login,
    // another environment becoming active, Clear tokens).
    ref.listen<Session>(activeSessionProvider, (previous, next) {
      if (_access.text != next.accessToken) _access.text = next.accessToken;
      if (_refresh.text != next.refreshToken) _refresh.text = next.refreshToken;
    });

    final meta = _metadata(session, ref.watch(sessionClockProvider)());

    Widget tokenField(String label, String fieldKey, TextEditingController controller, ValueChanged<String> onChanged) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              key: Key(fieldKey),
              controller: controller,
              obscureText: !_show,
              autocorrect: false,
              enableSuggestions: false,
              style: AppTypography.codeMd,
              decoration: const InputDecoration(isDense: true),
              onChanged: onChanged,
            ),
          ],
        ),
      );
    }

    Widget check(String label, String boxKey, bool value, ValueChanged<bool> onChanged) {
      return InkWell(
        onTap: () => onChanged(!value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(key: Key(boxKey), value: value, onChanged: (v) => onChanged(v ?? false)),
            Text(label, style: AppTypography.bodyMd),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tokenField('Access token', 'session-access-field', _access,
            (v) => _update((s) => s.copyWith(accessToken: v))),
        tokenField('Refresh token', 'session-refresh-field', _refresh,
            (v) => _update((s) => s.copyWith(refreshToken: v))),
        Wrap(
          children: [
            check('Show', 'session-show-checkbox', _show, (v) => setState(() => _show = v)),
            check('Send Authorization', 'session-attach-checkbox', session.attachAuth,
                (v) => _update((s) => s.copyWith(attachAuth: v))),
            check('Capture tokens from 2xx', 'session-capture-checkbox', session.captureTokens,
                (v) => _update((s) => s.copyWith(captureTokens: v))),
          ],
        ),
        if (meta != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              meta,
              key: const Key('session-meta'),
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        HeaderGhostButton(
          key: const Key('session-clear-button'),
          label: 'Clear tokens',
          onPressed: () => _update((s) => s.copyWith(accessToken: '', refreshToken: '')),
        ),
      ],
    );
  }
}
