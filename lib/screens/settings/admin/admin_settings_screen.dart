import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/config/ai_config_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (_) => const AdminSettingsScreen());
  }

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  // ── AI Controllers ──
  final _apiKeyController = TextEditingController();
  final _geminiApiKeyController = TextEditingController();
  final _aiModelController = TextEditingController();
  bool _isSavingAiConfig = false;

  // ── Notification Controllers ──
  final _notifTitleController = TextEditingController();
  final _notifBodyController = TextEditingController();
  final _notifSenderController = TextEditingController(text: 'إدارة المدرسة');
  final _notifImageUrlController = TextEditingController();
  final _notifActionLinkController = TextEditingController();
  String _notifTargetGrade = 'الكل';
  String _notifType = 'general';
  bool _isSendingNotif = false;

  @override
  void initState() {
    super.initState();
    _loadAiSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _geminiApiKeyController.dispose();
    _aiModelController.dispose();
    _notifTitleController.dispose();
    _notifBodyController.dispose();
    _notifSenderController.dispose();
    _notifImageUrlController.dispose();
    _notifActionLinkController.dispose();
    super.dispose();
  }

  Future<void> _loadAiSettings() async {
    final key = await AiConfigService.getApiKey();
    final geminiKey = await AiConfigService.getGeminiApiKey();
    final model = await AiConfigService.getModelName();
    if (mounted) {
      setState(() {
        _apiKeyController.text = key;
        _geminiApiKeyController.text = geminiKey;
        _aiModelController.text = model;
      });
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveAiSettings() async {
    final key = _apiKeyController.text.trim();
    final geminiKey = _geminiApiKeyController.text.trim();
    final model = _aiModelController.text.trim();
    
    if (key.isEmpty || geminiKey.isEmpty || model.isEmpty) {
      _showSnackBar('يرجى إدخال المفاتيح واسم النموذج أولاً', isError: true);
      return;
    }
    
    setState(() => _isSavingAiConfig = true);
    try {
      await AiConfigService.updateAiConfig(apiKey: key, geminiApiKey: geminiKey, modelName: model);
      _showSnackBar('تم حفظ وتحديث إعدادات الذكاء الاصطناعي بنجاح 🤖✅');
    } catch (e) {
      _showSnackBar('خطأ أثناء حفظ إعدادات AI: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingAiConfig = false);
    }
  }

  Future<void> _sendBroadcastNotification() async {
    final title = _notifTitleController.text.trim();
    final body = _notifBodyController.text.trim();
    final senderName = _notifSenderController.text.trim();
    final imageUrl = _notifImageUrlController.text.trim();
    final actionLink = _notifActionLinkController.text.trim();

    if (title.isEmpty) {
      _showSnackBar('الرجاء إدخال عنوان الإشعار على الأقل.', isError: true);
      return;
    }

    setState(() => _isSendingNotif = true);
    try {
      final db = FirebaseFirestore.instance;
      await db.collection('notifications').add({
        'title': title,
        'body': body,
        'type': _notifType,
        'targetGrade': _notifTargetGrade,
        'senderName': senderName.isNotEmpty ? senderName : 'إدارة المدرسة',
        'imageUrl': imageUrl,
        'actionLink': actionLink,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _notifTitleController.clear();
      _notifBodyController.clear();
      _notifImageUrlController.clear();
      _notifActionLinkController.clear();

      _showSnackBar('تم بث الإشعار للطلاب بنجاح! 📢✅');
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء إرسال الإشعار: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSendingNotif = false);
    }
  }

  Future<void> _deleteNotification(String notifId) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').doc(notifId).delete();
      _showSnackBar('تم حذف الإشعار بنجاح 🗑️');
    } catch (e) {
      _showSnackBar('خطأ في حذف الإشعار: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'الإعدادات والإشعارات',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: scheme.surface,
          bottom: TabBar(
            labelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.tajawal(),
            tabs: const [
              Tab(icon: Icon(Icons.campaign_rounded), text: 'الإشعارات'),
              Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'الذكاء الاصطناعي'),
            ],
          ),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: TabBarView(
            children: [
              _buildNotificationsTab(scheme),
              _buildAiTab(scheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiTab(ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'إعدادات النماذج والمفاتيح',
                        style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _apiKeyController,
                    decoration: InputDecoration(
                      labelText: 'مفتاح OpenAI أو غيره (General API Key)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.key_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _geminiApiKeyController,
                    decoration: InputDecoration(
                      labelText: 'مفتاح Google Gemini API Key',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.vpn_key_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _aiModelController,
                    decoration: InputDecoration(
                      labelText: 'اسم النموذج (مثل gemini-1.5-flash)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.memory_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSavingAiConfig ? null : _saveAiSettings,
                      icon: _isSavingAiConfig 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_rounded),
                      label: Text('حفظ الإعدادات', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16)),
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
        ],
      ),
    );
  }

  Widget _buildNotificationsTab(ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.campaign, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'إرسال إشعار جديد',
                        style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notifTitleController,
                    decoration: InputDecoration(
                      labelText: 'عنوان الإشعار (مطلوب)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notifBodyController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'محتوى الإشعار (اختياري)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.text_fields_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _notifTargetGrade,
                          decoration: InputDecoration(
                            labelText: 'المستهدفون',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: ['الكل', 'الصف السابع', 'الصف الثامن', 'الصف التاسع']
                              .map((g) => DropdownMenuItem(value: g, child: Text(g, style: GoogleFonts.tajawal())))
                              .toList(),
                          onChanged: (v) => setState(() => _notifTargetGrade = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _notifType,
                          decoration: InputDecoration(
                            labelText: 'نوع الإشعار',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'general', child: Text('عام')),
                            DropdownMenuItem(value: 'alert', child: Text('تنبيه')),
                            DropdownMenuItem(value: 'success', child: Text('نجاح')),
                          ],
                          onChanged: (v) => setState(() => _notifType = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notifSenderController,
                    decoration: InputDecoration(
                      labelText: 'اسم المُرسِل',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notifImageUrlController,
                    decoration: InputDecoration(
                      labelText: 'رابط صورة مرفقة (اختياري)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.image_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notifActionLinkController,
                    decoration: InputDecoration(
                      labelText: 'رابط زر الإجراء (اختياري)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.link_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSendingNotif ? null : _sendBroadcastNotification,
                      icon: _isSendingNotif 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                      label: Text('بث الإشعار للطلاب', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
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
            'الإشعارات السابقة:',
            style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('notifications').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('لا توجد إشعارات سابقة.', style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final docId = docs[index].id;
                  final title = data['title'] ?? 'بدون عنوان';
                  final target = data['targetGrade'] ?? 'الكل';
                  
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Icon(Icons.campaign, color: Colors.orange.shade700),
                      ),
                      title: Text(title, style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                      subtitle: Text('المستهدفون: $target', style: GoogleFonts.tajawal(fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                        onPressed: () => _deleteNotification(docId),
                        tooltip: 'حذف الإشعار',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
