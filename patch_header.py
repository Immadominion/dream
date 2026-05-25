import re

with open('lib/features/trade/presentation/widgets/trade_market_header.dart', 'r') as f:
    text = f.read()

# 1. Add fields and constructor
new_constructor = '''  final bool showBackButton;
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
  });'''

text = text.replace('const TradeMarketHeader({super.key});', new_constructor)

# 2. Add PhosphorIcons import at the top
if 'phosphor_flutter' not in text:
    text = text.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:phosphor_flutter/phosphor_flutter.dart';")

# 3. Handle Trade/Market toggle switch removal and add Chart toggle button
# Look for Expanded(child: Align(alignment: Alignment.centerRight, child: _HeaderModeSwitch( ... )))
text = re.sub(
    r'Expanded\(\s*child:\s*Align\(\s*alignment:\s*Alignment\.centerRight,\s*child:\s*_HeaderModeSwitch\(.*?\),\s*\),\s*\),',
    '''Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: showChartToggle 
                ? IconButton(
                    icon: Icon(
                      isChartVisible ? PhosphorIcons.chartLineDown(PhosphorIconsStyle.bold) : PhosphorIcons.chartLineUp(PhosphorIconsStyle.bold), 
                      color: AppColors.textPrimaryDark, 
                      size: 24.w
                    ),
                    onPressed: onToggleChart,
                  ) 
                : const SizedBox.shrink(),
            ),
          ),''',
    text,
    flags=re.DOTALL
)

# 4. Strip the _HeaderModeSwitch class
text = re.sub(r'class _HeaderModeSwitch extends ConsumerWidget \{.*?\n\}\n', '', text, flags=re.DOTALL)

# 5. Prepend back button functionality into the Row (the outermost row in _TradeMarketHeader returned widget)
text = re.sub(
    r'Row\(\s*children:\s*\[',
    '''Row(
          children: [
            if (showBackButton)
              IconButton(
                icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.bold), color: AppColors.textPrimaryDark, size: 24.w),
                onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (showBackButton) SizedBox(width: 12.w),''',
    text, 
    count=1
)

with open('lib/features/trade/presentation/widgets/trade_market_header.dart', 'w') as f:
    f.write(text)

