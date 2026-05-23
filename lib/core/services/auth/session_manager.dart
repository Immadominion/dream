import 'dart:convert';

import '../../../shared/models/user.dart';
import '../../../shared/services/storage_service.dart';
import '../logger_service.dart';

/// Manages auth session persistence to local storage
/// NO network calls - pure storage operations
/// Keeps session data synchronized between Hive and SharedPreferences
class AuthSessionManager {
  final LoggerService _logger;

  static const String _sessionKey = 'privy_session_json';
  static const String _userTokenKey = StorageService.userTokenKey;
  static const String _walletAddressKey = 'wallet_address';

  AuthSessionManager(this._logger);

  /// Save complete session to storage
  Future<void> saveSession(AuthSession session) async {
    try {
      // Save full session as JSON
      final sessionJson = jsonEncode(session.toJson());
      await StorageService.setString(_sessionKey, sessionJson);

      // Save critical fields separately for quick access
      await StorageService.saveUserToken(session.accessToken);

      if (session.user.walletAddress != null) {
        await StorageService.saveWalletAddress(session.user.walletAddress!);
      }

      _logger.info('Session saved successfully', tag: 'SessionManager');
    } catch (error) {
      _logger.error('Failed to save session', error: error);
      rethrow;
    }
  }

  /// Load session from storage
  /// Returns null if no session exists or session is invalid
  Future<AuthSession?> loadSession() async {
    try {
      final sessionJson = StorageService.getString(_sessionKey);

      if (sessionJson.isEmpty) {
        _logger.info('No session found in storage', tag: 'SessionManager');
        return null;
      }

      final sessionMap = jsonDecode(sessionJson) as Map<String, dynamic>;
      final session = AuthSession.fromJson(sessionMap);

      // Check if session is expired
      if (!session.isValid) {
        _logger.warning('Session expired, clearing', tag: 'SessionManager');
        await clearSession();
        return null;
      }

      _logger.info(
        'Session loaded: ${session.user.email}',
        tag: 'SessionManager',
      );
      return session;
    } catch (error) {
      _logger.error('Failed to load session', error: error);
      // Clear corrupted session
      await clearSession();
      return null;
    }
  }

  /// Check if a valid session exists without loading full session
  /// Faster than loadSession() for quick authentication checks
  Future<bool> hasValidSession() async {
    try {
      final sessionJson = StorageService.getString(_sessionKey);
      if (sessionJson.isEmpty) return false;

      final sessionMap = jsonDecode(sessionJson) as Map<String, dynamic>;
      final expiresAtStr = sessionMap['expiresAt'] as String?;

      if (expiresAtStr == null) return false;

      final expiresAt = DateTime.parse(expiresAtStr);
      final isValid = DateTime.now().isBefore(expiresAt);

      return isValid;
    } catch (error) {
      _logger.error('Failed to check session validity', error: error);
      return false;
    }
  }

  /// Clear session from storage
  Future<void> clearSession() async {
    try {
      await StorageService.setString(_sessionKey, '');
      await StorageService.setString(_userTokenKey, '');
      await StorageService.setString(_walletAddressKey, '');

      _logger.info('Session cleared', tag: 'SessionManager');
    } catch (error) {
      _logger.error('Failed to clear session', error: error);
    }
  }

  /// Get stored wallet address quickly
  Future<String?> getWalletAddress() async {
    final address = StorageService.getString(_walletAddressKey);
    return address.isEmpty ? null : address;
  }

  /// Get stored access token quickly
  Future<String?> getAccessToken() async {
    final token = StorageService.userToken;
    return token.isEmpty ? null : token;
  }

  /// Update session expiration time (for session refresh)
  Future<void> updateExpiration(DateTime newExpiration) async {
    try {
      final session = await loadSession();
      if (session == null) return;

      final updatedSession = AuthSession(
        accessToken: session.accessToken,
        user: session.user,
        expiresAt: newExpiration,
      );

      await saveSession(updatedSession);
      _logger.info('Session expiration updated', tag: 'SessionManager');
    } catch (error) {
      _logger.error('Failed to update session expiration', error: error);
    }
  }

  /// Get session time remaining in minutes
  /// Returns null if no session or session invalid
  Future<int?> getSessionTimeRemaining() async {
    final session = await loadSession();
    if (session == null || !session.isValid) return null;

    final remaining = session.expiresAt.difference(DateTime.now());
    return remaining.inMinutes;
  }

  /// Check if session needs refresh (less than 5 minutes remaining)
  Future<bool> needsRefresh() async {
    final remaining = await getSessionTimeRemaining();
    if (remaining == null) return false;

    return remaining < 5;
  }
}
