import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localport/core/crypto/session_crypto.dart';

void main() {
  test('X25519 peers can seal and open AES-256-GCM payloads', () async {
    final alice = await SessionCrypto.generateKeyPair();
    final bob = await SessionCrypto.generateKeyPair();
    final alicePub = await alice.extractPublicKey();
    final bobPub = await bob.extractPublicKey();

    final aliceSession = await SessionCrypto.fromHandshake(
      local: alice,
      remote: bobPub,
    );
    final bobSession = await SessionCrypto.fromHandshake(
      local: bob,
      remote: alicePub,
    );

    final sealed = await aliceSession.seal('secret payload'.codeUnits);
    final opened = await bobSession.open(sealed);
    expect(String.fromCharCodes(opened), 'secret payload');
  });

  test('wrong remote key cannot open the payload', () async {
    final alice = await SessionCrypto.generateKeyPair();
    final bob = await SessionCrypto.generateKeyPair();
    final eve = await SessionCrypto.generateKeyPair();
    final bobPub = await bob.extractPublicKey();
    final evePub = await eve.extractPublicKey();

    final aliceSession = await SessionCrypto.fromHandshake(
      local: alice,
      remote: bobPub,
    );
    final eveSession = await SessionCrypto.fromHandshake(
      local: eve,
      remote: evePub,
    );
    final sealed = await aliceSession.seal([9, 8, 7]);
    expect(
      eveSession.open(sealed),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
