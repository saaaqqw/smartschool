import os
import re

dir_path = r'c:\Users\ALBASHA\Desktop\smart_school1\lib\screens\settings\admin'

replacements = {
    # 1. First pass: Replace the constant color variable declarations
    r'const bgColor = Color\(0xFF0F172A\);': r'final bgColor = Theme.of(context).colorScheme.surface;',
    r'const cardBgColor = Color\(0xFF1E293B\);': r'final cardBgColor = Theme.of(context).colorScheme.surfaceContainer;',
    r'const borderColor = Color\(0xFF334155\);': r'final borderColor = Theme.of(context).colorScheme.outlineVariant;',
    r'const accentColor = Color\(0xFF10B981\);.*': r'final accentColor = Theme.of(context).colorScheme.primary;',
    r'const textPrimary = Color\(0xFFF8FAFC\);': r'final textPrimary = Theme.of(context).colorScheme.onSurface;',
    r'const textSecondary = Color\(0xFF94A3B8\);': r'final textSecondary = Theme.of(context).colorScheme.onSurfaceVariant;',
    
    # 2. Second pass: Replace any remaining raw hex colors
    r'Color\(0xFF0F172A\)': r'Theme.of(context).colorScheme.surface',
    r'Color\(0xFF1E293B\)': r'Theme.of(context).colorScheme.surfaceContainer',
    r'Color\(0xFF334155\)': r'Theme.of(context).colorScheme.outlineVariant',
    r'Color\(0xFF10B981\)': r'Theme.of(context).colorScheme.primary',
    r'Color\(0xFFF8FAFC\)': r'Theme.of(context).colorScheme.onSurface',
    r'Color\(0xFF94A3B8\)': r'Theme.of(context).colorScheme.onSurfaceVariant',
    r'Color\(0xFF64748B\)': r'Theme.of(context).colorScheme.onSurfaceVariant',
    
    # 3. Third pass: Clean up stray `const` keywords that were applied to the old Color literals
    r'const Theme\.of\(context\)': r'Theme.of(context)',
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
print("Color replacement complete.")
