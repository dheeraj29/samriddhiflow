import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

class EncryptionService {
  static const _v2Prefix = 'SF_V2';
  static const _iterations = 100000;

  /// Generates a key once per session to avoid redundant PBKDF2 operations.
  Future<Uint8List> deriveKey(String passcode, Uint8List salt) async {
    return await _deriveKeyPbkdf2(passcode, salt, _iterations);
  }

  /// Encrypts data using AES-CBC + HMAC-SHA256.
  /// If [preDerivedKey] is provided, it skips PBKDF2.
  Future<String> encryptData(String data, String passcode,
      {Uint8List? preDerivedKey, Uint8List? salt}) async {
    if (data.isEmpty) return data;

    final usedSalt = salt ?? _generateRandomBytes(16);
    final keyBytes = preDerivedKey ??
        await _deriveKeyPbkdf2(passcode, usedSalt, _iterations);
    final key = encrypt.Key(keyBytes);

    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

    final encrypted = encrypter.encrypt(data, iv: iv);
    final ciphertext = encrypted.bytes;
    final tag = _generateMac(iv.bytes, ciphertext, keyBytes);

    return [
      _v2Prefix,
      _iterations.toString(),
      base64.encode(usedSalt),
      iv.base64,
      base64.encode(tag),
      base64.encode(ciphertext),
    ].join('|');
  }

  /// Decrypts a V2 payload.
  /// If [preDerivedKey] is provided, it skips PBKDF2 if salt matches.
  Future<String> decryptData(String encryptedPayload, String passcode,
      {Uint8List? preDerivedKey}) async {
    if (encryptedPayload.isEmpty) return encryptedPayload;

    final parts = encryptedPayload.split('|');
    if (parts.length != 6 || parts[0] != _v2Prefix) {
      throw const FormatException("Invalid or unsupported encrypted format");
    }

    final iterations = int.parse(parts[1]);
    final salt = base64.decode(parts[2]);
    final iv = encrypt.IV.fromBase64(parts[3]);
    final storedTag = base64.decode(parts[4]);
    final ciphertext = base64.decode(parts[5]);

    final keyBytes =
        preDerivedKey ?? await _deriveKeyPbkdf2(passcode, salt, iterations);

    final computedTag = _generateMac(iv.bytes, ciphertext, keyBytes);
    if (!_fixedTimeEquals(storedTag, computedTag)) {
      throw const FormatException("Incorrect passcode or corrupted data");
    }

    final key = encrypt.Key(keyBytes);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

    try {
      return encrypter.decrypt(encrypt.Encrypted(ciphertext), iv: iv);
    } catch (e) {
      throw const FormatException("Incorrect passcode or corrupted data");
    }
  }

  Uint8List generateSalt() => _generateRandomBytes(16);

  /// Manual PBKDF2-HMAC-SHA256 implementation using package:crypto.
  Future<Uint8List> _deriveKeyPbkdf2(
      String passcode, Uint8List salt, int iterations) async {
    final passwordBytes = utf8.encode(passcode);
    final hmac = Hmac(sha256, passwordBytes);

    // We need 32 bytes (256 bits) for the AES key.
    // PBKDF2 generates key material in blocks of the hash length (32 bytes for SHA256).
    // So we only need 1 block (l = 1).

    // U1 = HMAC(password, salt || blockIndex)
    var blockIndex = Uint8List(4);
    blockIndex[3] = 1; // 1-indexed

    var lastU = hmac.convert([...salt, ...blockIndex]).bytes;
    var result = Uint8List.fromList(lastU);

    for (var i = 1; i < iterations; i++) {
      lastU = hmac.convert(lastU).bytes;
      for (var j = 0; j < 32; j++) {
        result[j] ^= lastU[j];
      }
      // Occasional yield to prevent blocking UI during long derivation
      if (i % 10000 == 0) await Future.delayed(Duration.zero);
    }

    return result;
  }

  Uint8List _generateMac(Uint8List iv, Uint8List ciphertext, Uint8List key) {
    final hmac = Hmac(sha256, key);
    return Uint8List.fromList(hmac.convert([...iv, ...ciphertext]).bytes);
  }

  Uint8List _generateRandomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rnd.nextInt(256)));
  }

  bool _fixedTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
