import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dream/core/services/solana/server_tx_guard.dart';
import 'package:dream/core/services/solana/wire_transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solana/base58.dart';
import 'package:solana/solana.dart';

/// Fixtures are real transactions built by dream-server against Meteora's
/// DBC program (dream-server/scripts/make-signer-fixture.ts).
void main() {
  late Map<String, dynamic> f;

  setUpAll(() {
    f =
        jsonDecode(File('test/fixtures/dream_txs.json').readAsStringSync())
            as Map<String, dynamic>;
  });

  WireTransaction tx(String b64) => WireTransaction.parse(base64Decode(b64));
  List<int> hex(String s) => [
    for (var i = 0; i < s.length; i += 2)
      int.parse(s.substring(i, i + 2), radix: 16),
  ];

  SwapCoinIntent swapIntent(String kind, {BigInt? amountIn, BigInt? minOut}) =>
      SwapCoinIntent(
        pool: f['pool'],
        mint: f['mint'],
        isBuy: kind == 'buy',
        amountIn: amountIn ?? BigInt.parse(f[kind]['amountIn']),
        minimumOut: minOut ?? BigInt.parse(f[kind]['minimumOut']),
      );

  group('wire format', () {
    test('parses signer slots of a server-built launch tx', () {
      final wire = tx(f['launch']['unsigned']);
      expect(wire.signers, [f['owner'], f['mint']]);
      expect(wire.bytes.sublist(1, 65).every((b) => b == 0), isTrue);
      expect(wire.bytes.sublist(65, 129).any((b) => b != 0), isTrue);
    });

    test('signing like the app matches web3.js byte-for-byte', () async {
      final kp = await Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: hex(f['ownerSeedHex']),
      );
      final wire = tx(f['launch']['unsigned']);
      final sig = await kp.sign(wire.message);
      expect(
        base64Encode(wire.withSignature(kp.address, sig.bytes)),
        f['launch']['signed'],
      );
    });

    test('unsignedFromMessage round-trips', () {
      final wire = tx(f['claim']['tx']);
      final rebuilt = WireTransaction.parse(
        WireTransaction.unsignedFromMessage(wire.message),
      );
      expect(rebuilt.message, wire.message);
      expect(rebuilt.signers, wire.signers);
    });

    test('rejects malformed input and foreign signers', () {
      expect(
        () => WireTransaction.parse(Uint8List.fromList([5, 1, 2, 3])),
        throwsA(isA<WireTransactionException>()),
      );
      expect(
        () => tx(
          f['claim']['tx'],
        ).withSignature('11111111111111111111111111111111', List.filled(64, 1)),
        throwsA(isA<WireTransactionException>()),
      );
    });
  });

  group('guard accepts the real flows', () {
    test('launch', () async {
      await ServerTxGuard.check(
        tx(f['launch']['unsigned']),
        wallet: f['owner'],
        intent: LaunchCoinIntent(mint: f['mint'], pool: f['pool']),
      );
    });
    test('buy', () async {
      await ServerTxGuard.check(
        tx(f['buy']['tx']),
        wallet: f['buyer'],
        intent: swapIntent('buy'),
      );
    });
    test('sell', () async {
      await ServerTxGuard.check(
        tx(f['sell']['tx']),
        wallet: f['buyer'],
        intent: swapIntent('sell'),
      );
    });
    test('claim', () async {
      await ServerTxGuard.check(
        tx(f['claim']['tx']),
        wallet: f['owner'],
        intent: ClaimFeesIntent(pool: f['pool'], mint: f['mint']),
      );
    });
  });

  group('guard rejects tampering', () {
    Future<void> expectBlocked(
      Future<void> Function() run,
      String reasonContains,
    ) async {
      await expectLater(
        run(),
        throwsA(
          isA<UnsafeTransactionException>().having(
            (e) => e.reason,
            'reason',
            contains(reasonContains),
          ),
        ),
      );
    }

    test('a transaction for someone else\'s wallet', () async {
      await expectBlocked(
        () => ServerTxGuard.check(
          tx(f['claim']['tx']),
          wallet: f['buyer'],
          intent: ClaimFeesIntent(pool: f['pool'], mint: f['mint']),
        ),
        'fee payer',
      );
    });

    test('a different action than the user asked for', () async {
      await expectBlocked(
        () => ServerTxGuard.check(
          tx(f['buy']['tx']),
          wallet: f['buyer'],
          intent: ClaimFeesIntent(pool: f['pool'], mint: f['mint']),
        ),
        'not a claim',
      );
    });

    test('a swap on another pool', () async {
      await expectBlocked(
        () => ServerTxGuard.check(
          tx(f['sell']['tx']),
          wallet: f['buyer'],
          intent: SwapCoinIntent(
            pool: '11111111111111111111111111111111',
            mint: f['mint'],
            isBuy: false,
            amountIn: BigInt.parse(f['sell']['amountIn']),
            minimumOut: BigInt.parse(f['sell']['minimumOut']),
          ),
        ),
        'another pool',
      );
    });

    test('a swap amount that differs from what the user typed', () async {
      await expectBlocked(
        () => ServerTxGuard.check(
          tx(f['sell']['tx']),
          wallet: f['buyer'],
          intent: swapIntent('sell', amountIn: BigInt.one),
        ),
        'differs',
      );
    });

    test('a weaker minimum than the user was shown', () async {
      await expectBlocked(
        () => ServerTxGuard.check(
          tx(f['sell']['tx']),
          wallet: f['buyer'],
          intent: swapIntent(
            'sell',
            minOut: BigInt.parse(f['sell']['minimumOut']) + BigInt.one,
          ),
        ),
        'too low',
      );
    });

    test('a buy that wraps more SOL than the user entered', () async {
      await expectBlocked(
        () => ServerTxGuard.check(
          tx(f['buy']['tx']),
          wallet: f['buyer'],
          intent: swapIntent(
            'buy',
            amountIn: BigInt.parse(f['buy']['amountIn']) - BigInt.one,
          ),
        ),
        // Pinned DBC amount trips first; either check blocks it.
        'differs',
      );
    });

    // Synthetic malicious transactions signed "as" the user.
    final attacker = base58encode(List.filled(32, 0xAA));

    Uint8List legacyTx(
      String feePayer,
      List<String> otherKeys,
      List<(int, List<int>, List<int>)> ixs,
    ) {
      final keys = [feePayer, ...otherKeys];
      final msg = <int>[
        1, 0, keys.length - 2, // 1 signer; programs/accounts are read-only-ish
        ...WireTransaction.compactU16(keys.length),
        for (final k in keys) ...base58decode(k),
        ...List.filled(32, 1),
        ...WireTransaction.compactU16(ixs.length),
        for (final (prog, accts, data) in ixs) ...[
          prog,
          ...WireTransaction.compactU16(accts.length),
          ...accts,
          ...WireTransaction.compactU16(data.length),
          ...data,
        ],
      ];
      return WireTransaction.unsignedFromMessage(Uint8List.fromList(msg));
    }

    test('a SOL transfer to an attacker', () async {
      final user = f['buyer'] as String;
      final raw = legacyTx(
        user,
        [attacker, ServerTxGuard.systemProgram],
        [
          (2, [0, 1], [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]),
        ],
      );
      await expectBlocked(
        () => ServerTxGuard.check(
          WireTransaction.parse(raw),
          wallet: user,
          intent: ClaimFeesIntent(pool: f['pool'], mint: f['mint']),
        ),
        'not yours',
      );
    });

    test('closing a token account to an attacker', () async {
      final user = f['buyer'] as String;
      final raw = legacyTx(
        user,
        [attacker, ServerTxGuard.tokenProgram],
        [
          (2, [1, 1, 0], [9]),
        ],
      );
      await expectBlocked(
        () => ServerTxGuard.check(
          WireTransaction.parse(raw),
          wallet: user,
          intent: ClaimFeesIntent(pool: f['pool'], mint: f['mint']),
        ),
        'someone else',
      );
    });

    test('an unknown program', () async {
      final user = f['buyer'] as String;
      final raw = legacyTx(
        user,
        [attacker],
        [
          (1, [0], [1, 2, 3]),
        ],
      );
      await expectBlocked(
        () => ServerTxGuard.check(
          WireTransaction.parse(raw),
          wallet: user,
          intent: ClaimFeesIntent(pool: f['pool'], mint: f['mint']),
        ),
        'unknown program',
      );
    });
  });
}
