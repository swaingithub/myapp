import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  // In a real app, this key should be securely exchanged or derived.
  // For this demo, we use a static key to demonstrate the encryption mechanism.
  static final _key = enc.Key.fromUtf8('my32lengthsupersecretnooneknows1');
  static final _iv = enc.IV.fromUtf8('16bytesstaticiv1');
  static final _encrypter = enc.Encrypter(enc.AES(_key));

  static String encrypt(String text) {
    return _encrypter.encrypt(text, iv: _iv).base64;
  }

  static String decrypt(String encryptedText) {
    try {
      return _encrypter.decrypt(enc.Encrypted.fromBase64(encryptedText),
          iv: _iv);
    } catch (e) {
      return encryptedText; // Fallback for unencrypted messages
    }
  }
}
