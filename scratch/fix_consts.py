import os
import re

file_path = r'c:\Users\ALBASHA\Desktop\smart_school1\lib\screens\settings\admin\admin_content_screen.dart'
lines_to_fix = [1106, 1235, 1238, 1262, 1267, 1368, 1606, 1623, 1664, 1758, 1889, 2046, 2210, 2281]

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line_num in lines_to_fix:
    idx = line_num - 1
    if idx < len(lines):
        lines[idx] = re.sub(r'\bconst\s+', '', lines[idx])

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
print("Removed const from specified lines.")
