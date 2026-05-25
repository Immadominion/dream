import re

with open('lib/features/trade/presentation/widgets/trade_market_header.dart', 'r') as f:
    content = f.read()

# Add the parameters to the TradeMarketHeader constructor
content = re.sub(
    r'final VoidCallback onToggleChart;\n  const TradeMarketHeader\(\{super\.key, required this\.onToggleChart\}\);',
    '''final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool showChartToggle;
  final bool isChartVisible;
  final VoidCallback? onToggleChart;

  const TradeMarketHeader({
    super.key,
    this.showBackButton = false,
    this.onBackPressed,
    this.showChartToggle = false,
    this.isChartVisible = false,
    this.onToggleChart,
  });''',
    content
)

# Replace the first element of the row inside the AppBar or Header context to maybe show the back button.
# Specifically, we know TradeMarketHeader returns a Container with a child Row.
# We need to render the back button and chart toggle.
content = re.sub(
    r'child: IconButton\([\s\S]*?onPressed: onToggleChart,[\s\S]*?\),',
    '''child: showChartToggle ? IconButton(
                icon: Icon(
                  isChartVisible ? PhosphorIcons.chartLineDown(PhosphorIconsStyle.bold) : PhosphorIcons.chartLineUp(PhosphorIconsStyle.bold), 
                  color: AppColors.textPrimary, 
                  size: 24.w
                ),
                onPressed: onToggleChart,
              ) : const SizedBox.shrink(),''',
    content
)

# And insert the back button at the beginning of the Row.
content = re.sub(
    r'Row\(\s*children: \[',
    '''Row(
          children: [
            if (showBackButton)
              IconButton(
                icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.bold), color: AppColors.textPrimary, size: 24.w),
                onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (showBackButton) SizedBox(width: 12.w),''',
    content
)

with open('lib/features/trade/presentation/widgets/trade_market_header.dart', 'w') as f:
    f.write(content)

