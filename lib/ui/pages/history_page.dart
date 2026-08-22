import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/app_controller.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(appControllerProvider).history;
    if (rows.isEmpty) {
      return const Center(child: Text('History is empty.'));
    }
    final format = DateFormat.yMMMd().add_Hm();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return ListTile(
          leading: Icon(
            row.direction == 'inbound' ? Icons.call_received : Icons.call_made,
          ),
          title: Text(row.fileName),
          subtitle: Text(
            '${row.peerName} · ${row.status} · ${format.format(row.createdAt.toLocal())}',
          ),
        );
      },
    );
  }
}
