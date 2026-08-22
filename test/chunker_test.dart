import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localport/core/transfer/chunker.dart';
import 'package:path/path.dart' as p;

void main() {
  test('FileChunker reads a file on a worker isolate', () async {
    final dir = await Directory.systemTemp.createTemp('localport-chunker-');
    final file = File(p.join(dir.path, 'payload.bin'));
    final payload = List<int>.generate(200, (i) => i % 256);
    await file.writeAsBytes(payload);

    final collected = <int>[];
    var lastEnd = 0;
    await FileChunker.streamPath(
      file.path,
      size: 64,
      onChunk: (chunk) {
        expect(chunk.offset, lastEnd);
        collected.addAll(chunk.bytes);
        lastEnd = chunk.offset + chunk.bytes.length;
      },
    );

    expect(collected, payload);
    await dir.delete(recursive: true);
  });
}
