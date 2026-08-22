import 'dart:convert';
import 'dart:typed_data';

enum MessageKind { json, chunk }

class JsonMessage {
  const JsonMessage(this.fields);

  final Map<String, Object?> fields;

  String get type => fields['type'] as String? ?? '';

  static JsonMessage hello({
    required String id,
    required String name,
    required List<int> publicKey,
  }) {
    return JsonMessage({
      'type': 'hello',
      'id': id,
      'name': name,
      'pk': base64Encode(publicKey),
    });
  }

  static JsonMessage fileOffer({
    required String transferId,
    required String fileName,
    required int fileSize,
  }) {
    return JsonMessage({
      'type': 'file_offer',
      'transferId': transferId,
      'fileName': fileName,
      'fileSize': fileSize,
    });
  }

  static JsonMessage fileAccept(String transferId) =>
      JsonMessage({'type': 'file_accept', 'transferId': transferId});

  static JsonMessage fileReject(String transferId, [String? reason]) =>
      JsonMessage({
        'type': 'file_reject',
        'transferId': transferId,
        'reason': ?reason,
      });

  static JsonMessage fileDone(String transferId) =>
      JsonMessage({'type': 'file_done', 'transferId': transferId});

  static JsonMessage clipboard(String text) => JsonMessage({
    'type': 'clipboard',
    'text': text,
    'ts': DateTime.now().toUtc().millisecondsSinceEpoch,
  });

  List<int> encode() => utf8.encode(jsonEncode(fields));

  static JsonMessage decode(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('expected JSON object');
    }
    return JsonMessage(decoded);
  }
}

class ChunkMessage {
  const ChunkMessage({
    required this.transferId,
    required this.offset,
    required this.data,
  });

  final String transferId;
  final int offset;
  final Uint8List data;

  Uint8List encode() {
    final idBytes = utf8.encode(transferId);
    final builder = BytesBuilder(copy: false)
      ..addByte(idBytes.length)
      ..add(idBytes)
      ..add(_u64(offset))
      ..add(data);
    return builder.toBytes();
  }

  static ChunkMessage decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('empty chunk');
    }
    final idLen = bytes[0];
    if (bytes.length < 1 + idLen + 8) {
      throw const FormatException('truncated chunk');
    }
    final id = utf8.decode(bytes.sublist(1, 1 + idLen));
    final offset = _readU64(bytes, 1 + idLen);
    final data = bytes.sublist(1 + idLen + 8);
    return ChunkMessage(transferId: id, offset: offset, data: data);
  }
}

Uint8List _u64(int value) {
  final data = ByteData(8)..setUint64(0, value, Endian.big);
  return data.buffer.asUint8List();
}

int _readU64(Uint8List bytes, int offset) {
  final view = ByteData.sublistView(bytes, offset, offset + 8);
  return view.getUint64(0, Endian.big);
}
