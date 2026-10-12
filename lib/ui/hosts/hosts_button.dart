import 'package:flutter/material.dart';

import '../shell/header_ghost_button.dart';
import 'hosts_dialog.dart';
import '../../l10n/l10n.dart';

/// Header button that opens the hosts-by-environment dialog.
class HostsButton extends StatelessWidget {
  const HostsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderGhostButton(
      key: const Key('hosts-button'),
      label: context.l10n.hostsButton,
      onPressed: () => showDialog<void>(context: context, builder: (_) => const HostsDialog()),
    );
  }
}
