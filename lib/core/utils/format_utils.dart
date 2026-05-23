/// Shared number and price formatting utilities for the Dream trading terminal.
///
/// All price/number display logic lives here to ensure consistency across
/// every widget and page.
/// Format a USD price with proper comma separators and decimal precision.
///
/// Examples:
///   formatPrice(60234.0)  → '$60,234'
///   formatPrice(1234.56)  → '$1,234.56' (if >= 1000 with cents)
///   formatPrice(98.765)   → '$98.77'
///   formatPrice(0.00123)  → '$0.0012'
String formatPrice(double price) {
  if (price <= 0) return '--';
  if (price >= 1000) {
    // Integer display with comma separators (no decimals for large prices)
    return '\$${_addThousandsSeparators(price.toStringAsFixed(0))}';
  }
  if (price >= 1) {
    return '\$${price.toStringAsFixed(2)}';
  }
  if (price >= 0.01) {
    return '\$${price.toStringAsFixed(4)}';
  }
  // Very small prices (meme coins, sub-cent)
  return '\$${price.toStringAsFixed(6)}';
}

/// Format a price without the $ prefix (useful for order inputs).
String formatPriceRaw(double price) {
  if (price <= 0) return '';
  if (price >= 1000) {
    return _addThousandsSeparators(price.toStringAsFixed(0));
  }
  if (price >= 1) return price.toStringAsFixed(2);
  if (price >= 0.01) return price.toStringAsFixed(4);
  return price.toStringAsFixed(6);
}

/// Format a large USD value in compact notation.
///
/// Examples:
///   formatCompact(1_500_000_000) → '$1.5B'
///   formatCompact(2_450_000)     → '$2.5M'
///   formatCompact(123_456)       → '$123K'
///   formatCompact(456)           → '$456'
String formatCompact(double value) {
  if (value <= 0) return '--';
  if (value >= 1e9) return '\$${(value / 1e9).toStringAsFixed(1)}B';
  if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(1)}M';
  if (value >= 1e3) return '\$${(value / 1e3).toStringAsFixed(0)}K';
  return '\$${value.toStringAsFixed(0)}';
}

/// Format a P&L value with sign prefix and dollar amount.
///
/// Examples:
///   formatPnl(123.45)  → '+$123.45'
///   formatPnl(-78.9)   → '-$78.90'
///   formatPnl(0)       → '$0.00'
String formatPnl(double pnl) {
  final abs = pnl.abs();
  final formatted = '\$${abs.toStringAsFixed(2)}';
  if (pnl > 0) return '+$formatted';
  if (pnl < 0) return '-$formatted';
  return formatted;
}

/// Format a percentage value with sign prefix.
///
/// Examples:
///   formatPercent(1.234)   → '+1.23%'
///   formatPercent(-0.567)  → '-0.57%'
String formatPercent(double pct, {int decimals = 2}) {
  final sign = pct >= 0 ? '+' : '';
  return '$sign${pct.toStringAsFixed(decimals)}%';
}

/// Format a funding rate (input is a raw ratio, e.g. 0.000142 = 0.0142%).
///
/// Examples:
///   formatFundingRate(0.000142)  → '+0.0142%'
///   formatFundingRate(-0.00005)  → '-0.0050%'
String formatFundingRate(double rate) {
  final pct = rate * 100;
  final sign = pct >= 0 ? '+' : '';
  return '$sign${pct.toStringAsFixed(4)}%';
}

/// Format a USDC balance for display.
///
/// Examples:
///   formatUsdc(1234.56)   → '$1,234.56'
///   formatUsdc(0.50)      → '$0.50'
String formatUsdc(double amount) {
  if (amount <= 0) return '\$0.00';
  if (amount >= 1000) {
    final intPart = amount.truncate();
    final decPart = ((amount - intPart) * 100).round();
    return '\$${_addThousandsSeparators(intPart.toString())}.${decPart.toString().padLeft(2, '0')}';
  }
  return '\$${amount.toStringAsFixed(2)}';
}

/// Add thousands separators (commas) to an integer string.
///
/// Example: '1234567' → '1,234,567'
String addThousandsSep(String intStr) => _addThousandsSeparators(intStr);

/// Add thousands separators (commas) to an integer string.
///
/// Example: '1234567' → '1,234,567'
String _addThousandsSeparators(String intStr) {
  // Handle negative numbers
  final isNeg = intStr.startsWith('-');
  final digits = isNeg ? intStr.substring(1) : intStr;

  final buf = StringBuffer();
  final n = digits.length;
  for (int i = 0; i < n; i++) {
    if (i > 0 && (n - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }

  return isNeg ? '-${buf.toString()}' : buf.toString();
}
