import 'dart:typed_data';

import 'package:solana/solana.dart'
    show Ed25519HDPublicKey, findAssociatedTokenAddress;

import 'wire_transaction.dart';

/// What the user asked for — the guard only accepts a transaction that does
/// exactly this and nothing else.
sealed class ServerTxIntent {
  const ServerTxIntent();
}

class LaunchCoinIntent extends ServerTxIntent {
  final String mint;
  final String pool;
  const LaunchCoinIntent({required this.mint, required this.pool});
}

class SwapCoinIntent extends ServerTxIntent {
  final String pool;
  final String mint;
  final bool isBuy;

  /// Exact input the user typed (lamports for a buy, coin units for a sell).
  final BigInt amountIn;

  /// The minimum output the user was shown and accepted.
  final BigInt minimumOut;

  const SwapCoinIntent({
    required this.pool,
    required this.mint,
    required this.isBuy,
    required this.amountIn,
    required this.minimumOut,
  });
}

class ClaimFeesIntent extends ServerTxIntent {
  final String pool;
  final String mint;
  const ClaimFeesIntent({required this.pool, required this.mint});
}

class UnsafeTransactionException implements Exception {
  final String reason;
  const UnsafeTransactionException(this.reason);
  @override
  String toString() =>
      'Blocked an unexpected transaction from the server ($reason). Nothing was signed.';
}

/// Client-side allowlist for transactions built by dream-server.
///
/// The app must never blind-sign: a compromised server, a hijacked API URL or
/// a TLS MITM could otherwise return "Buy 0.1 SOL" that is really "send
/// everything to the attacker". Every instruction must be one of the exact
/// shapes the Dreams flows produce (derived from the real Meteora SDK output,
/// captured in test/fixtures by dream-server/scripts/make-signer-fixture.ts):
///
///   ComputeBudget  limit / price, capped
///   DBC program    exactly one: create-pool | swap2 | claim-creator-fee,
///                  referencing the expected pool (and mint)
///   ATA program    create (idempotent) — payer and owner are the user
///   System         transfer user → user's own WSOL account (wrap)
///   Token program  SyncNative on the user's WSOL account;
///                  CloseAccount whose destination & authority are the user
///
/// Anything else — another program, a transfer to someone else, a different
/// fee payer, lookup tables — is rejected before the wallet is asked to sign.
abstract final class ServerTxGuard {
  static const computeBudgetProgram =
      'ComputeBudget111111111111111111111111111111';
  static const dbcProgram = 'dbcij3LWUppWqq96dh6gJWwBifmcGfLSB5D4DuSMaqN';
  static const ataProgram = 'ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL';
  static const systemProgram = '11111111111111111111111111111111';
  static const tokenProgram = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
  static const wsolMint = 'So11111111111111111111111111111111111111112';

  // Anchor discriminators (sha256("global:<ix>")[..8]) of the DBC
  // instructions the Dreams flows use.
  static const _createPool = [0x8c, 0x55, 0xd7, 0xb0, 0x66, 0x36, 0x68, 0x4f];
  static const _swap2 = [0x41, 0x4b, 0x3f, 0x4c, 0xeb, 0x5b, 0x5b, 0x88];
  static const _claimCreatorFee = [
    0x52, 0xdc, 0xfa, 0xbd, 0x03, 0x55, 0x6b, 0x2d, //
  ];

  /// Max compute-unit limit and total priority fee the user will pay.
  static const maxComputeUnits = 1400000;
  static const maxPriorityFeeLamports = 10000000; // 0.01 SOL

  static Future<void> check(
    WireTransaction tx, {
    required String wallet,
    required ServerTxIntent intent,
  }) async {
    if (tx.usesLookupTables || tx.isVersioned) {
      throw const UnsafeTransactionException('unsupported transaction format');
    }
    if (tx.feePayer != wallet) {
      throw const UnsafeTransactionException('fee payer is not your wallet');
    }
    final expectedSigners = switch (intent) {
      LaunchCoinIntent(:final mint) => [wallet, mint],
      _ => [wallet],
    };
    if (tx.signers.length != expectedSigners.length ||
        !_sameElements(tx.signers, expectedSigners)) {
      throw const UnsafeTransactionException('unexpected signers');
    }

    final wsolAta = await _ata(wallet, wsolMint);
    final allowedAtaMints = {wsolMint, intent.mintOf};

    var computeLimit = 200000;
    var computePrice = 0;
    var dbcCalls = 0;
    var wrappedLamports = BigInt.zero;

    for (final ix in tx.instructions) {
      final d = ix.data;
      switch (ix.programId) {
        case computeBudgetProgram:
          if (d.length == 5 && d[0] == 2) {
            computeLimit = _u32(d, 1);
            if (computeLimit > maxComputeUnits) {
              throw const UnsafeTransactionException('compute limit too high');
            }
          } else if (d.length == 9 && d[0] == 3) {
            computePrice = _u64Big(d, 1) > BigInt.from(1 << 40)
                ? 1 << 40
                : _u64(d, 1);
          } else {
            throw const UnsafeTransactionException('unknown compute-budget op');
          }

        case dbcProgram:
          dbcCalls++;
          _checkDbc(ix, wallet: wallet, intent: intent);

        case ataProgram:
          // [payer, ata, owner, mint, system, token]
          final createOk = d.isEmpty || (d.length == 1 && d[0] == 1);
          if (!createOk ||
              ix.accounts.length < 4 ||
              ix.accounts[0] != wallet ||
              ix.accounts[2] != wallet ||
              !allowedAtaMints.contains(ix.accounts[3])) {
            throw const UnsafeTransactionException(
              'token account not owned by you',
            );
          }

        case systemProgram:
          // Only wrapping SOL into the user's own WSOL account.
          final isTransfer =
              d.length == 12 &&
              d[0] == 2 &&
              d[1] == 0 &&
              d[2] == 0 &&
              d[3] == 0;
          if (!isTransfer ||
              ix.accounts.length != 2 ||
              ix.accounts[0] != wallet ||
              ix.accounts[1] != wsolAta) {
            throw const UnsafeTransactionException(
              'SOL transfer to an account that is not yours',
            );
          }
          wrappedLamports += _u64Big(d, 4);

        case tokenProgram:
          if (d.length == 1 && d[0] == 17) {
            // SyncNative
            if (ix.accounts.length != 1 || ix.accounts[0] != wsolAta) {
              throw const UnsafeTransactionException('unexpected token op');
            }
          } else if (d.length == 1 && d[0] == 9) {
            // CloseAccount [account, destination, authority]
            if (ix.accounts.length < 3 ||
                ix.accounts[0] != wsolAta ||
                ix.accounts[1] != wallet ||
                ix.accounts[2] != wallet) {
              throw const UnsafeTransactionException(
                'closes an account to someone else',
              );
            }
          } else {
            throw const UnsafeTransactionException('unexpected token op');
          }

        default:
          throw UnsafeTransactionException('unknown program ${ix.programId}');
      }
    }

    if (dbcCalls != 1) {
      throw const UnsafeTransactionException(
        'expected exactly one coin action',
      );
    }
    // Only a buy may wrap SOL, and never more than the user typed.
    final maxWrap = intent is SwapCoinIntent && intent.isBuy
        ? intent.amountIn
        : BigInt.zero;
    if (wrappedLamports > maxWrap) {
      throw const UnsafeTransactionException(
        'spends more SOL than you entered',
      );
    }
    final priorityLamports = computeLimit * computePrice ~/ 1000000;
    if (priorityLamports > maxPriorityFeeLamports) {
      throw const UnsafeTransactionException('priority fee too high');
    }
  }

  static void _checkDbc(
    WireInstruction ix, {
    required String wallet,
    required ServerTxIntent intent,
  }) {
    final (disc, label) = switch (intent) {
      LaunchCoinIntent() => (_createPool, 'create-pool'),
      SwapCoinIntent() => (_swap2, 'swap'),
      ClaimFeesIntent() => (_claimCreatorFee, 'claim'),
    };
    if (ix.data.length < 8 || !_prefix(ix.data, disc)) {
      throw UnsafeTransactionException('coin action is not a $label');
    }
    final accounts = ix.accounts.toSet();
    final required = switch (intent) {
      LaunchCoinIntent(:final mint, :final pool) => {pool, mint, wallet},
      SwapCoinIntent(:final pool, :final mint) => {pool, mint, wallet},
      ClaimFeesIntent(:final pool, :final mint) => {pool, mint, wallet},
    };
    if (!accounts.containsAll(required)) {
      throw const UnsafeTransactionException(
        'coin action targets another pool',
      );
    }
    if (intent is SwapCoinIntent) {
      // swap2 args: amount_0 u64 | amount_1 u64 | swap_mode u8 (0 = ExactIn).
      // ExactIn ⇒ amount_0 = amount in, amount_1 = minimum out.
      final d = ix.data;
      if (d.length != 25 || d[24] != 0) {
        throw const UnsafeTransactionException('unexpected swap mode');
      }
      final amountIn = _u64Big(d, 8);
      final minOut = _u64Big(d, 16);
      if (amountIn != intent.amountIn) {
        throw const UnsafeTransactionException(
          'swap amount differs from yours',
        );
      }
      if (minOut < intent.minimumOut || minOut == BigInt.zero) {
        throw const UnsafeTransactionException('minimum received is too low');
      }
    }
  }

  static Future<String> _ata(String owner, String mint) async {
    final ata = await findAssociatedTokenAddress(
      owner: Ed25519HDPublicKey.fromBase58(owner),
      mint: Ed25519HDPublicKey.fromBase58(mint),
    );
    return ata.toBase58();
  }

  static bool _sameElements(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b) && a.first == b.first;

  static bool _prefix(Uint8List data, List<int> disc) {
    for (var i = 0; i < disc.length; i++) {
      if (data[i] != disc[i]) return false;
    }
    return true;
  }

  static int _u32(Uint8List d, int o) =>
      ByteData.sublistView(d, o, o + 4).getUint32(0, Endian.little);

  static int _u64(Uint8List d, int o) =>
      ByteData.sublistView(d, o, o + 8).getUint64(0, Endian.little);

  /// Unsigned 64-bit little-endian as BigInt (Dart ints are signed 64-bit).
  static BigInt _u64Big(Uint8List d, int o) {
    var v = BigInt.zero;
    for (var i = 7; i >= 0; i--) {
      v = (v << 8) | BigInt.from(d[o + i]);
    }
    return v;
  }
}

extension on ServerTxIntent {
  String get mintOf => switch (this) {
    LaunchCoinIntent(:final mint) => mint,
    SwapCoinIntent(:final mint) => mint,
    ClaimFeesIntent(:final mint) => mint,
  };
}
