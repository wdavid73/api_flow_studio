import 'package:flutter/material.dart';

import '../shell/header_ghost_button.dart';
import 'hosts_dialog.dart';

/// Header button that opens the hosts-by-environment dialog.
class HostsButton extends StatelessWidget {
  const HostsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderGhostButton(
      key: const Key('hosts-button'),
      label: 'Hosts & notes',
      onPressed: () => showDialog<void>(context: context, builder: (_) => const HostsDialog()),
    );
  }
}
