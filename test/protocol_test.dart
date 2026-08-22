import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:localport/core/protocol/framing.dart';
import 'package:localport/core/protocol/messages.dart';

void main() {
  test('JSON hello round-trips through a length-prefixed frame', () {
    final hello = JsonMessage.hello(
      id: 'abc',
      name: 'Desk',
      publicKey: List<int>.generate(8, (i) => i),
    );
    final encoded = Frame(
      MessageKind.json,
      Uint8List.fromList(hello.encode()),
    ).encode();

    final reader = FrameReader();
    final frames = reader.add(encoded).toList();
    expect(frames, hasLength(1));
    final decoded = JsonMessage.decode(frames.single.payload);
    expect(decoded.type, 'hello');
    expect(decoded.fields['id'], 'abc');
    expect(decoded.fields['name'], 'Desk');
  });

  test('FrameReader reassembles split packets', () {
    final message = JsonMessage.clipboard('hello');
    final bytes = Frame(
      MessageKind.json,
      Uint8List.fromList(message.encode()),
    ).encode();
    final reader = FrameReader();
    expect(reader.add(bytes.sublist(0, 3)), isEmpty);
    final frames = reader.add(bytes.sublist(3)).toList();
    expect(frames, hasLength(1));
    expect(JsonMessage.decode(frames.single.payload).fields['text'], 'hello');
  });

  test('chunk encode/decode keeps offset and payload', () {
    final chunk = ChunkMessage(
      transferId: 't1',
      offset: 65536,
      data: Uint8List.fromList([1, 2, 3, 4]),
    );
    final decoded = ChunkMessage.decode(chunk.encode());
    expect(decoded.transferId, 't1');
    expect(decoded.offset, 65536);
    expect(decoded.data, [1, 2, 3, 4]);
  });
}
