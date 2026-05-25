import re

with open('lib/features/trade/presentation/widgets/trade_market_header.dart', 'r') as f:
    text = f.read()

# Replace TextField borders
text = re.sub(
    r'border:\s*OutlineInputBorder\(.*?\),',
    '''border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide.none,
              ),''',
    text,
    flags=re.DOTALL
)
text = re.sub(
    r'enabledBorder:\s*OutlineInputBorder\(.*?\),',
    '''enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide.none,
              ),''',
    text,
    flags=re.DOTALL
)
text = re.sub(
    r'focusedBorder:\s*OutlineInputBorder\(.*?\),',
    '''focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide.none,
              ),''',
    text,
    flags=re.DOTALL
)

# And remove the 'color: AppColors.borderDark' line if any in the handle
# wait, actually let's re-write build method of _SymbolPickerSheet using a pure string replacement.

