import re

with open('lib/features/trade/presentation/widgets/trade_market_header.dart', 'r') as f:
    text = f.read()

text = re.sub(
    r'border: OutlineInputBorder\(.*?\),',
    '''border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide.none,
              ),''',
    text,
    flags=re.DOTALL
)

text = re.sub(
    r'enabledBorder: OutlineInputBorder\(.*?\),',
    '''enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide.none,
              ),''',
    text,
    flags=re.DOTALL
)

text = re.sub(
    r'focusedBorder: OutlineInputBorder\(.*?\),',
    '''focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide.none,
              ),''',
    text,
    flags=re.DOTALL
)


with open('lib/features/trade/presentation/widgets/trade_market_header.dart', 'w') as f:
    f.write(text)
