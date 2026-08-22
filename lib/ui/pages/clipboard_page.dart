import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_controller.dart';

class ClipboardPage extends ConsumerStatefulWidget {
  const ClipboardPage({super.key});

  @override
  ConsumerState<ClipboardPage> createState() => _ClipboardPageState();
}

class _ClipboardPageState extends ConsumerState<ClipboardPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clip = ref.watch(appControllerProvider).lastClipboard;
    if (_controller.text != clip && clip.isNotEmpty) {
      _controller.text = clip;
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Clipboard', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Text copied here is pushed to connected devices over the encrypted session.',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste or type text to share…',
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => ref
                .read(appControllerProvider.notifier)
                .shareClipboard(_controller.text),
            icon: const Icon(Icons.ios_share),
            label: const Text('Share with peers'),
          ),
        ],
      ),
    );
  }
}
