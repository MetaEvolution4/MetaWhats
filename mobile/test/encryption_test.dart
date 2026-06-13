import 'package:flutter_test/flutter_test.dart';
import 'package:metawhats/core/encryption.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:convert';

void main() {
  group('E2EE Encryption Tests', () {
    late E2EE e2ee;

    setUp(() {
      e2ee = E2EE();
    });

    test('Alice should be able to encrypt and Bob should be able to decrypt the message', () async {
      // 1. Setup Keys for Alice and Bob
      final aliceKeyPair = await e2ee.generateKeyPair();
      final bobKeyPair = await e2ee.generateKeyPair();

      // Simulate Public Key exchange via backend (Base64 strings)
      final alicePublicKeyBytes = await aliceKeyPair.extractPublicKey();
      final alicePublicKeyBase64 = base64Encode(alicePublicKeyBytes.bytes);

      final bobPublicKeyBytes = await bobKeyPair.extractPublicKey();
      final bobPublicKeyBase64 = base64Encode(bobPublicKeyBytes.bytes);

      // 2. Alice derives shared secret using her private key and Bob's public key
      final aliceSharedSecret = await e2ee.deriveSharedSecret(aliceKeyPair, bobPublicKeyBase64);

      // 3. Bob derives shared secret using his private key and Alice's public key
      final bobSharedSecret = await e2ee.deriveSharedSecret(bobKeyPair, alicePublicKeyBase64);

      // 4. Alice encrypts a message for Bob
      final plainText = "Hello Bob, this is a top secret message!";
      final encryptedPayload = await e2ee.encryptMessage(plainText, aliceSharedSecret);

      final ciphertext = encryptedPayload['ciphertext']!;
      final nonce = encryptedPayload['nonce']!;
      final mac = encryptedPayload['mac']!;

      expect(ciphertext, isNot(contains('Hello'))); // Proves it is encrypted

      // 5. Bob decrypts the message using his derived shared secret
      final decryptedText = await e2ee.decryptMessage(ciphertext, nonce, mac, bobSharedSecret);

      expect(decryptedText, equals(plainText));
    });

    test('Eve should NOT be able to decrypt the message without private keys', () async {
      final aliceKeyPair = await e2ee.generateKeyPair();
      final bobKeyPair = await e2ee.generateKeyPair();
      final eveKeyPair = await e2ee.generateKeyPair(); // Eve's own keypair

      final bobPublicKeyBytes = await bobKeyPair.extractPublicKey();
      final bobPublicKeyBase64 = base64Encode(bobPublicKeyBytes.bytes);
      
      final alicePublicKeyBytes = await aliceKeyPair.extractPublicKey();
      final alicePublicKeyBase64 = base64Encode(alicePublicKeyBytes.bytes);

      final aliceSharedSecret = await e2ee.deriveSharedSecret(aliceKeyPair, bobPublicKeyBase64);
      final plainText = "Secret for Bob";
      final encryptedPayload = await e2ee.encryptMessage(plainText, aliceSharedSecret);

      // Eve intercepts ciphertext, nonce, mac, and Alice's public key, 
      // but she tries to derive secret using HER private key instead of Bob's
      final eveSharedSecret = await e2ee.deriveSharedSecret(eveKeyPair, alicePublicKeyBase64);

      expect(
        () async => await e2ee.decryptMessage(
          encryptedPayload['ciphertext']!, 
          encryptedPayload['nonce']!, 
          encryptedPayload['mac']!, 
          eveSharedSecret
        ),
        throwsA(isA<SecretBoxAuthenticationError>())
      );
    });
  });
}
