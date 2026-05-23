import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Service for managing local storage using Hive and SharedPreferences
class StorageService {
  static SharedPreferences? _prefs;
  static Box? _userBox;
  static Box? _settingsBox;

  // Box names
  static const String userBoxName = 'user_data';
  static const String settingsBoxName = 'app_settings';

  // Initialize storage service
  static Future<void> initialize() async {
    try {
      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      // Open Hive boxes
      _userBox = await Hive.openBox(userBoxName);
      _settingsBox = await Hive.openBox(settingsBoxName);
    } catch (e) {
      throw Exception('Failed to initialize storage service: $e');
    }
  }

  // SharedPreferences methods for simple key-value storage
  static Future<bool> setBool(String key, bool value) async {
    return await _prefs?.setBool(key, value) ?? false;
  }

  static Future<bool> saveBool(String key, bool value) async {
    return setBool(key, value);
  }

  static Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(key, value) ?? false;
  }

  static Future<bool> setInt(String key, int value) async {
    return await _prefs?.setInt(key, value) ?? false;
  }

  static Future<bool> setDouble(String key, double value) async {
    return await _prefs?.setDouble(key, value) ?? false;
  }

  static Future<bool> saveDouble(String key, double value) async {
    return setDouble(key, value);
  }

  static bool getBool(String key, {bool defaultValue = false}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  static String getString(String key, {String defaultValue = ''}) {
    return _prefs?.getString(key) ?? defaultValue;
  }

  static int getInt(String key, {int defaultValue = 0}) {
    return _prefs?.getInt(key) ?? defaultValue;
  }

  static double getDouble(String key, {double defaultValue = 0.0}) {
    return _prefs?.getDouble(key) ?? defaultValue;
  }

  // JSON storage methods
  static Future<bool> saveJson(String key, Map<String, dynamic> value) async {
    try {
      final jsonString = jsonEncode(value);
      return await setString(key, jsonString);
    } catch (e) {
      return false;
    }
  }

  static Map<String, dynamic>? getJson(String key) {
    try {
      final jsonString = getString(key);
      if (jsonString.isEmpty) return null;
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // Hive methods for complex object storage
  static Future<void> saveUserData(String key, dynamic value) async {
    await _userBox?.put(key, value);
  }

  static dynamic getUserData(String key) {
    return _userBox?.get(key);
  }

  static Future<void> saveSettings(String key, dynamic value) async {
    await _settingsBox?.put(key, value);
  }

  static dynamic getSettings(String key) {
    return _settingsBox?.get(key);
  }

  static Future<void> clearUserData() async {
    await _userBox?.clear();
  }

  static Future<void> clearSettings() async {
    await _settingsBox?.clear();
  }

  static Future<void> clearAll() async {
    await _prefs?.clear();
    await clearUserData();
    await clearSettings();
  }

  // Common storage keys
  static const String isFirstLaunchKey = 'is_first_launch';
  static const String userTokenKey = 'user_token';
  static const String walletAddressKey = 'wallet_address';
  static const String themeKey = 'app_theme';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String privyAccessTokenKey = 'privy_access_token';

  // Convenience methods for common operations
  static bool get isFirstLaunch =>
      getBool(isFirstLaunchKey, defaultValue: true);
  static Future<void> setFirstLaunchComplete() =>
      setBool(isFirstLaunchKey, false);

  static String get userToken => getString(userTokenKey);
  static Future<void> saveUserToken(String token) =>
      setString(userTokenKey, token);

  static String get walletAddress => getString(walletAddressKey);
  static Future<void> saveWalletAddress(String address) =>
      setString(walletAddressKey, address);

  static String get privyAccessToken => getString(privyAccessTokenKey);
  static Future<void> savePrivyAccessToken(String token) =>
      setString(privyAccessTokenKey, token);

  static bool get notificationsEnabled =>
      getBool(notificationsEnabledKey, defaultValue: true);
  static Future<void> setNotificationsEnabled(bool enabled) =>
      setBool(notificationsEnabledKey, enabled);

  // API Key storage
  static const String apiKeyKey = 'api_key';

  static Future<void> storeApiKey(String apiKey) async {
    await setString(apiKeyKey, apiKey);
  }

  static Future<String?> getApiKey() async {
    final key = getString(apiKeyKey);
    return key.isEmpty ? null : key;
  }
}
