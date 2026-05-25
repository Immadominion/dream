with open('lib/features/trade/presentation/widgets/trade_tp_sl_section.dart', 'r') as f:
    lines = f.readlines()

output = []
skip = False
for i, line in enumerate(lines):
    if line.strip() == '],':
        pass # keep it
    if line.strip() == '),' and lines[i+1].strip() == ');' and lines[i+2].strip() == '}':
        output.append('  );\n') # replace ), and skip );
        skip = True
        continue
    if skip and line.strip() == ');':
        skip = False
        continue
    
    output.append(line)

with open('lib/features/trade/presentation/widgets/trade_tp_sl_section.dart', 'w') as f:
    f.writelines(output)

