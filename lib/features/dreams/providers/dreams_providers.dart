import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth/client_auth_provider.dart';
import '../../../core/services/analytics/product_analytics.dart';
import '../../../core/services/solana/server_transaction_signer.dart';
import '../../../core/services/solana/solana_transaction_service.dart';
import '../../../core/services/solana/usdc_transfer_service.dart';
import '../../../shared/services/storage_service.dart';
import '../models/dream_models.dart';
import '../services/dream_api_service.dart';

// ── Feed ─────────────────────────────────────────────────────────────────────

class DreamsFeedState {
  final DreamSort sort;
  final DreamCategory? category;
  final List<Dream> dreams;
  final int? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final bool coinLaunchesEnabled;
  final String? error;

  const DreamsFeedState({
    this.sort = DreamSort.latest,
    this.category,
    this.dreams = const [],
    this.nextCursor,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.coinLaunchesEnabled = false,
    this.error,
  });

  bool get hasMore => nextCursor != null;

  DreamsFeedState copyWith({
    DreamSort? sort,
    DreamCategory? Function()? category,
    List<Dream>? dreams,
    int? Function()? nextCursor,
    bool? isLoading,
    bool? isLoadingMore,
    bool? coinLaunchesEnabled,
    String? Function()? error,
  }) {
    return DreamsFeedState(
      sort: sort ?? this.sort,
      category: category != null ? category() : this.category,
      dreams: dreams ?? this.dreams,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      coinLaunchesEnabled: coinLaunchesEnabled ?? this.coinLaunchesEnabled,
      error: error != null ? error() : this.error,
    );
  }
}

class DreamsFeedNotifier extends Notifier<DreamsFeedState> {
  /// Monotonic token so a slow response for an old filter can't overwrite a
  /// newer one.
  int _generation = 0;

  @override
  DreamsFeedState build() {
    Future.microtask(refresh);
    return const DreamsFeedState();
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    state = state.copyWith(isLoading: true, error: () => null);
    try {
      final page = await ref
          .read(dreamApiServiceProvider)
          .listDreams(sort: state.sort, category: state.category);
      if (gen != _generation) return;
      state = state.copyWith(
        dreams: page.dreams,
        nextCursor: () => page.nextCursor,
        coinLaunchesEnabled: page.coinLaunchesEnabled,
        isLoading: false,
      );
    } on DreamApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(isLoading: false, error: () => e.message);
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore || state.isLoading) return;
    final gen = _generation;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await ref
          .read(dreamApiServiceProvider)
          .listDreams(
            sort: state.sort,
            category: state.category,
            cursor: cursor,
          );
      if (gen != _generation) return;
      final seen = state.dreams.map((d) => d.id).toSet();
      state = state.copyWith(
        dreams: [...state.dreams, ...page.dreams.where((d) => seen.add(d.id))],
        nextCursor: () => page.nextCursor,
        isLoadingMore: false,
      );
    } on DreamApiException {
      if (gen != _generation) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setSort(DreamSort sort) {
    if (sort == state.sort) return;
    unawaited(ProductAnalytics.dreamsFeedViewed(sort.apiValue));
    state = state.copyWith(sort: sort);
    refresh();
  }

  void setCategory(DreamCategory? category) {
    if (category == state.category) return;
    state = state.copyWith(category: () => category);
    refresh();
  }

  /// Insert or replace a dream after a local action (create/fund/launch).
  void upsert(Dream dream) {
    final i = state.dreams.indexWhere((d) => d.id == dream.id);
    final next = [...state.dreams];
    if (i >= 0) {
      next[i] = dream;
    } else {
      next.insert(0, dream);
    }
    state = state.copyWith(dreams: next);
  }
}

final dreamsFeedProvider =
    NotifierProvider<DreamsFeedNotifier, DreamsFeedState>(
      DreamsFeedNotifier.new,
    );

// ── Detail ───────────────────────────────────────────────────────────────────

final dreamDetailProvider = FutureProvider.autoDispose
    .family<DreamDetail, String>((ref, id) {
      return ref.watch(dreamApiServiceProvider).getDream(id);
    });

/// The signed-in user's own dreams (any status).
final myDreamsProvider = FutureProvider.autoDispose<List<Dream>>((ref) async {
  final wallet = ref.watch(clientAuthProvider).walletAddress;
  if (wallet == null) return const [];
  return ref.watch(dreamApiServiceProvider).myDreams(wallet);
});

/// Raw token balance (base units) of [mint] held by the signed-in wallet.
final coinBalanceProvider = FutureProvider.autoDispose.family<BigInt, String>((
  ref,
  mint,
) async {
  final wallet = ref.watch(clientAuthProvider).walletAddress;
  if (wallet == null) return BigInt.zero;
  final resp = await Dio().post<Map<String, dynamic>>(
    AppConstants.heliusRpcUrl,
    data: {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'getTokenAccountsByOwner',
      'params': [
        wallet,
        {'mint': mint},
        {'encoding': 'jsonParsed'},
      ],
    },
  );
  final accounts = (resp.data?['result']?['value'] as List?) ?? const [];
  var total = BigInt.zero;
  for (final a in accounts) {
    final amount =
        a['account']?['data']?['parsed']?['info']?['tokenAmount']?['amount'];
    if (amount is String) total += BigInt.tryParse(amount) ?? BigInt.zero;
  }
  return total;
});

final usdcBalanceProvider = FutureProvider.autoDispose<double>((ref) async {
  final wallet = ref.watch(clientAuthProvider).walletAddress;
  if (wallet == null) return 0;
  return ref.watch(solanaTransactionServiceProvider).getUsdcBalance(wallet);
});

final solBalanceProvider = FutureProvider.autoDispose<double>((ref) async {
  final wallet = ref.watch(clientAuthProvider).walletAddress;
  if (wallet == null) return 0;
  return ref.watch(solanaTransactionServiceProvider).getSolBalance(wallet);
});

// ── Actions ──────────────────────────────────────────────────────────────────

class DreamActionException implements Exception {
  final String message;
  const DreamActionException(this.message);
  @override
  String toString() => message;
}

/// A built (but not yet signed) swap, shown to the user before they confirm.
class SwapQuote {
  final Dream dream;
  final bool buy;
  final BigInt amountIn;
  final BigInt expectedOut;
  final BigInt minimumOut;
  final int slippageBps;
  final ServerBuiltTx tx;

  const SwapQuote({
    required this.dream,
    required this.buy,
    required this.amountIn,
    required this.expectedOut,
    required this.minimumOut,
    required this.slippageBps,
    required this.tx,
  });
}

/// Every money-moving action on a dream. The server builds or verifies; the
/// app checks every server-built transaction against what the user asked for
/// before the wallet signs; funds never pass through Dream.
class DreamActions {
  final Ref _ref;
  DreamActions(this._ref);

  static const _pendingKey = 'dreams.pending_contributions.v1';
  static const defaultSlippageBps = 100;

  DreamApiService get _api => _ref.read(dreamApiServiceProvider);
  ServerTransactionSigner get _signer =>
      _ref.read(serverTransactionSignerProvider);

  String get _wallet {
    final wallet = _ref.read(clientAuthProvider).walletAddress;
    if (wallet == null || wallet.isEmpty) {
      throw const DreamActionException('Sign in to continue');
    }
    return wallet;
  }

  void _refresh(Dream dream) {
    _ref.read(dreamsFeedProvider.notifier).upsert(dream);
    _ref.invalidate(dreamDetailProvider(dream.id));
    _ref.invalidate(myDreamsProvider);
  }

  Future<Dream> create({
    required String title,
    required String story,
    required DreamCategory category,
    required String goalUsdc,
  }) async {
    final dream = await _api.createDream(
      wallet: _wallet,
      title: title,
      story: story,
      category: category,
      goalUsdc: goalUsdc,
    );
    unawaited(
      ProductAnalytics.dreamCreated(
        category: category.name,
        goalUsd: double.tryParse(goalUsdc) ?? 0,
      ),
    );
    _refresh(dream);
    return dream;
  }

  /// Link (and verify) the owner's X post.
  Future<Dream> linkX(Dream dream, String url) async {
    final updated = await _api.linkXPost(
      wallet: _wallet,
      id: dream.id,
      url: url,
    );
    unawaited(ProductAnalytics.xVerified());
    _refresh(updated);
    return updated;
  }

  /// Send USDC straight to the dream owner's wallet, then have the server
  /// verify the transfer on-chain and credit the dream. The tx signature is
  /// persisted until the server records it, so a crash or network drop after
  /// the transfer never loses the supporter's credit.
  Future<Dream> fund(Dream dream, double amountUsdc) async {
    final wallet = _wallet;
    if (wallet == dream.ownerWallet) {
      throw const DreamActionException("You can't fund your own dream");
    }
    final result = await _ref
        .read(usdcTransferServiceProvider)
        .sendUsdc(
          fromOwner: wallet,
          toOwner: dream.ownerWallet,
          amountUsdc: amountUsdc,
        );
    if (!result.success || result.signature == null) {
      unawaited(ProductAnalytics.dreamFundFailed('transfer'));
      throw DreamActionException(result.error ?? 'Transfer failed');
    }
    unawaited(ProductAnalytics.dreamFunded(amountUsdc));
    await _savePending(dream.id, result.signature!, wallet);
    _ref.invalidate(usdcBalanceProvider);
    try {
      final updated = await _api.recordContribution(
        wallet: wallet,
        id: dream.id,
        txSignature: result.signature!,
      );
      await _clearPending(result.signature!);
      _refresh(updated);
      return updated;
    } on DreamApiException catch (e) {
      if (!e.isNotYetVisible) await _clearPending(result.signature!);
      unawaited(ProductAnalytics.dreamFundFailed('record'));
      throw DreamActionException(
        e.isNotYetVisible
            ? 'Your USDC was sent. We’ll finish recording it when the network catches up.'
            : 'Your USDC was sent, but it couldn’t be counted: ${e.message}',
      );
    }
  }

  /// Retry recording contributions whose transfer landed but whose record
  /// call didn't finish (app killed, offline, RPC lag).
  Future<void> retryPendingContributions() async {
    final wallet = _ref.read(clientAuthProvider).walletAddress;
    if (wallet == null) return;
    for (final p in _loadPending().where((p) => p.wallet == wallet)) {
      try {
        final updated = await _api.recordContribution(
          wallet: wallet,
          id: p.dreamId,
          txSignature: p.signature,
        );
        await _clearPending(p.signature);
        _refresh(updated);
      } on DreamApiException catch (e) {
        if (!e.isNotYetVisible) await _clearPending(p.signature);
      } catch (_) {
        // Keep it for the next attempt.
      }
    }
  }

  Future<Dream> launchCoin(
    Dream dream, {
    required String name,
    required String symbol,
  }) async {
    final wallet = _wallet;
    final built = await _api.prepareCoin(
      wallet: wallet,
      id: dream.id,
      name: name,
      symbol: symbol,
    );
    final mint = built.mint;
    final pool = built.pool;
    if (mint == null || pool == null) {
      throw const DreamActionException('Server returned an incomplete launch');
    }
    final sig = await _signer.signAndSend(
      transactionBase64: built.transaction,
      walletAddress: wallet,
      intent: LaunchCoinIntent(mint: mint, pool: pool),
    );
    final updated = await _api.confirmCoin(
      wallet: wallet,
      id: dream.id,
      mint: mint,
      txSignature: sig,
    );
    unawaited(ProductAnalytics.coinLaunched());
    _ref.invalidate(solBalanceProvider);
    _refresh(updated);
    return updated;
  }

  /// Build a swap and return its quote for the user to review. Nothing is
  /// signed yet. [amountIn] is lamports for a buy, raw coin units for a sell.
  Future<SwapQuote> quoteSwap(
    Dream dream, {
    required bool buy,
    required BigInt amountIn,
    int slippageBps = defaultSlippageBps,
  }) async {
    if (dream.coin == null) throw const DreamActionException('No coin');
    final built = await _api.buildSwap(
      wallet: _wallet,
      id: dream.id,
      buy: buy,
      amountIn: amountIn,
      slippageBps: slippageBps,
    );
    final expected = BigInt.tryParse(built.expectedOut ?? '');
    final minimum = BigInt.tryParse(built.minimumOut ?? '');
    if (expected == null || minimum == null || minimum <= BigInt.zero) {
      throw const DreamActionException('Couldn’t get a price — try again');
    }
    // The server's minimum must honour the slippage the user chose.
    final floor =
        expected * BigInt.from(10000 - slippageBps) ~/ BigInt.from(10000);
    if (minimum < floor || minimum > expected) {
      throw const DreamActionException('Price check failed — try again');
    }
    return SwapQuote(
      dream: dream,
      buy: buy,
      amountIn: amountIn,
      expectedOut: expected,
      minimumOut: minimum,
      slippageBps: slippageBps,
      tx: built,
    );
  }

  /// Sign and submit a quote the user approved.
  Future<String> executeSwap(SwapQuote quote) async {
    final coin = quote.dream.coin!;
    final sig = await _signer.signAndSend(
      transactionBase64: quote.tx.transaction,
      walletAddress: _wallet,
      intent: SwapCoinIntent(
        pool: coin.pool,
        mint: coin.mint,
        isBuy: quote.buy,
        amountIn: quote.amountIn,
        minimumOut: quote.minimumOut,
      ),
    );
    unawaited(ProductAnalytics.coinTraded(buy: quote.buy));
    _ref.invalidate(solBalanceProvider);
    _ref.invalidate(coinBalanceProvider(coin.mint));
    _ref.invalidate(dreamDetailProvider(quote.dream.id));
    return sig;
  }

  Future<String> claimFees(Dream dream) async {
    final coin = dream.coin;
    if (coin == null) throw const DreamActionException('No coin');
    final wallet = _wallet;
    final built = await _api.buildClaim(wallet: wallet, id: dream.id);
    final sig = await _signer.signAndSend(
      transactionBase64: built.transaction,
      walletAddress: wallet,
      intent: ClaimFeesIntent(pool: coin.pool, mint: coin.mint),
    );
    unawaited(ProductAnalytics.coinFeesClaimed());
    _ref.invalidate(solBalanceProvider);
    _ref.invalidate(dreamDetailProvider(dream.id));
    return sig;
  }

  Future<void> close(Dream dream) async {
    final updated = await _api.closeDream(wallet: _wallet, id: dream.id);
    _refresh(updated);
    await _ref.read(dreamsFeedProvider.notifier).refresh();
  }

  Future<void> report(Dream dream, String reason) async {
    await _api.report(wallet: _wallet, id: dream.id, reason: reason);
    unawaited(ProductAnalytics.dreamReported(reason));
  }

  // ── Pending contribution store ────────────────────────────────────────────

  List<_PendingContribution> _loadPending() {
    try {
      final raw = StorageService.getString(_pendingKey);
      if (raw.isEmpty) return [];
      return (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(_PendingContribution.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePending(String dreamId, String sig, String wallet) async {
    final list = _loadPending()
      ..add(
        _PendingContribution(dreamId: dreamId, signature: sig, wallet: wallet),
      );
    await StorageService.setString(
      _pendingKey,
      jsonEncode(list.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> _clearPending(String sig) async {
    final list = _loadPending()..removeWhere((p) => p.signature == sig);
    await StorageService.setString(
      _pendingKey,
      jsonEncode(list.map((p) => p.toJson()).toList()),
    );
  }
}

class _PendingContribution {
  final String dreamId;
  final String signature;
  final String wallet;
  const _PendingContribution({
    required this.dreamId,
    required this.signature,
    required this.wallet,
  });

  factory _PendingContribution.fromJson(Map<String, dynamic> j) =>
      _PendingContribution(
        dreamId: j['dreamId'] as String,
        signature: j['signature'] as String,
        wallet: j['wallet'] as String,
      );

  Map<String, dynamic> toJson() => {
    'dreamId': dreamId,
    'signature': signature,
    'wallet': wallet,
  };
}

final dreamActionsProvider = Provider<DreamActions>(DreamActions.new);
