import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/peer.dart';
import '../../state/app_controller.dart';

class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nearby devices',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'You are ${state.identity.name}. Discovery uses mDNS on the LAN.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.peers.isEmpty
                ? const _Empty()
                : ListView.separated(
                    itemCount: state.peers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _PeerTile(peer: state.peers[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PeerTile extends ConsumerWidget {
  const _PeerTile({required this.peer});

  final Peer peer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropTarget(
      onDragDone: (details) async {
        for (final file in details.files) {
          if (file.path.isEmpty) continue;
          await ref
              .read(appControllerProvider.notifier)
              .sendFile(peer, file.path);
        }
      },
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(peer.name.isEmpty ? '?' : peer.name[0].toUpperCase()),
          ),
          title: Text(peer.name),
          subtitle: Text('${peer.endpoint}${peer.trusted ? ' · trusted' : ''}'),
          trailing: Wrap(
            spacing: 8,
            children: [
              IconButton(
                tooltip: 'Connect',
                onPressed: () =>
                    ref.read(appControllerProvider.notifier).connect(peer),
                icon: const Icon(Icons.link),
              ),
              FilledButton.tonal(
                onPressed: () => _pickAndSend(ref),
                child: const Text('Send file'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSend(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    final path = result?.files.single.path;
    if (path == null) return;
    await ref.read(appControllerProvider.notifier).sendFile(peer, path);
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_tethering,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('Waiting for peers on this network…'),
          const SizedBox(height: 4),
          Text(
            'Open LocalPort on another device connected to the same Wi‑Fi.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
