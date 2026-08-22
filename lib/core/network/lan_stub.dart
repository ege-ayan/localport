import '../../data/models/peer.dart';
import '../../data/models/transfer.dart';
import '../identity.dart';

typedef IncomingFileHandler = Future<String?> Function(TransferProgress offer);

class LanHub {
  LanHub({
    required this.identity,
    required this.onPeers,
    required this.onTransfer,
    required this.onClipboard,
    required this.onLog,
    required this.decideIncomingFile,
  });

  final DeviceIdentity identity;
  final void Function(List<Peer> peers) onPeers;
  final void Function(TransferProgress progress) onTransfer;
  final void Function(String text, String fromName) onClipboard;
  final void Function(String message) onLog;
  final IncomingFileHandler decideIncomingFile;

  int get port => 0;

  Future<void> start() async {
    onLog('LAN features require a native build (not web).');
  }

  Future<void> stop() async {}

  Future<void> connect(Peer peer) async {}

  Future<void> sendFile(Peer peer, String path) async {}

  Future<void> sendClipboard(String text) async {}
}
