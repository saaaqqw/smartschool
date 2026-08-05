import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (_) => const AdminManagementScreen());
  }

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController(); // UID or Email
  String _addMethod = 'email'; // 'email' or 'uid'
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveNewAdmin() async {
    final identifier = _identifierController.text.trim();
    final name = _nameController.text.trim();
    
    if (identifier.isEmpty) {
      _showSnackBar('الرجاء إدخال البريد الإلكتروني أو المعرّف', isError: true);
      return;
    }
    
    setState(() => _isSaving = true);
    try {
      final db = FirebaseFirestore.instance.collection('admins');
      
      if (_addMethod == 'uid') {
        // Add by UID (doc ID is UID)
        await db.doc(identifier).set({
          'uid': identifier,
          'email': '',
          'name': name.isEmpty ? 'مشرف (عبر UID)' : name,
          'addedAt': FieldValue.serverTimestamp(),
          'method': 'uid',
        }, SetOptions(merge: true));
      } else {
        // Add by Email (doc ID is auto-generated or use email as ID)
        final docId = identifier.replaceAll('.', '_').toLowerCase();
        await db.doc(docId).set({
          'uid': '',
          'email': identifier.toLowerCase(),
          'name': name.isEmpty ? 'مشرف (عبر Email)' : name,
          'addedAt': FieldValue.serverTimestamp(),
          'method': 'email',
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      _nameController.clear();
      _identifierController.clear();
      _showSnackBar('تم إضافة المشرف بنجاح وتفعيل صلاحياته');
    } catch (e) {
      _showSnackBar('تعذر إضافة المشرف: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAdmin(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Text('سحب الصلاحية', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من رغبتك في حذف المشرف "$name" وسحب صلاحياته السحابية؟', style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.tajawal(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف وسحب الصلاحية', style: GoogleFonts.tajawal(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      await FirebaseFirestore.instance.collection('admins').doc(docId).delete();
      if (!mounted) return;
      _showSnackBar('تم حذف المشرف بنجاح');
    } catch (e) {
      _showSnackBar('تعذر حذف المشرف: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إدارة المشرفين والمعلمين',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: scheme.surface,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── فورم الإضافة ──
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إضافة مشرف جديد',
                        style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.primary),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text('بالبريد الإلكتروني', style: GoogleFonts.tajawal(fontSize: 14)),
                              value: 'email',
                              groupValue: _addMethod,
                              onChanged: (val) => setState(() => _addMethod = val!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text('بمعرّف الحساب (UID)', style: GoogleFonts.tajawal(fontSize: 14)),
                              value: 'uid',
                              groupValue: _addMethod,
                              onChanged: (val) => setState(() => _addMethod = val!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _identifierController,
                        decoration: InputDecoration(
                          labelText: _addMethod == 'email' ? 'البريد الإلكتروني للمشرف' : 'معرّف الحساب (UID)',
                          prefixIcon: Icon(_addMethod == 'email' ? Icons.email_rounded : Icons.vpn_key_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'اسم المشرف (اختياري)',
                          prefixIcon: const Icon(Icons.person_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveNewAdmin,
                          icon: _isSaving 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.add_moderator_rounded),
                          label: Text('تفعيل الصلاحية الإدارية', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'المشرفون الحاليون:',
                style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface),
              ),
              const SizedBox(height: 12),

              // ── قائمة المشرفين ──
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('admins').orderBy('addedAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text('لا يوجد مشرفون إضافيون حالياً.', style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final docId = docs[index].id;
                        final name = data['name'] ?? 'بدون اسم';
                        final method = data['method'] ?? 'uid';
                        final email = data['email'] ?? '';
                        final uid = data['uid'] ?? '';
                        
                        final displayId = method == 'email' ? email : uid;

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: scheme.primaryContainer,
                              child: Icon(Icons.shield_rounded, color: scheme.primary),
                            ),
                            title: Text(name, style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                            subtitle: Text(displayId, style: GoogleFonts.tajawal(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                              onPressed: () => _deleteAdmin(docId, name),
                              tooltip: 'سحب الصلاحية',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
