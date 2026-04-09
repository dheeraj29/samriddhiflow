import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/services/encryption_service.dart';

void main() {
  group('EncryptionService Tests', () {
    late EncryptionService service;

    setUp(() {
      service = EncryptionService();
    });

    test('Encrypts and decrypts correctly with the right passcode', () async {
      const passcode = "MySecret123";
      const data = '{"test": "payload"}';

      final encrypted = await service.encryptData(data, passcode);

      expect(encrypted, isNot(equals(data)));
      expect(encrypted.startsWith('SF_V2|'), isTrue);

      final decrypted = await service.decryptData(encrypted, passcode);
      expect(decrypted, equals(data));
    });

    test('Throws FormatException for badly formatted payload', () async {
      expect(
          () async => await service.decryptData("bad_payload", "pass"),
          throwsA(predicate((e) =>
              e is FormatException &&
              e.toString().contains("Invalid or unsupported"))));
    });

    test('Throws FormatException on wrong passcode', () async {
      const passcode = "RightPasscode";
      const wrongPasscode = "WrongPasscode";
      const data = "Sensitive Data";

      final encrypted = await service.encryptData(data, passcode);

      // Decrypting with the wrong key will cause HMAC to mismatch
      expect(
          () async => await service.decryptData(encrypted, wrongPasscode),
          throwsA(predicate((e) =>
              e is FormatException &&
              e.toString().contains("Incorrect passcode or corrupted data"))));
    });

    test('Detects tampering (HMAC mismatch)', () async {
      const passcode = "MySecret123";
      const data = "Test Data";

      final encrypted = await service.encryptData(data, passcode);

      // Tamper with the ciphertext (the last part)
      final parts = encrypted.split('|');
      final ciphertext = parts.last;

      // Flip a character in the ciphertext base64 string that is NOT a padding character
      final hackedCiphertext = ciphertext.replaceFirst(
          ciphertext[5], ciphertext[5] == 'A' ? 'B' : 'A');
      parts[5] = hackedCiphertext;
      final tamperedPayload = parts.join('|');

      expect(
          () async => await service.decryptData(tamperedPayload, passcode),
          throwsA(predicate((e) =>
              e is FormatException &&
              e.toString().contains("Incorrect passcode or corrupted data"))));
    });

    test('Encrypting empty string returns empty string safely', () async {
      expect(await service.encryptData("", "pass"), equals(""));
      expect(await service.decryptData("", "pass"), equals(""));
    });
  });
}
