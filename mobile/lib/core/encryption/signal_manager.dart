import 'dart:convert';
import 'dart:typed_data';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SignalManager {
  static final SignalManager _instance = SignalManager._internal();
  factory SignalManager() => _instance;
  SignalManager._internal();

  final _secureStorage = const FlutterSecureStorage();

  late IdentityKeyPair _identityKeyPair;
  late int _registrationId;
  late InMemoryPreKeyStore _preKeyStore;
  late InMemorySignedPreKeyStore _signedPreKeyStore;
  late InMemorySessionStore _sessionStore;
  late InMemoryIdentityKeyStore _identityStore;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // In a real production app, you would load these from secure storage.
    // For Phase 3 MVP, we will generate them if they don't exist and save.
    
    final hasKeys = await _secureStorage.containsKey(key: 'registration_id');

    if (hasKeys) {
      // Load existing (mocked load for brevity - in production you serialize/deserialize stores)
      // Since serialization of InMemory stores isn't trivial out of the box without writing custom stores,
      // we generate new keys on every fresh login for the MVP if the DB was cleared.
      await _generateNewKeys();
    } else {
      await _generateNewKeys();
    }

    _isInitialized = true;
  }

  Future<void> _generateNewKeys() async {
    _identityKeyPair = generateIdentityKeyPair();
    _registrationId = generateRegistrationId(false);

    final preKeys = generatePreKeys(0, 100);
    final signedPreKey = generateSignedPreKey(_identityKeyPair, 0);

    _sessionStore = InMemorySessionStore();
    _preKeyStore = InMemoryPreKeyStore();
    _signedPreKeyStore = InMemorySignedPreKeyStore();
    _identityStore = InMemoryIdentityKeyStore(_identityKeyPair, _registrationId);

    for (var p in preKeys) {
      await _preKeyStore.storePreKey(p.id, p);
    }
    await _signedPreKeyStore.storeSignedPreKey(signedPreKey.id, signedPreKey);

    await _secureStorage.write(key: 'registration_id', value: _registrationId.toString());
    // In production, save all keys to SQLite encrypted with a key from secure storage.
  }

  Future<Map<String, dynamic>> getBundleForServer() async {
    await initialize();

    final signedPreKey = await _signedPreKeyStore.loadSignedPreKey(0);
    final preKeyList = [];
    for (int i = 0; i < 100; i++) {
      final pk = await _preKeyStore.loadPreKey(i);
      preKeyList.add({
        'key_id': pk.id,
        'public_key': base64Encode(pk.getKeyPair().publicKey.serialize()),
      });
    }

    return {
      'registration_id': _registrationId,
      'identity_key': base64Encode(_identityKeyPair.publicKey.serialize()),
      'signed_pre_key': base64Encode(signedPreKey.getKeyPair().publicKey.serialize()),
      'signed_signature': base64Encode(signedPreKey.signature),
      'signed_key_id': signedPreKey.id,
      'pre_keys': preKeyList,
    };
  }

  Future<void> processPreKeyBundle(String remoteUserId, Map<String, dynamic> bundle) async {
    await initialize();

    final remoteAddress = SignalProtocolAddress(remoteUserId, 1);
    final sessionBuilder = SessionBuilder(_sessionStore, _preKeyStore, _signedPreKeyStore, _identityStore, remoteAddress);

    final identityKey = IdentityKey.fromBytes(base64Decode(bundle['identity_key']), 0);
    final signedPreKey = ECPublicKey(base64Decode(bundle['signed_pre_key']));
    final signature = base64Decode(bundle['signed_signature']);
    final preKey = bundle['pre_key'] != null ? ECPublicKey(base64Decode(bundle['pre_key']['public_key'])) : null;
    
    final preKeyBundle = PreKeyBundle(
      bundle['registration_id'],
      1, // deviceId
      bundle['pre_key'] != null ? bundle['pre_key']['key_id'] : null,
      preKey,
      bundle['signed_key_id'],
      signedPreKey,
      signature,
      identityKey
    );

    await sessionBuilder.processPreKeyBundle(preKeyBundle);
  }

  Future<String> encryptMessage(String remoteUserId, String plaintext) async {
    await initialize();
    final remoteAddress = SignalProtocolAddress(remoteUserId, 1);
    final sessionCipher = SessionCipher(_sessionStore, _preKeyStore, _signedPreKeyStore, _identityStore, remoteAddress);
    
    final ciphertextMessage = await sessionCipher.encrypt(Uint8List.fromList(utf8.encode(plaintext)));
    
    // Convert CiphertextMessage to base64
    return base64Encode(ciphertextMessage.serialize());
  }

  Future<String> decryptMessage(String remoteUserId, String ciphertextBase64, int cipherType) async {
    await initialize();
    final remoteAddress = SignalProtocolAddress(remoteUserId, 1);
    final sessionCipher = SessionCipher(_sessionStore, _preKeyStore, _signedPreKeyStore, _identityStore, remoteAddress);
    
    final bytes = base64Decode(ciphertextBase64);
    
    Uint8List plaintextBytes;
    if (cipherType == 3) {
      final message = WhisperMessage.fromBytes(bytes);
      plaintextBytes = await sessionCipher.decrypt(message);
    } else {
      final message = PreKeyWhisperMessage.fromBytes(bytes);
      plaintextBytes = await sessionCipher.decrypt(message as PreKeyWhisperMessage);
    }
    
    return utf8.decode(plaintextBytes);
  }
}
