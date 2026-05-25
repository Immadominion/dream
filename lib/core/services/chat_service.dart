import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'logger_service.dart';

class ChatService {
  static String get tawkUrl =>
      dotenv.env['TAWK_TO_URL'] ??
      'https://tawk.to/chat/68c3692a2d363c192cbaaea5/1j4tl5k2i';

  /// Opens Tawk.to chat in in-app webview / browser
  static Future<void> openChat(BuildContext context) async {
    final logger = LoggerService();
    try {
      logger.info('Opening Tawk.to chat in browser', tag: '[Support]');
      final Uri chatUrl = Uri.parse(tawkUrl);

      if (await canLaunchUrl(chatUrl)) {
        await launchUrl(chatUrl, mode: LaunchMode.externalApplication);
        logger.info('Opened chat successfully', tag: '[Support]');
      } else {
        logger.error('Could not launch chat URL: $tawkUrl', tag: '[Support]');
      }
    } catch (e) {
      logger.error('Failed to open chat: $e', tag: '[Support]');
    }
  }

  /// Opens chat with a pre-filled message
  static Future<void> openChatWithMessage(String message) async {
    final logger = LoggerService();
    try {
      final encodedMessage = Uri.encodeComponent(message);
      final chatUrlWithMessage = '$tawkUrl?message=$encodedMessage';
      final Uri chatUrl = Uri.parse(chatUrlWithMessage);

      if (await canLaunchUrl(chatUrl)) {
        await launchUrl(chatUrl, mode: LaunchMode.externalApplication);
        logger.info('Opened Tawk.to chat with message', tag: '[Support]');
      } else {
        logger.error(
          'Could not launch chat URL: $chatUrlWithMessage',
          tag: '[Support]',
        );
      }
    } catch (e) {
      logger.error('Failed to open chat with message: $e', tag: '[Support]');
    }
  }
}
