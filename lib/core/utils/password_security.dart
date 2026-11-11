import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Salted SHA-256 password hashing & verification.
/// Stored format: `<salt>:<hexDigest>` (salt must NOT contain ':').
class PasswordSecurity {
  static String hashPassword(String password, {String? salt}) {
    salt ??= const Uuid().v4().replaceAll('-', '').substring(0, 16);
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return '$salt:$digest';
  }

  static bool verify(String storedHashOrPlaintext, String password) {
    if (storedHashOrPlaintext.isEmpty || password.isEmpty) return false;
    if (storedHashOrPlaintext.contains(':')) {
      final parts = storedHashOrPlaintext.split(':');
      if (parts.length == 2) {
        final salt = parts[0];
        final expectedHash = parts[1];
        final bytes = utf8.encode('$salt:$password');
        final digest = sha256.convert(bytes).toString();
        return _constantTimeEquals(digest, expectedHash);
      }
    }
    // Legacy plaintext accounts (auto-upgraded to a hash on next login).
    return storedHashOrPlaintext == password;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
