import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_controller.dart';
import 'pages/clipboard_page.dart';
import 'pages/devices_page.dart';
import 'pages/history_page.dart';
import 'pages/transfers_page.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  var _index = 0;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.devices), label: 'Devices'),
    NavigationDestination(icon: Icon(Icons.swap_vert), label: 'Transfers'),
    NavigationDestination(icon: Icon(Icons.content_paste), label: 'Clipboard'),
    NavigationDestination(icon: Icon(Icons.history), label: 'History'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final state = ref.watch(appControllerProvider);
    final pages = const [
      DevicesPage(),
      TransfersPage(),
      ClipboardPage(),
      HistoryPage(),
    ];

    final body = IndexedStack(index: _index, children: pages);
    final title = _destinations[_index].label;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(
                      Icons.cell_tower,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    const Text('LocalPort'),
                  ],
                ),
              ),
              destinations: [
                for (final item in _destinations)
                  NavigationRailDestination(
                    icon: item.icon,
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  _TopBar(title: title, deviceName: state.identity.name),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('LocalPort · $title')),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: _destinations,
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.deviceName});

  final String title;
  final String deviceName;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        child: Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            Text(deviceName, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
