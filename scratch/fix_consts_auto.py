import os
import re
import subprocess

file_path = r'c:\Users\ALBASHA\Desktop\smart_school1\lib\screens\settings\admin\admin_content_screen.dart'
# Run flutter analyze and capture output
try:
    output = subprocess.check_output(
        'flutter analyze', 
        cwd=r'c:\Users\ALBASHA\Desktop\smart_school1', 
        shell=True, 
        text=True,
        stderr=subprocess.STDOUT
    )
except subprocess.CalledProcessError as e:
    output = e.output

# Parse the output
lines_to_fix = []
for line in output.splitlines():
    if 'admin_content_screen.dart' in line and ('invalid_constant' in line or 'const_eval_method_invocation' in line):
        # Format is usually: error - Message - path:line:col - rule
        match = re.search(r'admin_content_screen\.dart:(\d+):', line)
        if match:
            lines_to_fix.append(int(match.group(1)))

print("Lines to fix:", lines_to_fix)

if lines_to_fix:
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    for line_num in lines_to_fix:
        idx = line_num - 1
        if idx < len(lines):
            lines[idx] = re.sub(r'\bconst\s+', '', lines[idx])

    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print("Fixed consts automatically.")
else:
    print("No const errors found.")
