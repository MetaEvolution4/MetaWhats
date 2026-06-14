import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;

class MediaEncryptionManager {
  static final MediaEncryptionManager _instance = MediaEncryptionManager._internal();
  factory MediaEncryptionManager() => _instance;
  MediaEncryptionManager._internal();

  /// Encrypts a file using AES-GCM.
  /// Returns a map containing the encrypted bytes, the base64 AES key, and the base64 IV.
  String generateRandomKeyBase64() {
    final key = encrypt.Key.fromSecureRandom(32);
    return key.base64;
  }

  Future<Map<String, dynamic>> encryptFile(File file) async {
    final bytes = await file.readAsBytes();

    // Generate random 256-bit key and 96-bit IV
    final key = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(12);

    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    
    // Encrypt
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);

    return {
      'encryptedBytes': encrypted.bytes,
      'keyBase64': key.base64,
      'ivBase64': iv.base64,
    };
  }

  /// Decrypts a byte array using AES-GCM given the base64 key and IV.
  /// Returns the decrypted bytes.
  Future<List<int>> decryptBytes(List<int> encryptedBytes, String keyBase64, String ivBase64) async {
    final key = encrypt.Key.fromBase64(keyBase64);
    final iv = encrypt.IV.fromBase64(ivBase64);

    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    
    // Encrypted class expects the raw bytes
    final encrypted = encrypt.Encrypted(Uint8List.fromList(encryptedBytes));
    
    return encrypter.decryptBytes(encrypted, iv: iv);
  }

  Future<Map<String, dynamic>> encryptString(String text, String keyBase64) async {
    final key = encrypt.Key.fromBase64(keyBase64);
    final iv = encrypt.IV.fromSecureRandom(12);

    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    final encrypted = encrypter.encrypt(text, iv: iv);

    return {
      'ciphertext': encrypted.base64,
      'ivBase64': iv.base64,
    };
  }

  Future<String> decryptString(String ciphertext, String keyBase64, String ivBase64) async {
    final key = encrypt.Key.fromBase64(keyBase64);
    final iv = encrypt.IV.fromBase64(ivBase64);

    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    final encrypted = encrypt.Encrypted.fromBase64(ciphertext);
    
    return encrypter.decrypt(encrypted, iv: iv);
  }
}
