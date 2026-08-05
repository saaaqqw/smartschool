import os

file_path = r'c:\Users\ALBASHA\Desktop\smart_school1\lib\screens\settings\admin\admin_content_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

def get_line_index(pattern):
    for i, line in enumerate(lines):
        if pattern in line:
            return i
    return -1

# 1. Add DefaultTabController
scaffold_idx = get_line_index('    return Scaffold(')
if scaffold_idx != -1:
    lines[scaffold_idx] = '    return DefaultTabController(\n      length: 2,\n      child: Scaffold(\n'

# 2. Add TabBar to AppBar
refresh_btn_idx = get_line_index("            tooltip: 'تفريغ الحقول',")
appbar_actions_end = refresh_btn_idx + 2

tab_bar_code = """        ],
        bottom: TabBar(
          labelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.tajawal(),
          indicatorColor: accentColor,
          labelColor: accentColor,
          unselectedLabelColor: textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_rounded), text: 'تفاصيل الدرس'),
            Tab(icon: Icon(Icons.quiz_rounded), text: 'بنك الأسئلة'),
          ],
        ),
      ),
"""
lines[appbar_actions_end:appbar_actions_end+2] = [tab_bar_code]

# 3. Replace the Body start
body_start_idx = get_line_index('      body: Directionality(')
listview_start_idx = get_line_index('                      child: ListView(')

new_body_start = """      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Form(
          key: _formKey,
          child: TabBarView(
            children: [
              // ── Tab 1: Lesson Details ──
              ListView(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20),
                children: [
"""

del lines[body_start_idx:listview_start_idx+2]
lines.insert(body_start_idx, new_body_start)

# 4. Split ListView between Section 2 and Section 3
sec3_header_idx = get_line_index('              // القسم الثالث: إضافة الأسئلة')
# insert closing for Tab 1 and opening for Tab 2
split_code = """                ],
              ),
              // ── Tab 2: Question Bank ──
              ListView(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20),
                children: [
"""
lines.insert(sec3_header_idx - 1, split_code)

# 5. Extract Section 4 (Publish buttons) and put it in bottomNavigationBar
# The publish buttons start at: // القسم الرابع: زر حفظ التغييرات في Firebase
sec4_header_idx = get_line_index('              // القسم الرابع: زر حفظ التغييرات في Firebase')
# It ends around line 2086 (const SizedBox(height: 40);)
end_of_form_idx = get_line_index('              const SizedBox(height: 40);')
if end_of_form_idx == -1:
    end_of_form_idx = sec4_header_idx
    for i in range(sec4_header_idx, len(lines)):
        if '            ],' in lines[i]:
            end_of_form_idx = i
            break

# Extract the buttons
buttons_code = lines[sec4_header_idx - 1:end_of_form_idx]
del lines[sec4_header_idx - 1:end_of_form_idx] # delete from ListView

# Clean up end of TabBarView and close it
# Replace the old ending of Form/Column
old_ending_idx = get_line_index('            ],')
# search downwards from the deletion point
for i in range(sec4_header_idx - 1, len(lines)):
    if '            ],' in lines[i]:
        old_ending_idx = i
        break

for i in range(old_ending_idx, len(lines)):
    if '    );' in lines[i]:
        old_ending_end = i
        break

closing_code = """                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B), // cardBgColor
            border: Border(top: BorderSide(color: Color(0xFF334155))), // borderColor
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
""" + "".join(buttons_code) + """            ],
          ),
        ),
      ),
    );
  }
"""
del lines[old_ending_idx:old_ending_end+2]
lines.insert(old_ending_idx, closing_code)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("Refactoring complete.")
