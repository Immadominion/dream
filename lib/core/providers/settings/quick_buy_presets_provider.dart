import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/storage_service.dart';

/// Default quick buy presets in SOL
const List<double> _defaultQuickBuyPresets = [0.1, 1.0];
const String _quickBuyStorageKey = 'quick_buy_presets_v1';

/// Notifier for quick buy presets using Riverpod 3.x Notifier pattern
class QuickBuyPresetsNotifier extends Notifier<List<double>> {
  @override
  List<double> build() {
    // Hydrate from storage on build
    Future.microtask(_hydrate);
    return _defaultQuickBuyPresets;
  }

  void _hydrate() {
    final stored = StorageService.getSettings(_quickBuyStorageKey);
    final parsed = _parsePresets(stored);
    if (parsed != null && parsed.isNotEmpty) {
      state = parsed;
    }
  }

  Future<void> updatePreset(int index, double value) async {
    if (index < 0 || index >= state.length) {
      return;
    }

    final clamped = value.clamp(0.001, 1000.0);
    final formatted = double.parse(clamped.toStringAsFixed(3));
    final next = List<double>.from(state);
    next[index] = formatted;

    state = List<double>.unmodifiable(next);
    await StorageService.saveSettings(_quickBuyStorageKey, next);
  }

  Future<void> reset() async {
    state = _defaultQuickBuyPresets;
    await StorageService.saveSettings(
      _quickBuyStorageKey,
      _defaultQuickBuyPresets,
    );
  }

  List<double>? _parsePresets(dynamic stored) {
    if (stored is List) {
      return _normalizeList(stored.cast<dynamic>());
    }

    if (stored is String && stored.isNotEmpty) {
      try {
        final decoded = jsonDecode(stored);
        if (decoded is List) {
          return _normalizeList(decoded.cast<dynamic>());
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  List<double>? _normalizeList(List<dynamic> values) {
    final parsed = <double>[];
    for (final value in values) {
      final parsedValue = _asDouble(value);
      if (parsedValue != null && parsedValue > 0) {
        parsed.add(double.parse(parsedValue.toStringAsFixed(3)));
      }
    }

    if (parsed.isEmpty) {
      return null;
    }

    if (parsed.length >= 2) {
      return List<double>.unmodifiable(parsed.take(2));
    }

    // If only one preset stored, duplicate to maintain two buttons
    final single = parsed.first;
    return List<double>.unmodifiable([single, single >= 1 ? single : 1.0]);
  }
}

/// Provider exposing quick buy presets stored in local settings (Riverpod 3.x)
final quickBuyPresetsProvider =
    NotifierProvider<QuickBuyPresetsNotifier, List<double>>(
      QuickBuyPresetsNotifier.new,
    );

double? _asDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
