import re

with open('lib/features/positions/presentation/widgets/position_card.dart', 'r') as f:
    text = f.read()

# 1. Textfield borders to transparent/none
text = re.sub(
    r'border:\s*OutlineInputBorder\(\s*borderRadius: BorderRadius\.circular\(\d+\.r\),\s*borderSide: BorderSide\(color: AppColors\.borderDark\),\s*\),',
    '''border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6.r),
                  borderSide: BorderSide.none,
                ),''',
    text
)
text = re.sub(
    r'enabledBorder:\s*OutlineInputBorder\(\s*borderRadius: BorderRadius\.circular\(\d+\.r\),\s*borderSide: BorderSide\(\s*color: _useCustom\s*\?\s*AppColors\.primary\s*:\s*AppColors\.borderDark,\s*\),\s*\),',
    '''enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6.r),
                  borderSide: BorderSide.none,
                ),''',
    text
)
# generic enabled/focused with borderSide
text = re.sub(
    r'enabledBorder:\s*OutlineInputBorder\(\s*borderRadius: BorderRadius\.circular\(\d+\.r\),\s*borderSide: BorderSide\(color: AppColors\.borderDark\),\s*\),',
    '''enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6.r),
                  borderSide: BorderSide.none,
                ),''',
    text
)
text = re.sub(
    r'focusedBorder:\s*OutlineInputBorder\(\s*borderRadius: BorderRadius\.circular\(\d+\.r\),\s*borderSide: const BorderSide\(color: AppColors\.primary\),\s*\),',
    '''focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6.r),
                  borderSide: BorderSide.none,
                ),''',
    text
)
text = re.sub(
    r'focusedBorder:\s*OutlineInputBorder\(\s*borderRadius: BorderRadius\.circular\(\d+\.r\),\s*borderSide: BorderSide\(color: AppColors\.primary\),\s*\),',
    '''focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6.r),
                  borderSide: BorderSide.none,
                ),''',
    text
)

# 2. Container Border.all(color: AppColors.borderDark)
text = re.sub(r'border: Border\.all\(color: AppColors\.borderDark\)', 'border: Border.all(color: Colors.transparent)', text)


with open('lib/features/positions/presentation/widgets/position_card.dart', 'w') as f:
    f.write(text)

