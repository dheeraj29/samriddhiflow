import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/services/encryption_service.dart';

void main() {
  group('EncryptionService Tests', () {
    late EncryptionService service;

    setUp(() {
      service = EncryptionService();
    });

    test('Encrypts and decrypts correctly with the right passcode', () {
      const passcode = "MySecret123";
      const data = '{"test": "payload"}';

      final encrypted = service.encryptData(data, passcode);

      expect(encrypted, isNot(equals(data)));
      expect(encrypted.contains(':'), isTrue); // IV:Encrypted format

      final decrypted = service.decryptData(encrypted, passcode);
      expect(decrypted, equals(data));
    });

    test('Throws FormatException for badly formatted payload', () {
      expect(() => service.decryptData("bad_payload", "pass"),
          throwsA(isA<FormatException>()));
    });

    test('Throws generic Error/Exception on wrong passcode', () {
      const passcode = "RightPasscode";
      const wrongPasscode = "WrongPasscode";
      const data = "Sensitive Data";

      final encrypted = service.encryptData(data, passcode);

      // Decrypting AES with the wrong key now throws a FormatException due to magic prefix check.
      expect(() => service.decryptData(encrypted, wrongPasscode),
          throwsA(isA<FormatException>()));
    });

    test('Encrypting empty string returns empty string safely', () {
      expect(service.encryptData("", "pass"), equals(""));
      expect(service.decryptData("", "pass"), equals(""));
    });
  });
}
