import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/collections/sidebar_tree.dart';
import 'ui/environments/environment_manager_screen.dart';
import 'ui/flows/flows_screen.dart';
import 'ui/request_builder/request_bar.dart';
import 'ui/shell/app_background.dart';
import 'ui/shell/app_banner.dart';
import 'ui/shell/app_destination.dart';
import 'ui/shell/app_header.dart';
import 'ui/shell/app_toast.dart';
import 'ui/shell/production_strip.dart';
import 'ui/theme/app_theme.dart';

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

    return AppBackground(
      child: ToastHost(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              const ProductionStrip(),
              const AppHeader(),
              const BannerHost(),
              Expanded(child: _DestinationBody(destination: selected)),
            ],
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
