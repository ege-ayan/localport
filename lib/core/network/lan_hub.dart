import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bonsoir/bonsoir.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../data/models/peer.dart';
import '../../data/models/transfer.dart';
import '../constants.dart';
import '../crypto/session_crypto.dart';
import '../identity.dart';
import '../protocol/framing.dart';
import '../protocol/messages.dart';
import '../transfer/chunker.dart';

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

  final _peers = <String, Peer>{};
  final _sessions = <String, _Session>{};
  final _inboundFiles = <String, IOSink>{};

  ServerSocket? _server;
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySub;
  var _running = false;

  int get port => _server?.port ?? defaultListenPort;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      defaultListenPort,
    );
    _server!.listen(
      _onSocket,
      onError: (Object e) => onLog('listen error: $e'),
    );

    final service = BonsoirService(
      name: identity.name,
      type: serviceType,
      port: _server!.port,
      attributes: {'id': identity.id},
    );
    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.initialize();
    await _broadcast!.start();

    _discovery = BonsoirDiscovery(type: serviceType);
    await _discovery!.initialize();
    _discoverySub = _discovery!.eventStream?.listen(_onDiscovery);
    await _discovery!.start();
    onLog('Listening on ${_server!.port}');
  }

  Future<void> stop() async {
    _running = false;
    await _discoverySub?.cancel();
    await _discovery?.stop();
    await _broadcast?.stop();
    await _server?.close();
    for (final session in _sessions.values) {
      session.socket.destroy();
    }
    _sessions.clear();
  }

  Future<void> connect(Peer peer) async {
    if (_sessions.containsKey(peer.id) || peer.id == identity.id) return;
    final socket = await Socket.connect(peer.host, peer.port);
    await _attach(socket, expectedId: peer.id, nameHint: peer.name);
  }

  Future<void> sendFile(Peer peer, String path) async {
    await connect(peer);
    final session = _sessions[peer.id];
    if (session == null) {
      throw StateError('not connected to ${peer.name}');
    }
    final file = File(path);
    final stat = await file.stat();
    final transferId = const Uuid().v4();
    onTransfer(
      TransferProgress(
        id: transferId,
        peerId: peer.id,
        peerName: peer.name,
        fileName: p.basename(path),
        fileSize: stat.size,
        transferred: 0,
        direction: TransferDirection.outbound,
        status: TransferStatus.offering,
      ),
    );
    session.sendJson(
      JsonMessage.fileOffer(
        transferId: transferId,
        fileName: p.basename(path),
        fileSize: stat.size,
      ),
    );
    session.pendingOutbound[transferId] = path;
  }

  Future<void> sendClipboard(String text) async {
    for (final session in _sessions.values) {
      session.sendJson(JsonMessage.clipboard(text));
    }
  }

  void _onDiscovery(BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent(:final service):
        unawaited(service.resolve(_discovery!.serviceResolver));
      case BonsoirDiscoveryServiceResolvedEvent(:final service):
      case BonsoirDiscoveryServiceUpdatedEvent(:final service):
        _upsertDiscovered(service);
      case BonsoirDiscoveryServiceLostEvent(:final service):
        final id = service.attributes['id'] ?? service.name;
        _peers.remove(id);
        onPeers(_peers.values.toList());
      default:
        break;
    }
  }

  void _upsertDiscovered(BonsoirService service) {
    final id = service.attributes['id'] ?? service.name;
    if (id == identity.id) return;
    final host = service.hostAddress ?? service.hostname;
    if (host == null || host.isEmpty) return;
    _peers[id] = Peer(
      id: id,
      name: service.name,
      host: host.replaceAll(RegExp(r'\.$'), ''),
      port: service.port,
      trusted: _peers[id]?.trusted ?? false,
    );
    onPeers(_peers.values.toList());
  }

  Future<void> _onSocket(Socket socket) => _attach(socket);

  Future<void> _attach(
    Socket socket, {
    String? expectedId,
    String? nameHint,
  }) async {
    final keyPair = await SessionCrypto.generateKeyPair();
    final localPub = await keyPair.extractPublicKey();
    final session = _Session(socket: socket, localKeyPair: keyPair);
    session.sendRawJson(
      JsonMessage.hello(
        id: identity.id,
        name: identity.name,
        publicKey: localPub.bytes,
      ),
    );

    framesFrom(socket).listen(
      (frame) => _onFrame(session, frame, expectedId, nameHint),
      onError: (Object e) => onLog('session error: $e'),
      onDone: () {
        if (session.peerId != null) {
          _sessions.remove(session.peerId);
        }
      },
    );
  }

  Future<void> _onFrame(
    _Session session,
    Frame frame,
    String? expectedId,
    String? nameHint,
  ) async {
    if (session.crypto == null) {
      if (frame.kind != MessageKind.json) return;
      final hello = JsonMessage.decode(frame.payload);
      if (hello.type != 'hello') return;
      final id = hello.fields['id'] as String;
      if (expectedId != null && expectedId != id) {
        session.socket.destroy();
        return;
      }
      final pk = base64ToBytes(hello.fields['pk'] as String);
      session.crypto = await SessionCrypto.fromHandshake(
        local: session.localKeyPair,
        remote: SimplePublicKey(pk, type: KeyPairType.x25519),
      );
      session.peerId = id;
      session.peerName = hello.fields['name'] as String? ?? nameHint ?? id;
      _sessions[id] = session;
      final existing = _peers[id];
      _peers[id] = Peer(
        id: id,
        name: session.peerName!,
        host: existing?.host ?? session.socket.remoteAddress.address,
        port: existing?.port ?? session.socket.remotePort,
        trusted: true,
      );
      onPeers(_peers.values.toList());
      onLog('Session with ${session.peerName}');
      return;
    }

    final clear = await session.crypto!.open(frame.payload);
    if (frame.kind == MessageKind.json) {
      await _onJson(session, JsonMessage.decode(clear));
    } else {
      await _onChunk(session, ChunkMessage.decode(clear));
    }
  }

  Future<void> _onJson(_Session session, JsonMessage message) async {
    switch (message.type) {
      case 'file_offer':
        final offer = TransferProgress(
          id: message.fields['transferId'] as String,
          peerId: session.peerId!,
          peerName: session.peerName!,
          fileName: message.fields['fileName'] as String,
          fileSize: (message.fields['fileSize'] as num).toInt(),
          transferred: 0,
          direction: TransferDirection.inbound,
          status: TransferStatus.offering,
        );
        onTransfer(offer);
        final dest = await decideIncomingFile(offer);
        if (dest == null) {
          session.sendJson(JsonMessage.fileReject(offer.id));
          onTransfer(offer.copyWith(status: TransferStatus.rejected));
          return;
        }
        session.inboundPaths[offer.id] = dest;
        session.inboundSizes[offer.id] = offer.fileSize;
        _inboundFiles[offer.id] = File(dest).openWrite();
        session.sendJson(JsonMessage.fileAccept(offer.id));
        onTransfer(offer.copyWith(status: TransferStatus.transferring));
      case 'file_accept':
        final transferId = message.fields['transferId'] as String;
        final path = session.pendingOutbound.remove(transferId);
        if (path == null) return;
        final file = File(path);
        final size = await file.length();
        var sent = 0;
        onTransfer(
          TransferProgress(
            id: transferId,
            peerId: session.peerId!,
            peerName: session.peerName!,
            fileName: p.basename(path),
            fileSize: size,
            transferred: 0,
            direction: TransferDirection.outbound,
            status: TransferStatus.transferring,
          ),
        );
        await FileChunker.streamPath(
          path,
          onChunk: (chunk) {
            session.sendChunk(
              ChunkMessage(
                transferId: transferId,
                offset: chunk.offset,
                data: chunk.bytes,
              ),
            );
            sent += chunk.bytes.length;
            onTransfer(
              TransferProgress(
                id: transferId,
                peerId: session.peerId!,
                peerName: session.peerName!,
                fileName: p.basename(path),
                fileSize: size,
                transferred: sent,
                direction: TransferDirection.outbound,
                status: TransferStatus.transferring,
              ),
            );
          },
        );
        session.sendJson(JsonMessage.fileDone(transferId));
        onTransfer(
          TransferProgress(
            id: transferId,
            peerId: session.peerId!,
            peerName: session.peerName!,
            fileName: p.basename(path),
            fileSize: size,
            transferred: size,
            direction: TransferDirection.outbound,
            status: TransferStatus.done,
          ),
        );
      case 'file_reject':
        final transferId = message.fields['transferId'] as String;
        session.pendingOutbound.remove(transferId);
        onTransfer(
          TransferProgress(
            id: transferId,
            peerId: session.peerId ?? '',
            peerName: session.peerName ?? '',
            fileName: '',
            fileSize: 0,
            transferred: 0,
            direction: TransferDirection.outbound,
            status: TransferStatus.rejected,
          ),
        );
      case 'file_done':
        final transferId = message.fields['transferId'] as String;
        await _inboundFiles.remove(transferId)?.close();
        final dest = session.inboundPaths[transferId];
        onTransfer(
          TransferProgress(
            id: transferId,
            peerId: session.peerId!,
            peerName: session.peerName!,
            fileName: dest == null ? '' : p.basename(dest),
            fileSize:
                session.inboundSizes[transferId] ??
                (dest == null ? 0 : await File(dest).length()),
            transferred: dest == null ? 0 : await File(dest).length(),
            direction: TransferDirection.inbound,
            status: TransferStatus.done,
          ),
        );
      case 'clipboard':
        final text = message.fields['text'] as String? ?? '';
        if (text.isNotEmpty) {
          onClipboard(text, session.peerName ?? 'peer');
        }
    }
  }

  Future<void> _onChunk(_Session session, ChunkMessage chunk) async {
    final sink = _inboundFiles[chunk.transferId];
    if (sink == null) return;
    sink.add(chunk.data);
    final dest = session.inboundPaths[chunk.transferId];
    onTransfer(
      TransferProgress(
        id: chunk.transferId,
        peerId: session.peerId!,
        peerName: session.peerName!,
        fileName: dest == null ? '' : p.basename(dest),
        fileSize: session.inboundSizes[chunk.transferId] ?? 0,
        transferred: chunk.offset + chunk.data.length,
        direction: TransferDirection.inbound,
        status: TransferStatus.transferring,
      ),
    );
  }
}

class _Session {
  _Session({required this.socket, required this.localKeyPair});

  final Socket socket;
  final SimpleKeyPair localKeyPair;
  SessionCrypto? crypto;
  String? peerId;
  String? peerName;
  final pendingOutbound = <String, String>{};
  final inboundPaths = <String, String>{};
  final inboundSizes = <String, int>{};

  void sendRawJson(JsonMessage message) {
    socket.add(
      Frame(MessageKind.json, Uint8List.fromList(message.encode())).encode(),
    );
  }

  void sendJson(JsonMessage message) {
    unawaited(
      _sendSealed(MessageKind.json, Uint8List.fromList(message.encode())),
    );
  }

  void sendChunk(ChunkMessage chunk) {
    unawaited(_sendSealed(MessageKind.chunk, chunk.encode()));
  }

  Future<void> _sendSealed(MessageKind kind, Uint8List payload) async {
    final sealed = await crypto!.seal(payload);
    socket.add(Frame(kind, sealed).encode());
  }
}

Uint8List base64ToBytes(String value) =>
    Uint8List.fromList(base64Decode(value));
