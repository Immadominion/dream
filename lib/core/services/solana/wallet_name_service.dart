import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../constants/app_constants.dart';
import '../logger_service.dart';

/// Resolves Solana wallet addresses to human-readable domain names.
///
/// Queries the Helius Names API which covers all major Solana TLDs:
/// - `.skr` (Seeker identity)
/// - `.sol` (Bonfida SNS)
/// - `.abc`, `.bonk`, `.backpack`, `.poor`, etc.
class WalletNameService {
  static final _logger = LoggerService();

  /// TLD priority order — .skr (Seeker) is shown first for Dream's audience.
  static const _tldPriority = ['.skr', '.sol', '.abc', '.bonk', '.backpack'];

  /// Resolves [walletAddress] to its best available domain name.
  ///
  /// Returns the domain string (e.g. `"benji.skr"`) or `null` when:
  /// - No domains are registered to this wallet
  /// - Helius API key is not configured
  /// - Network request fails or times out
  static Future<String?> resolveWalletName(String walletAddress) async {
    if (walletAddress.isEmpty) return null;

    final apiKey = AppConstants.heliusApiKey;
    if (apiKey.isEmpty) {
      _logger.warning(
        'Helius API key not set — SNS lookup skipped',
        tag: '[WalletName]',
      );
      return null;
    }

    try {
      final uri = Uri.parse(
        '${AppConstants.heliusApiUrl}/names'
        '?api-key=$apiKey'
        '&address=$walletAddress',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        _logger.warning(
          'SNS lookup returned ${response.statusCode}',
          tag: '[WalletName]',
        );
        return null;
      }

      final dynamic decoded = json.decode(response.body);
      if (decoded is! List || decoded.isEmpty) return null;

      final names = decoded.cast<String>();
      final best = _pickBestName(names);
      _logger.info('Resolved $walletAddress → $best', tag: '[WalletName]');
      return best;
    } catch (e) {
      _logger.error('SNS resolution error: $e', tag: '[WalletName]');
      return null;
    }
  }

  /// Picks the highest-priority name from [names] using [_tldPriority].
  static String _pickBestName(List<String> names) {
    for (final tld in _tldPriority) {
      final match = names.firstWhere((n) => n.endsWith(tld), orElse: () => '');
      if (match.isNotEmpty) return match;
    }
    return names.first;
  }
}
