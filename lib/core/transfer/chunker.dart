import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../constants.dart';

class FileChunk {
  const FileChunk({required this.offset, required this.bytes});

  final int offset;
  final Uint8List bytes;
}

/// Reads a file on a worker isolate so the UI isolate stays free.
class FileChunker {
  static Future<void> streamPath(
    String path, {
    required void Function(FileChunk chunk) onChunk,
    int size = chunkSize,
  }) async {
    final receive = ReceivePort();
    await Isolate.spawn(_readWorker, _ReadArgs(path, size, receive.sendPort));
    await for (final message in receive) {
      if (message == null) {
        receive.close();
        return;
      }
      if (message is _ReadError) {
        receive.close();
        throw FileSystemException(message.reason, path);
      }
      onChunk(message as FileChunk);
    }
  }
}

class _ReadArgs {
  const _ReadArgs(this.path, this.size, this.port);

  final String path;
  final int size;
  final SendPort port;
}

class _ReadError {
  const _ReadError(this.reason);

  final String reason;
}

Future<void> _readWorker(_ReadArgs args) async {
  try {
    final file = File(args.path);
    final raf = await file.open();
    var offset = 0;
    try {
      while (true) {
        final bytes = await raf.read(args.size);
        if (bytes.isEmpty) break;
        args.port.send(FileChunk(offset: offset, bytes: bytes));
        offset += bytes.length;
      }
      args.port.send(null);
    } finally {
      await raf.close();
    }
  } catch (error) {
    args.port.send(_ReadError(error.toString()));
  }
}
