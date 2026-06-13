import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class E2EE {
  final _algorithm = X25519();
  final _cipher = AesGcm.with256bits();

  /// Gera um novo par de chaves ECDH (X25519).
  /// A chave privada deve ser salva localmente (Flutter Secure Storage)
  /// A chave pública (em base64) deve ser enviada para o Backend (api/users/me).
  Future<SimpleKeyPair> generateKeyPair() async {
    return await _algorithm.newKeyPair();
  }

  /// Deriva o Shared Secret a partir da Chave Privada Local e da Chave Pública do Destinatário.
  Future<SecretKey> deriveSharedSecret(SimpleKeyPair localKeyPair, String remotePublicKeyBase64) async {
    final remotePublicKeyBytes = base64Decode(remotePublicKeyBase64);
    final remotePublicKey = SimplePublicKey(remotePublicKeyBytes, type: KeyPairType.x25519);

    return await _algorithm.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: remotePublicKey,
    );
  }

  /// Criptografa uma string usando o Shared Secret (AES-GCM).
  /// Retorna um Map com 'ciphertext' e 'nonce', ambos em Base64, para enviar ao servidor.
  Future<Map<String, String>> encryptMessage(String plainText, SecretKey sharedSecret) async {
    final clearTextBytes = utf8.encode(plainText);
    final secretBox = await _cipher.encrypt(
      clearTextBytes,
      secretKey: sharedSecret,
    );

    return {
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes), // mac appended or sent separate
    };
  }

  /// Descriptografa uma mensagem que veio do servidor.
  Future<String> decryptMessage(String ciphertextBase64, String nonceBase64, String macBase64, SecretKey sharedSecret) async {
    final secretBox = SecretBox(
      base64Decode(ciphertextBase64),
      nonce: base64Decode(nonceBase64),
      mac: Mac(base64Decode(macBase64)),
    );

    final clearTextBytes = await _cipher.decrypt(
      secretBox,
      secretKey: sharedSecret,
    );

    return utf8.decode(clearTextBytes);
  }
}
