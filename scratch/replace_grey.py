import os
import re

dir_path = r'c:\Users\ALBASHA\Desktop\smart_school1\lib\screens\settings\admin'

replacements = {
    r'Colors\.grey\.shade600': r'Theme.of(context).colorScheme.onSurfaceVariant',
    r'Colors\.grey': r'Theme.of(context).colorScheme.onSurfaceVariant',
}

for filename in os.listdir(dir_path):
    if filename.endswith('.dart'):
        filepath = os.path.join(dir_path, filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        for old, new in replacements.items():
            content = re.sub(old, new, content)
            
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
print("Grey color replacement complete.")
