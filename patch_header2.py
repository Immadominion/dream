import re

with open('lib/features/trade/presentation/widgets/trade_market_header.dart', 'r') as f:
    text = f.read()

# Replace constructor correctly
text = re.sub(
    r'  const TradeMarketHeader\(\{\n    super\.key,\n    required this\.tradeState,\n    required this\.marketsState,\n  \}\);',
    '''  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool showChartToggle;
  final bool isChartVisible;
  final VoidCallback? onToggleChart;

  const TradeMarketHeader({
    super.key,
    required this.tradeState,
    required this.marketsState,
    this.showBackButton = false,
    this.onBackPressed,
    this.showChartToggle = false,
    this.isChartVisible = false,
    this.onToggleChart,
  });''',
    text
)

with open('lib/features/trade/presentation/widgets/trade_market_header.dart', 'w') as f:
    f.write(text)

