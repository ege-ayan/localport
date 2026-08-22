import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// X25519 handshake + AES-256-GCM session, used for every LAN payload.
class SessionCrypto {
  SessionCrypto._(this._key);

  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  final SecretKey _key;

  static Future<SimpleKeyPair> generateKeyPair() => _x25519.newKeyPair();

  static Future<SessionCrypto> fromHandshake({
    required SimpleKeyPair local,
    required SimplePublicKey remote,
  }) async {
    final shared = await _x25519.sharedSecretKey(
      keyPair: local,
      remotePublicKey: remote,
    );
    final derived = await _hkdf.deriveKey(
      secretKey: shared,
      info: utf8.encode('localport/v1'),
    );
    return SessionCrypto._(derived);
  }

  Future<Uint8List> seal(List<int> plaintext) async {
    final box = await _aes.encrypt(plaintext, secretKey: _key);
    final nonce = Uint8List.fromList(box.nonce);
    final cipher = Uint8List.fromList(box.cipherText);
    final mac = Uint8List.fromList(box.mac.bytes);
    final out = BytesBuilder(copy: false)
      ..add([nonce.length, mac.length])
      ..add(nonce)
      ..add(mac)
      ..add(cipher);
    return out.toBytes();
  }

  Future<Uint8List> open(Uint8List sealed) async {
    if (sealed.length < 2) {
      throw const FormatException('truncated ciphertext');
    }
    final nonceLen = sealed[0];
    final macLen = sealed[1];
    final header = 2 + nonceLen + macLen;
    if (sealed.length < header) {
      throw const FormatException('truncated ciphertext');
    }
    final nonce = sealed.sublist(2, 2 + nonceLen);
    final mac = sealed.sublist(2 + nonceLen, header);
    final cipher = sealed.sublist(header);
    final clear = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
      secretKey: _key,
    );
    return Uint8List.fromList(clear);
  }
}
