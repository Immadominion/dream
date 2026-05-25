import re

with open('lib/features/positions/presentation/widgets/position_card.dart', 'r') as f:
    text = f.read()

text = re.sub(
    r'border: Border\.all\(\s*color: sel\s*\?\s*AppColors\.bearish\s*:\s*AppColors\.borderDark,\s*\),',
    'border: Border.all(color: Colors.transparent),',
    text
)
with open('lib/features/positions/presentation/widgets/position_card.dart', 'w') as f:
    f.write(text)

