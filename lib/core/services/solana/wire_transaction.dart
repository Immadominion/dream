import 'dart:typed_data';

import 'package:solana/base58.dart';

class WireTransactionException implements Exception {
  final String message;
  const WireTransactionException(this.message);
  @override
  String toString() => message;
}

/// A decoded top-level instruction.
class WireInstruction {
  final String programId;

  /// Account addresses, in instruction order.
  final List<String> accounts;
  final Uint8List data;

  const WireInstruction({
    required this.programId,
    required this.accounts,
    required this.data,
  });
}

/// A parsed Solana wire transaction (legacy or v0).
///
/// Layout: `compact-u16 n | n × 64-byte signatures | message`. The message is
/// an optional version byte (high bit set ⇒ v0), the header
/// `[numRequiredSignatures, roSigned, roUnsigned]`, `compact-u16 k | k × 32`
/// account keys, a 32-byte blockhash, then `compact-u16 m` instructions of
/// `programIdIndex | compact-u16 a | a account indices | compact-u16 d | d data`.
/// v0 messages end with address-table lookups, which we parse only to reject
/// (accounts loaded from tables can't be inspected without RPC).
class WireTransaction {
  final Uint8List bytes;
  final int signaturesOffset;
  final int signatureCount;
  final Uint8List message;

  /// Base58 public keys of the required signers, in signature-slot order.
  final List<String> signers;
  final List<String> accountKeys;
  final List<WireInstruction> instructions;
  final bool isVersioned;
  final bool usesLookupTables;

  const WireTransaction._({
    required this.bytes,
    required this.signaturesOffset,
    required this.signatureCount,
    required this.message,
    required this.signers,
    required this.accountKeys,
    required this.instructions,
    required this.isVersioned,
    required this.usesLookupTables,
  });

  String get feePayer => signers.first;

  factory WireTransaction.parse(Uint8List bytes) {
    final r = _Reader(bytes);
    final sigCount = r.compactU16();
    final sigOffset = r.offset;
    r.skip(sigCount * 64);
    final messageOffset = r.offset;
    final message = Uint8List.fromList(bytes.sublist(messageOffset));
    final parsed = parseMessage(message);
    if (parsed.numRequiredSignatures != sigCount) {
      throw const WireTransactionException('Signature layout mismatch');
    }
    return WireTransaction._(
      bytes: Uint8List.fromList(bytes),
      signaturesOffset: sigOffset,
      signatureCount: sigCount,
      message: message,
      signers: parsed.accountKeys.sublist(0, sigCount),
      accountKeys: parsed.accountKeys,
      instructions: parsed.instructions,
      isVersioned: parsed.isVersioned,
      usesLookupTables: parsed.usesLookupTables,
    );
  }

  /// Wrap a bare message in a wire transaction with empty signature slots.
  static Uint8List unsignedFromMessage(Uint8List message) {
    final n = parseMessage(message).numRequiredSignatures;
    return Uint8List.fromList([
      ...compactU16(n),
      ...List<int>.filled(n * 64, 0),
      ...message,
    ]);
  }

  /// Returns a copy with [signature] written into [signer]'s slot. Every
  /// other slot (e.g. the server's mint signature) is left untouched.
  Uint8List withSignature(String signer, List<int> signature) {
    if (signature.length != 64) {
      throw const WireTransactionException('Invalid signature length');
    }
    final index = signers.indexOf(signer);
    if (index < 0) {
      throw const WireTransactionException(
        'This transaction is not for your wallet',
      );
    }
    final out = Uint8List.fromList(bytes);
    out.setRange(
      signaturesOffset + index * 64,
      signaturesOffset + (index + 1) * 64,
      signature,
    );
    return out;
  }

  /// The 64-byte signature in [signer]'s slot.
  Uint8List signatureOf(String signer) {
    final index = signers.indexOf(signer);
    if (index < 0) {
      throw const WireTransactionException('Signer not found');
    }
    return Uint8List.fromList(
      bytes.sublist(
        signaturesOffset + index * 64,
        signaturesOffset + (index + 1) * 64,
      ),
    );
  }

  static ParsedMessage parseMessage(Uint8List message) {
    final r = _Reader(message);
    var isVersioned = false;
    if (message.isEmpty) {
      throw const WireTransactionException('Malformed transaction');
    }
    if (message[0] & 0x80 != 0) {
      final version = message[0] & 0x7f;
      if (version != 0) {
        throw WireTransactionException(
          'Unsupported transaction version $version',
        );
      }
      isVersioned = true;
      r.skip(1);
    }
    final numRequired = r.u8();
    r.skip(2);
    final keyCount = r.compactU16();
    if (keyCount < numRequired || numRequired == 0) {
      throw const WireTransactionException('Malformed account keys');
    }
    final keys = <String>[
      for (var i = 0; i < keyCount; i++) base58encode(r.take(32)),
    ];
    r.skip(32); // recent blockhash
    final ixCount = r.compactU16();
    final instructions = <WireInstruction>[];
    for (var i = 0; i < ixCount; i++) {
      final programIndex = r.u8();
      final accountCount = r.compactU16();
      final accountIdx = [for (var j = 0; j < accountCount; j++) r.u8()];
      final dataLen = r.compactU16();
      final data = Uint8List.fromList(r.take(dataLen));
      String key(int idx) {
        if (idx >= keys.length) {
          // Index points into an address lookup table.
          return '<lookup:$idx>';
        }
        return keys[idx];
      }

      instructions.add(
        WireInstruction(
          programId: key(programIndex),
          accounts: [for (final a in accountIdx) key(a)],
          data: data,
        ),
      );
    }
    var usesLookupTables = false;
    if (isVersioned) {
      usesLookupTables = r.compactU16() > 0;
    }
    return ParsedMessage(
      numRequiredSignatures: numRequired,
      accountKeys: keys,
      instructions: instructions,
      isVersioned: isVersioned,
      usesLookupTables: usesLookupTables,
    );
  }

  static List<int> compactU16(int value) {
    if (value <= 0x7f) return [value];
    if (value <= 0x3fff) return [(value & 0x7f) | 0x80, (value >> 7) & 0xff];
    return [
      (value & 0x7f) | 0x80,
      ((value >> 7) & 0x7f) | 0x80,
      (value >> 14) & 0xff,
    ];
  }
}

class ParsedMessage {
  final int numRequiredSignatures;
  final List<String> accountKeys;
  final List<WireInstruction> instructions;
  final bool isVersioned;
  final bool usesLookupTables;

  const ParsedMessage({
    required this.numRequiredSignatures,
    required this.accountKeys,
    required this.instructions,
    required this.isVersioned,
    required this.usesLookupTables,
  });
}

class _Reader {
  final List<int> _b;
  int offset = 0;
  _Reader(this._b);

  void _need(int n) {
    if (offset + n > _b.length) {
      throw const WireTransactionException('Malformed transaction');
    }
  }

  int u8() {
    _need(1);
    return _b[offset++];
  }

  List<int> take(int n) {
    _need(n);
    final out = _b.sublist(offset, offset + n);
    offset += n;
    return out;
  }

  void skip(int n) {
    _need(n);
    offset += n;
  }

  int compactU16() {
    var value = 0;
    for (var i = 0; i < 3; i++) {
      final byte = u8();
      value |= (byte & 0x7f) << (7 * i);
      if (byte & 0x80 == 0) return value;
    }
    throw const WireTransactionException('Malformed compact-u16');
  }
}
