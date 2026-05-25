with open('lib/core/services/phoenix/phoenix_trader_service.dart', 'r') as f:
    text = f.read()

# Let's read the lines directly
import sys

def add_braces(filepath, line_num):
    with open(filepath, 'r') as f:
        lines = f.readlines()
    idx = line_num - 1
    # assuming simple if statement like `if (cond) return;`
    line = lines[idx]
    if 'if' in line and not '{' in line:
        import re
        match = re.match(r'^(\s*if\s*\(.*?\))\s*(.*)$', line)
        if match:
            new_line = match.group(1) + ' { ' + match.group(2) + ' }\n'
            lines[idx] = new_line
            with open(filepath, 'w') as f:
                f.writelines(lines)
            return True
    return False

add_braces('lib/core/services/phoenix/phoenix_trader_service.dart', 179)
add_braces('lib/features/positions/presentation/widgets/position_card.dart', 337)

