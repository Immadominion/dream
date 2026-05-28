import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/storage_service.dart';
import '../../constants/app_constants.dart';
import '../../models/app_notification.dart';
import '../logger_service.dart';
import '../notification_service.dart';
import '../wallet/mwa_wallet_service.dart';
import '../wallet/privy_wallet_manager.dart';

final remoteNotificationServiceProvider = Provider<RemoteNotificationService>(
  (ref) {
    return RemoteNotificationService(
      logger: ref.watch(loggerServiceProvider),
      notificationService: ref.watch(notificationServiceProvider),
      privyWalletManager: ref.watch(privyWalletManagerProvider),
      mwaWalletService: ref.watch(mwaWalletServiceProvider),
    );
  },
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignore initialization races in the background isolate.
  }
}

class NotificationTapPayload {
  final String? symbol;
  final String? route;
  final String? eventId;

  const NotificationTapPayload({this.symbol, this.route, this.eventId});
}

class RemoteNotificationService {
  static const _installationIdKey = 'notifications_installation_id_v1';
  static const _deviceSyncPrefix = 'notifications_device_sync_';

  final LoggerService _logger;
  final NotificationService _notificationService;
  final PrivyWalletManager _privyWalletManager;
  final MwaWalletService _mwaWalletService;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final StreamController<NotificationTapPayload> _tapController =
      StreamController<NotificationTapPayload>.broadcast();

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  StreamSubscription<String>? _tokenRefreshSub;

  bool _initialized = false;
  NotificationTapPayload? _pendingTap;
  String? _walletAddress;
  String? _userEmail;

  RemoteNotificationService({
    required LoggerService logger,
    required NotificationService notificationService,
    required PrivyWalletManager privyWalletManager,
    required MwaWalletService mwaWalletService,
  }) : _logger = logger,
       _notificationService = notificationService,
       _privyWalletManager = privyWalletManager,
       _mwaWalletService = mwaWalletService;

  Stream<NotificationTapPayload> get tapPayloads => _tapController.stream;

  NotificationTapPayload? consumePendingTap() {
    final payload = _pendingTap;
    _pendingTap = null;
    return payload;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (error) {
      _logger.warning(
        'Unable to set foreground notification presentation: $error',
        tag: 'RemoteNotifications',
      );
    }

    _foregroundSub = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
    );
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((_) {
      final walletAddress = _walletAddress;
      if (walletAddress == null) return;
      unawaited(
        syncCurrentDevice(
          walletAddress: walletAddress,
          email: _userEmail,
          force: true,
        ),
      );
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _pendingTap = _parseTapPayload(initialMessage);
    }

    _initialized = true;
    _logger.info('Remote notification runtime ready', tag: 'RemoteNotifications');
  }

  Future<bool> syncCurrentDevice({
    required String walletAddress,
    String? email,
    bool force = false,
  }) async {
    _walletAddress = walletAddress;
    _userEmail = email;

    if (!AppConstants.hasSupabaseConfig) {
      _logger.warning(
        'Supabase config missing; skipping device registration',
        tag: 'RemoteNotifications',
      );
      return false;
    }

    final notificationsEnabled =
        await _notificationService.areNotificationsEnabled;
    if (!notificationsEnabled) {
      _logger.info(
        'OS notifications disabled; skipping device registration',
        tag: 'RemoteNotifications',
      );
      return false;
    }

    final deviceToken = await _messaging.getToken();
    if (deviceToken == null || deviceToken.isEmpty) {
      _logger.warning(
        'FCM token unavailable; device registration deferred',
        tag: 'RemoteNotifications',
      );
      return false;
    }

    final installationId = await _getInstallationId();
    final syncKey = '$_deviceSyncPrefix$walletAddress';
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (!force) {
      final cached = StorageService.getJson(syncKey);
      final syncedAt = cached?['syncedAt'] as int? ?? 0;
      final cachedToken = cached?['deviceToken'] as String?;
      final cachedInstallation = cached?['installationId'] as String?;
      final recentlySynced = nowMs - syncedAt < const Duration(hours: 6).inMilliseconds;

      if (recentlySynced &&
          cachedToken == deviceToken &&
          cachedInstallation == installationId) {
        return true;
      }
    }

    final payload = <String, dynamic>{
      'walletAddress': walletAddress,
      'email': email,
      'deviceToken': deviceToken,
      'installationId': installationId,
      'platform': _platformLabel,
      'appVersion': AppConstants.appVersion,
      'locale': Platform.localeName,
      'timestampMs': nowMs,
    };
    final signingMessage = _buildRegistrationMessage(payload);
    final signatureBase64 = await _signWalletMessage(
      walletAddress: walletAddress,
      message: signingMessage,
    );

    if (signatureBase64 == null || signatureBase64.isEmpty) {
      _logger.warning(
        'Wallet signature unavailable; device registration skipped',
        tag: 'RemoteNotifications',
      );
      return false;
    }

    try {
      await Supabase.instance.client.functions.invoke(
        AppConstants.supabaseRegisterDeviceFunction,
        body: {
          ...payload,
          'message': signingMessage,
          'signatureBase64': signatureBase64,
        },
      );

      await StorageService.saveJson(syncKey, {
        'deviceToken': deviceToken,
        'installationId': installationId,
        'syncedAt': nowMs,
      });

      _logger.info(
        'Notification device synced for $walletAddress',
        tag: 'RemoteNotifications',
      );
      return true;
    } catch (error, stackTrace) {
      _logger.error(
        'Notification device sync failed',
        error: error,
        stackTrace: stackTrace,
        tag: 'RemoteNotifications',
      );
      return false;
    }
  }

  Future<bool> recordClientEvent({
    required String walletAddress,
    required String eventId,
    required String eventType,
    required AppNotifCategory category,
    required String title,
    required String body,
    String? symbol,
    List<String> channels = const ['push', 'email'],
    Map<String, dynamic> payload = const {},
  }) async {
    if (!AppConstants.hasSupabaseConfig) {
      return false;
    }

    final normalizedChannels = _normalizeChannels(channels);
    if (normalizedChannels.isEmpty) {
      return false;
    }

    final requestPayload = <String, dynamic>{
      'walletAddress': walletAddress,
      'eventId': eventId,
      'eventType': eventType,
      'category': _categoryLabel(category),
      'title': title,
      'body': body,
      'symbol': symbol,
      'channels': normalizedChannels,
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
    };

    final signingMessage = _buildClientEventMessage(requestPayload);
    final signatureBase64 = await _signWalletMessage(
      walletAddress: walletAddress,
      message: signingMessage,
    );

    if (signatureBase64 == null || signatureBase64.isEmpty) {
      _logger.warning(
        'Wallet signature unavailable; client event skipped',
        tag: 'RemoteNotifications',
      );
      return false;
    }

    try {
      await Supabase.instance.client.functions.invoke(
        AppConstants.supabaseRecordClientEventFunction,
        body: {
          ...requestPayload,
          'payload': payload,
          'message': signingMessage,
          'signatureBase64': signatureBase64,
        },
      );
      return true;
    } catch (error, stackTrace) {
      _logger.error(
        'Client notification event sync failed',
        error: error,
        stackTrace: stackTrace,
        tag: 'RemoteNotifications',
      );
      return false;
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? _stringOrNull(message.data['title']);
    final body = message.notification?.body ?? _stringOrNull(message.data['body']);
    if (title == null || body == null) return;

    await _notificationService.showGenericNotification(
      category: _parseCategory(_stringOrNull(message.data['category'])),
      title: title,
      body: body,
      payload: _stringOrNull(message.data['symbol']) ??
          _stringOrNull(message.data['payload']),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final payload = _parseTapPayload(message);
    if (payload != null) {
      _tapController.add(payload);
    }
  }

  NotificationTapPayload? _parseTapPayload(RemoteMessage message) {
    if (message.data.isEmpty && message.notification == null) return null;

    return NotificationTapPayload(
      symbol: _stringOrNull(message.data['symbol']) ??
          _stringOrNull(message.data['payload']),
      route: _stringOrNull(message.data['route']),
      eventId: _stringOrNull(message.data['event_id']),
    );
  }

  String _buildRegistrationMessage(Map<String, dynamic> payload) {
    return [
      'dream-notify/register-device',
      'wallet:${payload['walletAddress']}',
      'token:${payload['deviceToken']}',
      'installation:${payload['installationId']}',
      'platform:${payload['platform']}',
      'appVersion:${payload['appVersion']}',
      'locale:${payload['locale']}',
      'email:${payload['email'] ?? ''}',
      'timestampMs:${payload['timestampMs']}',
    ].join('\n');
  }

  String _buildClientEventMessage(Map<String, dynamic> payload) {
    return [
      'dream-notify/record-event',
      'wallet:${payload['walletAddress']}',
      'eventId:${payload['eventId']}',
      'eventType:${payload['eventType']}',
      'category:${payload['category']}',
      'symbol:${_sanitizeSignedField(payload['symbol']?.toString())}',
      'title:${_sanitizeSignedField(payload['title']?.toString())}',
      'body:${_sanitizeSignedField(payload['body']?.toString())}',
      'channels:${(payload['channels'] as List<dynamic>).join(',')}',
      'timestampMs:${payload['timestampMs']}',
    ].join('\n');
  }

  Future<String?> _signWalletMessage({
    required String walletAddress,
    required String message,
  }) async {
    if (_mwaWalletService.connectedPublicKey == walletAddress) {
      final result = await _mwaWalletService.signMessage(message);
      if (!result.success || result.signature == null) {
        return null;
      }
      return base64Encode(result.signature!);
    }

    final wallet = await _privyWalletManager.getOrCreateWallet();
    if (wallet == null || wallet.address != walletAddress) {
      return null;
    }
    return _privyWalletManager.signMessage(wallet, message);
  }

  List<String> _normalizeChannels(List<String> channels) {
    final normalized = channels
        .map((channel) => channel.trim().toLowerCase())
        .where((channel) => channel == 'push' || channel == 'email')
        .toSet()
        .toList()
      ..sort();
    return normalized;
  }

  String _categoryLabel(AppNotifCategory category) => switch (category) {
    AppNotifCategory.trade => 'trade',
    AppNotifCategory.alert => 'alert',
    AppNotifCategory.risk => 'risk',
    AppNotifCategory.system => 'system',
    AppNotifCategory.marketing => 'marketing',
    AppNotifCategory.intelligence => 'intelligence',
  };

  String _sanitizeSignedField(String? value) =>
      value?.replaceAll('\n', ' ').trim() ?? '';

  Future<String> _getInstallationId() async {
    final existing = StorageService.getString(_installationIdKey);
    if (existing.isNotEmpty) return existing;

    final random = Random.secure();
    final seed =
        '${DateTime.now().microsecondsSinceEpoch}-${Platform.operatingSystem}-${random.nextInt(1 << 32)}-${random.nextInt(1 << 32)}';
    final installationId = sha256.convert(utf8.encode(seed)).toString();
    await StorageService.setString(_installationIdKey, installationId);
    return installationId;
  }

  AppNotifCategory _parseCategory(String? raw) {
    return switch (raw) {
      'trade' => AppNotifCategory.trade,
      'alert' => AppNotifCategory.alert,
      'risk' => AppNotifCategory.risk,
      'marketing' => AppNotifCategory.marketing,
      'intelligence' => AppNotifCategory.intelligence,
      _ => AppNotifCategory.system,
    };
  }

  String get _platformLabel => switch (Platform.operatingSystem) {
    'android' => 'android',
    'ios' => 'ios',
    _ => 'unknown',
  };

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  void dispose() {
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
    _tokenRefreshSub?.cancel();
    _tapController.close();
  }
}