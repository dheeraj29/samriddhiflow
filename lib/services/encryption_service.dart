import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

class EncryptionService {
  static const _magicPrefix = 'SF_ENC:';

  /// Encrypts a string of data using AES-CBC.
  /// The [passcode] is hashed using SHA-256 to create a 32-byte key.
  /// Returns a string formatted as "base64(iv):base64(encrypted)".
  String encryptData(String data, String passcode) {
    if (data.isEmpty) return data;

    final key = _deriveKey(passcode);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

    final encrypted = encrypter.encrypt('$_magicPrefix$data', iv: iv);

    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts a string of data that was encrypted using [encryptData].
  /// The [encryptedPayload] must be in the format "base64(iv):base64(encrypted)".
  /// Throws an exception if decryption fails (e.g. wrong passcode or bad format).
  String decryptData(String encryptedPayload, String passcode) {
    if (encryptedPayload.isEmpty) return encryptedPayload;

    final parts = encryptedPayload.split(':');
    if (parts.length != 2) {
      throw const FormatException("Invalid encrypted payload format");
    }

    final iv = encrypt.IV.fromBase64(parts[0]);
    final encryptedBytes = encrypt.Encrypted.fromBase64(parts[1]);

    final key = _deriveKey(passcode);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

    try {
      final decrypted = encrypter.decrypt(encryptedBytes, iv: iv);

      if (!decrypted.startsWith(_magicPrefix)) {
        throw const FormatException("Incorrect passcode or corrupted data");
      }

      return decrypted.substring(_magicPrefix.length);
    } catch (e) {
      if (e is FormatException) rethrow;
      throw const FormatException("Incorrect passcode or corrupted data");
    }
  }

  /// Derives a 32-byte Key from a user-supplied passcode using SHA-256.
  encrypt.Key _deriveKey(String passcode) {
    final bytes = utf8.encode(passcode);
    final digest = sha256.convert(bytes);
    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }
}
