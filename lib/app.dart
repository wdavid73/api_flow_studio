import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/theme/app_theme.dart';

enum AppDestination {
  workspace('Workspace'),
  environments('Environments'),
  flows('Flows'),
  history('History');

  const AppDestination(this.label);

  final String label;
}

final selectedDestinationProvider = StateProvider<AppDestination>(
  (ref) => AppDestination.workspace,
);

class ApiFlowStudioApp extends StatelessWidget {
  const ApiFlowStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API Flow Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDestinationProvider);

    return Scaffold(
      body: Column(
        children: [
          _NavBar(selected: selected),
          Expanded(child: _DestinationBody(destination: selected)),
        ],
      ),
    );
  }
}

class _NavBar extends ConsumerWidget {
  const _NavBar({required this.selected});

  final AppDestination selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Text('API Flow Studio', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 32),
            for (final destination in AppDestination.values)
              _NavItem(
                destination: destination,
                isSelected: destination == selected,
                onTap: () => ref.read(selectedDestinationProvider.notifier).state = destination,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          destination.label,
          style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }
}

class _DestinationBody extends StatelessWidget {
  const _DestinationBody({required this.destination});

  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('${destination.label} placeholder'));
  }
}
