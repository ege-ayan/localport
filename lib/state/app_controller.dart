import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/identity.dart';
import '../core/io/incoming_path.dart';
import '../core/network/lan.dart';
import '../data/collections.dart';
import '../data/database.dart';
import '../data/models/peer.dart';
import '../data/models/transfer.dart';

class AppState {
  const AppState({
    required this.identity,
    required this.peers,
    required this.transfers,
    required this.history,
    required this.logs,
    required this.lastClipboard,
    required this.ready,
  });

  final DeviceIdentity identity;
  final List<Peer> peers;
  final List<TransferProgress> transfers;
  final List<TransferRecord> history;
  final List<String> logs;
  final String lastClipboard;
  final bool ready;

  AppState copyWith({
    DeviceIdentity? identity,
    List<Peer>? peers,
    List<TransferProgress>? transfers,
    List<TransferRecord>? history,
    List<String>? logs,
    String? lastClipboard,
    bool? ready,
  }) {
    return AppState(
      identity: identity ?? this.identity,
      peers: peers ?? this.peers,
      transfers: transfers ?? this.transfers,
      history: history ?? this.history,
      logs: logs ?? this.logs,
      lastClipboard: lastClipboard ?? this.lastClipboard,
      ready: ready ?? this.ready,
    );
  }
}

class AppController extends Notifier<AppState> {
  LanHub? _hub;
  AppDatabase? _db;
  String _lastLocalClipboard = '';
  Timer? _clipboardTimer;

  @override
  AppState build() {
    ref.onDispose(() {
      _clipboardTimer?.cancel();
      unawaited(_hub?.stop());
    });
    Future.microtask(_boot);
    return AppState(
      identity: const DeviceIdentity(id: '', name: 'LocalPort'),
      peers: const [],
      transfers: const [],
      history: const [],
      logs: const [],
      lastClipboard: '',
      ready: false,
    );
  }

  Future<void> _boot() async {
    final identity = await DeviceIdentity.load();
    if (!kIsWeb) {
      _db = await AppDatabase.open();
    }
    state = state.copyWith(identity: identity, ready: true);
    _hub = LanHub(
      identity: identity,
      onPeers: (peers) => state = state.copyWith(peers: peers),
      onTransfer: _onTransfer,
      onClipboard: _onRemoteClipboard,
      onLog: (line) {
        state = state.copyWith(
          logs: [...state.logs.reversed.take(40).toList().reversed, line],
        );
      },
      decideIncomingFile: _saveIncoming,
    );
    await _hub!.start();
    await _refreshHistory();
    if (!kIsWeb) {
      _clipboardTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_pollClipboard());
      });
    }
  }

  Future<void> rename(String name) async {
    await DeviceIdentity.saveName(name);
    state = state.copyWith(
      identity: DeviceIdentity(id: state.identity.id, name: name),
    );
  }

  Future<void> connect(Peer peer) => _hub!.connect(peer);

  Future<void> sendFile(Peer peer, String path) => _hub!.sendFile(peer, path);

  Future<void> shareClipboard([String? text]) async {
    final value = text ?? (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (value == null || value.isEmpty) return;
    _lastLocalClipboard = value;
    state = state.copyWith(lastClipboard: value);
    await _hub?.sendClipboard(value);
  }

  Future<void> _pollClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty || text == _lastLocalClipboard) return;
    _lastLocalClipboard = text;
    state = state.copyWith(lastClipboard: text);
    await _hub?.sendClipboard(text);
  }

  Future<void> _onRemoteClipboard(String text, String fromName) async {
    _lastLocalClipboard = text;
    await Clipboard.setData(ClipboardData(text: text));
    state = state.copyWith(
      lastClipboard: text,
      logs: [...state.logs, 'Clipboard from $fromName'],
    );
  }

  Future<void> _onTransfer(TransferProgress progress) async {
    final next = [
      progress,
      ...state.transfers.where((item) => item.id != progress.id),
    ];
    state = state.copyWith(transfers: next);
    if (progress.status == TransferStatus.done ||
        progress.status == TransferStatus.rejected ||
        progress.status == TransferStatus.failed) {
      await _persist(progress);
    }
  }

  Future<void> _persist(TransferProgress progress) async {
    final db = _db;
    if (db == null) return;
    await db.addTransfer(
      TransferRecord()
        ..transferId = progress.id
        ..peerId = progress.peerId
        ..peerName = progress.peerName
        ..fileName = progress.fileName
        ..fileSize = progress.fileSize
        ..direction = progress.direction.name
        ..status = progress.status.name
        ..createdAt = DateTime.now().toUtc(),
    );
    if (progress.peerId.isNotEmpty) {
      await db.upsertTrusted(progress.peerId, progress.peerName);
    }
    await _refreshHistory();
  }

  Future<void> _refreshHistory() async {
    final db = _db;
    if (db == null) return;
    state = state.copyWith(history: await db.recentTransfers());
  }

  Future<String?> _saveIncoming(TransferProgress offer) {
    return incomingFilePath(offer.fileName);
  }
}

final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);
