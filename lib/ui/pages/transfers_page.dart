import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/transfer.dart';
import '../../state/app_controller.dart';

class TransfersPage extends ConsumerWidget {
  const TransfersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(appControllerProvider).transfers;
    if (transfers.isEmpty) {
      return const Center(child: Text('No transfers yet.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: transfers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _Tile(item: transfers[index]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});

  final TransferProgress item;

  @override
  Widget build(BuildContext context) {
    final inbound = item.direction == TransferDirection.inbound;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(inbound ? Icons.download : Icons.upload),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.fileName.isEmpty ? item.id : item.fileName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(item.status.name),
              ],
            ),
            const SizedBox(height: 4),
            Text('${item.peerName} · ${_size(item.fileSize)}'),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: item.ratio.clamp(0, 1)),
          ],
        ),
      ),
    );
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
