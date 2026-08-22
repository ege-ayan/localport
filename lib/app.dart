import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/app_controller.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

class LocalPortApp extends ConsumerWidget {
  const LocalPortApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(appControllerProvider.select((s) => s.ready));
    return MaterialApp(
      title: 'LocalPort',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: ready
          ? const AppShell()
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
