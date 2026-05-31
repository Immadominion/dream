import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized, hardware-backed secure storage for sensitive values
/// (auth tokens, JWTs, signing material).
///
/// Backed by the Android Keystore (`EncryptedSharedPreferences`) and the iOS
/// Keychain. Use this — never plain [SharedPreferences] — for anything that
/// authorizes a user or moves funds.
class SecureStorageService {
  SecureStorageService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

  /// Read a value. Returns `null` when the key is absent.
  static Future<String?> read(String key) => _storage.read(key: key);

  /// Write a value. Passing an empty or null value deletes the key.
  static Future<void> write(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(key: key, value: value);
  }

  /// Delete a single key.
  static Future<void> delete(String key) => _storage.delete(key: key);

  /// Delete every key managed by this store (call on full logout/reset).
  static Future<void> deleteAll() => _storage.deleteAll();
}
