import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/models/models.dart';
import '../request_draft_provider.dart';
import '../../../l10n/l10n.dart';

enum AuthKind { none, basic, bearer }

class AuthTab extends ConsumerWidget {
  const AuthTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(requestDraftProvider);
    final notifier = ref.read(requestDraftProvider.notifier);
    final kind = draft.authConfig.map(
      none: (_) => AuthKind.none,
      basic: (_) => AuthKind.basic,
      bearer: (_) => AuthKind.bearer,
    );

    void setKind(AuthKind newKind) {
      switch (newKind) {
        case AuthKind.none:
          notifier.setAuthConfig(const AuthConfig.none());
        case AuthKind.basic:
          notifier.setAuthConfig(const AuthConfig.basic(username: '', password: ''));
        case AuthKind.bearer:
          notifier.setAuthConfig(const AuthConfig.bearer(token: ''));
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<AuthKind>(
            key: const Key('auth-kind-selector'),
            segments: [
              ButtonSegment(value: AuthKind.none, label: Text(context.l10n.commonNone)),
              ButtonSegment(value: AuthKind.basic, label: Text(context.l10n.authBasic)),
              ButtonSegment(value: AuthKind.bearer, label: Text(context.l10n.authBearer)),
            ],
            selected: {kind},
            onSelectionChanged: (selection) => setKind(selection.first),
          ),
          const SizedBox(height: 16),
          draft.authConfig.map(
            none: (_) => const SizedBox.shrink(),
            basic: (b) => Column(
              children: [
                TextFormField(
                  key: const Key('auth-username-field'),
                  initialValue: b.username,
                  decoration: InputDecoration(labelText: context.l10n.authUsername),
                  onChanged: (v) => notifier.setAuthConfig(b.copyWith(username: v)),
                ),
                TextFormField(
                  key: const Key('auth-password-field'),
                  initialValue: b.password,
                  decoration: InputDecoration(labelText: context.l10n.authPassword),
                  onChanged: (v) => notifier.setAuthConfig(b.copyWith(password: v)),
                ),
              ],
            ),
            bearer: (b) => TextFormField(
              key: const Key('auth-token-field'),
              initialValue: b.token,
              decoration: InputDecoration(labelText: context.l10n.authToken),
              onChanged: (v) => notifier.setAuthConfig(b.copyWith(token: v)),
            ),
          ),
        ],
      ),
    );
  }
}
