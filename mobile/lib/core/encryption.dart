import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EncryptedData {
  final String cipherText;
  final String nonce;
  final String mac;

  EncryptedData({required this.cipherText, required this.nonce, required this.mac});
}

class EncryptionService {
  final _algorithm = X25519();
  final _cipher = AesGcm.with256bits();

  Future<void> initKeypair() async {
    final keyPair = await _algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('public_key', base64Encode(publicKey.bytes));
    await prefs.setString('private_key', base64Encode(privateKeyBytes));
  }

  Future<SecretKey> deriveSharedSecret(String remotePublicKeyBase64) async {
    final prefs = await SharedPreferences.getInstance();
    final privKeyStr = prefs.getString('private_key');
    if (privKeyStr == null) throw Exception('No local keypair found');
    
    final localKeyPair = SimpleKeyPairData(
      base64Decode(privKeyStr),
      publicKey: SimplePublicKey(
        base64Decode(prefs.getString('public_key')!), 
        type: KeyPairType.x25519
      ),
      type: KeyPairType.x25519,
    );

    final remotePublicKeyBytes = base64Decode(remotePublicKeyBase64);
    final remotePublicKey = SimplePublicKey(remotePublicKeyBytes, type: KeyPairType.x25519);

    return await _algorithm.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: remotePublicKey,
    );
  }

  Future<EncryptedData> encryptMessage(String plainText, SecretKey sharedSecret) async {
    final clearTextBytes = utf8.encode(plainText);
    final secretBox = await _cipher.encrypt(
      clearTextBytes,
      secretKey: sharedSecret,
    );

    return EncryptedData(
      cipherText: base64Encode(secretBox.cipherText),
      nonce: base64Encode(secretBox.nonce),
      mac: base64Encode(secretBox.mac.bytes),
    );
  }

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
