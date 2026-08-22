import 'dart:async';
import 'dart:typed_data';

import 'messages.dart';

/// Length-prefixed frames: `[u32be length][u8 kind][payload]`.
class Frame {
  const Frame(this.kind, this.payload);

  final MessageKind kind;
  final Uint8List payload;

  Uint8List encode() {
    final body = BytesBuilder(copy: false)
      ..addByte(kind == MessageKind.json ? 0 : 1)
      ..add(payload);
    final bytes = body.toBytes();
    final header = ByteData(4)..setUint32(0, bytes.length);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...bytes]);
  }

  static Frame parse(Uint8List body) {
    if (body.isEmpty) {
      throw const FormatException('empty frame');
    }
    final kind = body[0] == 0 ? MessageKind.json : MessageKind.chunk;
    return Frame(kind, body.sublist(1));
  }
}

class FrameReader {
  final _buffer = BytesBuilder(copy: false);

  Iterable<Frame> add(List<int> data) sync* {
    _buffer.add(data);
    while (true) {
      final available = _buffer.length;
      if (available < 4) return;
      final raw = _buffer.toBytes();
      final length = ByteData.sublistView(raw, 0, 4).getUint32(0);
      if (available < 4 + length) return;
      final body = raw.sublist(4, 4 + length);
      final rest = raw.sublist(4 + length);
      _buffer.clear();
      if (rest.isNotEmpty) {
        _buffer.add(rest);
      }
      yield Frame.parse(body);
    }
  }
}

class FrameWriter {
  FrameWriter(this._add);

  final void Function(List<int> bytes) _add;

  void write(Frame frame) => _add(frame.encode());

  void writeJson(JsonMessage message) {
    write(Frame(MessageKind.json, Uint8List.fromList(message.encode())));
  }

  void writeChunk(ChunkMessage chunk) {
    write(Frame(MessageKind.chunk, chunk.encode()));
  }
}

Stream<Frame> framesFrom(Stream<List<int>> incoming) {
  final reader = FrameReader();
  return incoming.asyncExpand(
    (chunk) => Stream.fromIterable(reader.add(chunk)),
  );
}
