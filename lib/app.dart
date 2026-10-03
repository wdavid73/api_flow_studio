import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/collections/sidebar_tree.dart';
import 'ui/environments/environment_manager_screen.dart';
import 'ui/environments/environment_switcher.dart';
import 'ui/flows/flows_screen.dart';
import 'ui/request_builder/request_bar.dart';
import 'ui/shell/production_strip.dart';
import 'ui/theme/app_colors.dart';
import 'ui/theme/app_spacing.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/app_typography.dart';
import 'ui/theme/widgets/app_logo.dart';

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
          const ProductionStrip(),
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
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 1))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              const AppLogoMark(size: 28),
              const SizedBox(width: AppSpacing.sm),
              Text('API Flow Studio', style: AppTypography.headlineSm),
              const SizedBox(width: AppSpacing.xl),
              for (final destination in AppDestination.values)
                _NavItem(
                  destination: destination,
                  isSelected: destination == selected,
                  onTap: () => ref.read(selectedDestinationProvider.notifier).state = destination,
                ),
              const Spacer(),
              const EnvironmentSwitcher(),
            ],
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceContainerHigh : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            destination.label,
            style: AppTypography.labelMd.copyWith(
              color: isSelected ? AppColors.onSurface : AppColors.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
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
    switch (destination) {
      case AppDestination.workspace:
        return const Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 256, child: SidebarTree()),
            VerticalDivider(width: 1),
            Expanded(child: RequestBar()),
          ],
        );
      case AppDestination.environments:
        return const EnvironmentManagerScreen();
      case AppDestination.flows:
        return const FlowsScreen();
      case AppDestination.history:
        return Center(child: Text('${destination.label} placeholder'));
    }
  }
}
