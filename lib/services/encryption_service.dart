import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _storage = const FlutterSecureStorage();
  encrypt.Key? _key;
  final _iv = encrypt.IV.fromLength(16); // Initialization Vector

  // Initialize the encryption service
  Future<void> init() async {
    String? storedKey = await _storage.read(key: 'encryption_key');

    if (storedKey == null) {
      // Generate a new key if none exists
      final key = encrypt.Key.fromSecureRandom(32);
      await _storage.write(
          key: 'encryption_key', value: base64UrlEncode(key.bytes));
      _key = key;
    } else {
      // Load existing key
      _key = encrypt.Key(base64Url.decode(storedKey));
    }
  }

  // Encrypt a message
  String encryptMessage(String plainText) {
    if (_key == null) return plainText; // Fallback if not initialized

    final encrypter = encrypt.Encrypter(encrypt.AES(_key!));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  // Decrypt a message
  String decryptMessage(String encryptedText) {
    if (_key == null) return encryptedText;

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_key!));
      final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e) {
      // Return original text if decryption fails (e.g., for old unencrypted messages)
      return encryptedText;
    }
  }
}
