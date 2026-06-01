import 'package:solana/solana.dart';
import 'package:tld_parser/tld_parser.dart';

import '../../constants/app_constants.dart';
import '../logger_service.dart';

/// Resolves Solana wallet addresses to human-readable domain names via the
/// AllDomains ANS Protocol (`tld_parser`), querying the chain directly.
///
/// Supported TLDs: `.skr`, `.sol`, `.abc`, `.bonk`, `.backpack`, `.poor`, etc.
class WalletNameService {
  static final _logger = LoggerService();

  /// TLD priority order — .skr (Seeker) shown first for Dream's audience.
  static const _tldPriority = ['.skr', '.sol', '.abc', '.bonk', '.backpack'];

  static TldParser? _parser;

  static TldParser _getParser() {
    _parser ??= TldParser(RpcClient(AppConstants.heliusRpcUrl));
    return _parser!;
  }

  /// Resolves [walletAddress] to its best available domain name via AllDomains.
  ///
  /// Returns the domain string (e.g. `"benji.skr"`) or `null` when:
  /// - No domains are registered to this wallet
  /// - The RPC call fails or times out
  static Future<String?> resolveWalletName(String walletAddress) async {
    if (walletAddress.isEmpty) return null;

    try {
      final pubkey = Ed25519HDPublicKey.fromBase58(walletAddress);
      final parser = _getParser();

      // Prefer the user's explicitly set primary domain.
      final mainDomain = await parser.tryGetMainDomain(pubkey);
      if (mainDomain != null) {
        _logger.info(
          'Resolved $walletAddress → ${mainDomain.fullDomain} (main domain)',
          tag: '[WalletName]',
        );
        return mainDomain.fullDomain;
      }

      // Fall back to searching per-TLD in priority order.
      for (final tld in _tldPriority) {
        final tldName = tld.substring(1); // strip leading dot
        try {
          final domains = await parser.getParsedAllUserDomainsFromTld(
            pubkey,
            tldName,
          );
          if (domains.isNotEmpty) {
            final name = domains.first.domain;
            _logger.info(
              'Resolved $walletAddress → $name (tld=$tld fallback)',
              tag: '[WalletName]',
            );
            return name;
          }
        } catch (_) {
          // TLD lookup failed — try next priority
        }
      }

      _logger.info(
        'No AllDomains name found for $walletAddress',
        tag: '[WalletName]',
      );
      return null;
    } catch (e) {
      _logger.error('AllDomains resolution error: $e', tag: '[WalletName]');
      return null;
    }
  }
}
