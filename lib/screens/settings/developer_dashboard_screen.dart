import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/subject_curriculum.dart';
import '../../services/database_cleanup_service.dart';
import '../../core/config/ai_config_service.dart';
import '../../core/config/developer_auth_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../core/stores/user_profile_store.dart';

/// نموذج يمثل سؤالاً مضافاً إلى القائمة المؤقتة قبل رفعه لـ Firestore
class TempQuestionItem {
  final String questionText;
  final List<String> options;
  final int correctIndex;

  TempQuestionItem({
    required this.questionText,
    required this.options,
    required this.correctIndex,
  });
}

/// لوحة تحكم المطور / المعلم لإدارة الدروس ومزامنتها مع Firebase
/// تتضمن القوائم المنسدلة المنسقة، حقول رابط الفيديو والملخص،
/// إضافة الأسئلة في قائمة مؤقتة وعرضها في ListTile، وحفظ التغييرات في Cloud Firestore.
class DeveloperDashboardScreen extends StatefulWidget {
  const DeveloperDashboardScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const DeveloperDashboardScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
    );
  }

  @override
  State<DeveloperDashboardScreen> createState() =>
      _DeveloperDashboardScreenState();
}

class _DeveloperDashboardScreenState extends State<DeveloperDashboardScreen> {
  final _formKey = GlobalKey<FormState>();

  int _dashboardTab = 0; // 0: إدارة الدروس، 1: بث الإشعارات
  final _notifTitleController = TextEditingController();
  final _notifBodyController = TextEditingController();
  final _notifSenderController = TextEditingController(text: 'إدارة المدرسة');
  final _notifImageUrlController = TextEditingController();
  final _notifActionLinkController = TextEditingController();
  String _notifTargetGrade = 'الكل';
  String _notifType = 'general';
  bool _isSendingNotif = false;

  // ── 1) القوائم المنسدلة (الصف، الفصل، المادة، الوحدة والدرس) ─────────────────────
  String _selectedGrade = 'الصف السابع';
  String _selectedSemester = 'الفصل الدراسي الأول';
  String _selectedSubject = kCoreSubjects.first.title;
  int _selectedUnitIndex = 0;
  int _selectedLessonNumber = 1;

  List<String> _gradeOptions = [
    'الصف السابع',
    'الصف الثامن',
    'الصف التاسع',
  ];

  final List<String> _semesterOptions = [
    'الفصل الدراسي الأول',
    'الفصل الدراسي الثاني',
  ];

  // ── حقول التحكم بمفتاح ونموذج الذكاء الاصطناعي ────────────────────────
  final _apiKeyController = TextEditingController();
  final _aiModelController = TextEditingController();
  bool _isSavingAiConfig = false;

  // ── حقول التحكم بالمشرفين وصلاحيات السحابة ────────────────────────
  final _adminUidController = TextEditingController();
  final _adminNameController = TextEditingController();
  bool _isSavingAdmin = false;

  // ── 2) حقول تفاصيل الدرس ورابط الفيديو والملخص واختيار الوحدة ─────────────
  final _unitTitleController = TextEditingController();
  final _lessonTitleController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _summaryTextController = TextEditingController();

  // ── 2.1) حقول ومتحكمات كتاب المادة الدراسي (Google Drive / PDF) ─────────────
  final _bookTitleController = TextEditingController();
  final _bookUrlController = TextEditingController();
  bool _isSavingBook = false;

  // ── 3) قائمة الأسئلة المؤقتة وحقول إدخال السؤال الجديد ──────────────────────
  final List<TempQuestionItem> _tempQuestionsList = [];

  final _qTextController = TextEditingController();
  final _qOptAController = TextEditingController();
  final _qOptBController = TextEditingController();
  final _qOptCController = TextEditingController();
  final _qOptDController = TextEditingController();
  int _qCorrectIndex = 0; // 0=أ, 1=ب, 2=ج, 3=د
  int? _editingQuestionIndex; // فهرس السؤال قيد التعديل في القائمة المحفوظة

  // ── حالات التحميل ────────────────────────────────────────────────────────
  bool _isPublishing = false;
  bool _isLoadingLessonFromDb = false;
  bool _isSavingQuestionToDb = false;

  @override
  void initState() {
    super.initState();
    _fetchGradesFromDatabase();
    _initSubjectData();
    _loadAiSettings();
    DatabaseCleanupService.cleanAllOnce();
  }

  Future<void> _fetchGradesFromDatabase() async {
    try {
      final db = FirebaseFirestore.instance;
      final snap = await db.collection('subjects').get();
      final Set<String> foundGrades = {
        'الصف الأول',
        'الصف الثاني',
        'الصف الثالث',
        'الصف الرابع',
        'الصف الخامس',
        'الصف السادس',
        'الصف السابع',
        'الصف الثامن',
        'الصف التاسع',
        'الصف العاشر',
        'الصف الحادي عشر',
        'الصف الثاني عشر',
      };

      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['grade'] is String && (data['grade'] as String).trim().isNotEmpty) {
          foundGrades.add((data['grade'] as String).trim());
        }
      }

      final sortedList = foundGrades.toList();
      final kGradeOrder = [
        'الصف الأول', 'الصف الثاني', 'الصف الثالث', 'الصف الرابع', 'الصف الخامس', 'الصف السادس',
        'الصف السابع', 'الصف الثامن', 'الصف التاسع', 'الصف العاشر', 'الصف الحادي عشر', 'الصف الثاني عشر'
      ];
      sortedList.sort((a, b) {
        final indexA = kGradeOrder.indexOf(a);
        final indexB = kGradeOrder.indexOf(b);
        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        if (indexA != -1) return -1;
        if (indexB != -1) return 1;
        return a.compareTo(b);
      });

      if (mounted) {
        setState(() {
          _gradeOptions = sortedList;
          if (!_gradeOptions.contains(_selectedGrade) && _gradeOptions.isNotEmpty) {
            _selectedGrade = _gradeOptions.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAiSettings() async {
    final key = await AiConfigService.getApiKey();
    final model = await AiConfigService.getModelName();
    if (mounted) {
      setState(() {
        _apiKeyController.text = key;
        _aiModelController.text = model;
      });
    }
  }

  Future<void> _saveAiSettings() async {
    final key = _apiKeyController.text.trim();
    final model = _aiModelController.text.trim();
    if (key.isEmpty || model.isEmpty) {
      _showSnackBar('يرجى إدخال المفتاح واسم النموذج أولاً ⚠️', isError: true);
      return;
    }
    setState(() => _isSavingAiConfig = true);
    try {
      await AiConfigService.updateAiConfig(apiKey: key, modelName: model);
      _showSnackBar('تم حفظ وتحديث إعدادات الذكاء الاصطناعي بنجاح 🤖✅');
    } catch (e) {
      _showSnackBar('خطأ أثناء حفظ إعدادات AI: $e ❌', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingAiConfig = false);
    }
  }

  Future<void> _saveNewAdmin() async {
    final uid = _adminUidController.text.trim();
    final name = _adminNameController.text.trim();
    if (uid.isEmpty) {
      _showSnackBar('يرجى إدخال معرف الحساب (UID) للمشرف أولاً', isError: true);
      return;
    }
    setState(() => _isSavingAdmin = true);
    try {
      await FirebaseFirestore.instance.collection('admins').doc(uid).set({
        'uid': uid,
        'name': name.isEmpty ? 'مشرف سحابي' : name,
        'addedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _adminUidController.clear();
      _adminNameController.clear();
      _showSnackBar('تمت إضافة المشرف بنجاح وتفعيل صلاحياته في السحابة');
    } catch (e) {
      _showSnackBar('تعذر إضافة المشرف: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingAdmin = false);
    }
  }

  Future<void> _deleteAdmin(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('سحب الصلاحية السحابية', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من رغبتك في حذف المشرف "$name" ($uid) وسحب كافة صلاحياته الإدارية من السحابة؟', style: GoogleFonts.tajawal(color: const Color(0xFF94A3B8))),
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
      await FirebaseFirestore.instance.collection('admins').doc(uid).delete();
      if (!mounted) return;
      _showSnackBar('تم حذف المشرف وسحب صلاحياته بنجاح');
    } catch (e) {
      _showSnackBar('تعذر حذف المشرف: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _aiModelController.dispose();
    _adminUidController.dispose();
    _adminNameController.dispose();
    _unitTitleController.dispose();
    _lessonTitleController.dispose();
    _videoUrlController.dispose();
    _summaryTextController.dispose();
    _bookTitleController.dispose();
    _bookUrlController.dispose();
    _qTextController.dispose();
    _qOptAController.dispose();
    _qOptBController.dispose();
    _qOptCController.dispose();
    _qOptDController.dispose();
    _notifTitleController.dispose();
    _notifBodyController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcastNotification() async {
    final title = _notifTitleController.text.trim();
    final body = _notifBodyController.text.trim();
    final senderName = _notifSenderController.text.trim();
    final imageUrl = _notifImageUrlController.text.trim();
    final actionLink = _notifActionLinkController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال عنوان الإشعار على الأقل.')),
      );
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
      // Keep sender controller as is for convenience

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم بث الإشعار للطلاب بنجاح! 📢✅'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء إرسال الإشعار: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSendingNotif = false);
    }
  }

  Future<void> _deleteBroadcastNotification(String notifId) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').doc(notifId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الإشعار بنجاح 🗑️'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حذف الإشعار: $e')),
      );
    }
  }

  Future<void> _initSubjectData() async {
    try {
      final db = FirebaseFirestore.instance;
      final subjectDocId = FirebaseSyncService.getSubjectDocId(
          _selectedSubject, _selectedGrade,
          semester: _selectedSemester);
      final subjSnap = await db.collection('subjects').doc(subjectDocId).get();
      List<Map<String, dynamic>> dbUnits = [];
      if (subjSnap.exists && subjSnap.data() != null) {
        final data = subjSnap.data()!;
        _bookTitleController.text = data['bookTitle'] as String? ?? '';
        _bookUrlController.text = data['bookUrl'] as String? ?? '';

        final unitsRaw = data['units'];
        final schoolSubject = kCoreSubjects.firstWhere(
            (s) => s.title == _selectedSubject,
            orElse: () => kCoreSubjects.first);
        if (unitsRaw is List) {
          for (int i = 0; i < unitsRaw.length; i++) {
            final u = unitsRaw[i];
            if (u is Map) {
              final map = Map<String, dynamic>.from(u);
              if (i < schoolSubject.units.length &&
                  (schoolSubject.subjectId == 'social' ||
                      schoolSubject.subjectId == 'quran' ||
                      schoolSubject.subjectId == 'islamic')) {
                map['title'] = schoolSubject.units[i].title;
              }
              dbUnits.add(map);
            }
          }
        }
        // التأكد من إضافة كافة فروع المنهج المقسمة في حال لم يتم إنشاؤها مسبقاً في المستند
        while (dbUnits.length < schoolSubject.units.length &&
            (schoolSubject.subjectId == 'social' ||
                schoolSubject.subjectId == 'quran' ||
                schoolSubject.subjectId == 'islamic')) {
          dbUnits.add({
            'index': dbUnits.length,
            'title': schoolSubject.units[dbUnits.length].title,
            'lessons': [],
          });
        }
      } else {
        _bookTitleController.clear();
        _bookUrlController.clear();
        final schoolSubject = kCoreSubjects.firstWhere(
            (s) => s.title == _selectedSubject,
            orElse: () => kCoreSubjects.first);
        if (schoolSubject.subjectId == 'social' ||
            schoolSubject.subjectId == 'quran' ||
            schoolSubject.subjectId == 'islamic') {
          for (int i = 0; i < schoolSubject.units.length; i++) {
            dbUnits.add({
              'index': i,
              'title': schoolSubject.units[i].title,
              'lessons': [],
            });
          }
        }
      }
      if (_selectedUnitIndex < dbUnits.length) {
        _unitTitleController.text =
            dbUnits[_selectedUnitIndex]['title'] as String? ?? '';
      } else {
        _unitTitleController.text = 'الوحدة ${_selectedUnitIndex + 1}';
      }
      await _loadLessonFromDb(_selectedLessonNumber, dbUnits);
    } catch (e) {
      debugPrint('Error init subject data: $e');
    }
  }

  Future<void> _saveBookDataToDb() async {
    final title = _bookTitleController.text.trim();
    final url = _bookUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال رابط الكتاب (Google Drive) أولاً.')),
      );
      return;
    }

    setState(() => _isSavingBook = true);
    try {
      final db = FirebaseFirestore.instance;
      final subjectDocId = FirebaseSyncService.getSubjectDocId(
          _selectedSubject, _selectedGrade,
          semester: _selectedSemester);

      await db.collection('subjects').doc(subjectDocId).set({
        'bookTitle': title.isEmpty ? 'كتاب $_selectedSubject — $_selectedSemester' : title,
        'bookUrl': url,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ رابط كتاب المادة لـ $_selectedSubject بنجاح! 📚✅'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ الكتاب: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSavingBook = false);
    }
  }

  Future<void> _deleteBookDataFromDb() async {
    setState(() => _isSavingBook = true);
    try {
      final db = FirebaseFirestore.instance;
      final subjectDocId = FirebaseSyncService.getSubjectDocId(
          _selectedSubject, _selectedGrade,
          semester: _selectedSemester);

      await db.collection('subjects').doc(subjectDocId).set({
        'bookTitle': FieldValue.delete(),
        'bookUrl': FieldValue.delete(),
      }, SetOptions(merge: true));

      _bookTitleController.clear();
      _bookUrlController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف رابط الكتاب من $_selectedSubject بنجاح.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حذف الكتاب: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSavingBook = false);
    }
  }

  Future<void> _loadLessonFromDb(int lessonNum,
      [List<Map<String, dynamic>>? providedUnits]) async {
    setState(() => _isLoadingLessonFromDb = true);
    try {
      final db = FirebaseFirestore.instance;
      final subjectDocId = FirebaseSyncService.getSubjectDocId(
          _selectedSubject, _selectedGrade,
          semester: _selectedSemester);

      String title = '';
      String video = '';
      String summary = '';
      _tempQuestionsList.clear();

      List<Map<String, dynamic>> dbUnits = providedUnits ?? [];
      final schoolSubject = kCoreSubjects.firstWhere(
          (s) => s.title == _selectedSubject,
          orElse: () => kCoreSubjects.first);
      if (dbUnits.isEmpty) {
        final subjSnap =
            await db.collection('subjects').doc(subjectDocId).get();
        if (subjSnap.exists && subjSnap.data() != null) {
          final unitsRaw = subjSnap.data()!['units'];
          if (unitsRaw is List) {
            for (int i = 0; i < unitsRaw.length; i++) {
              final u = unitsRaw[i];
              if (u is Map) {
                final map = Map<String, dynamic>.from(u);
                if (i < schoolSubject.units.length &&
                    (schoolSubject.subjectId == 'social' ||
                        schoolSubject.subjectId == 'quran' ||
                        schoolSubject.subjectId == 'islamic')) {
                  map['title'] = schoolSubject.units[i].title;
                }
                dbUnits.add(map);
              }
            }
          }
        }
      } else {
        for (int i = 0; i < dbUnits.length; i++) {
          if (i < schoolSubject.units.length &&
              (schoolSubject.subjectId == 'social' ||
                  schoolSubject.subjectId == 'quran' ||
                  schoolSubject.subjectId == 'islamic')) {
            dbUnits[i]['title'] = schoolSubject.units[i].title;
          }
        }
      }
      while (dbUnits.length < schoolSubject.units.length &&
          (schoolSubject.subjectId == 'social' ||
              schoolSubject.subjectId == 'quran' ||
              schoolSubject.subjectId == 'islamic')) {
        dbUnits.add({
          'index': dbUnits.length,
          'title': schoolSubject.units[dbUnits.length].title,
          'lessons': [],
        });
      }

      if (_selectedUnitIndex < dbUnits.length) {
        final lList = dbUnits[_selectedUnitIndex]['lessons'] as List? ?? [];
        if (lessonNum - 1 < lList.length && lList[lessonNum - 1] is Map) {
          final lData = lList[lessonNum - 1] as Map;
          title = lData['title'] as String? ?? '';
          video = lData['videoUrl'] as String? ?? '';
          summary = lData['summaryContent'] as String? ?? '';

          final qList = lData['questions'] as List? ?? [];
          for (final item in qList) {
            if (item is Map) {
              final qText = item['question'] as String? ?? '';
              final opts = List<String>.from(item['options'] ?? []);
              final correctIdx = (item['correctIndex'] as num?)?.toInt() ?? 0;
              if (qText.isNotEmpty && opts.length >= 2) {
                _tempQuestionsList.add(TempQuestionItem(
                  questionText: qText,
                  options: opts,
                  correctIndex: correctIdx,
                ));
              }
            }
          }
        }
      }

      _lessonTitleController.text = title;
      _videoUrlController.text = video;
      _summaryTextController.text = summary;
    } catch (e) {
      debugPrint('Error loading lesson $lessonNum: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLessonFromDb = false);
    }
  }

  // ── التحقق من صحة رابط الفيديو أو معرّف يوتيوب ─────────────────────────
  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال رابط الفيديو أو معرّف يوتيوب';
    }
    final trimmed = value.trim();
    final isYoutubeId = RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed);
    if (isYoutubeId) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasAbsolutePath ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      return 'يرجى إدخال رابط فيديو يوتيوب أو سحابي صحيح (يبدأ بـ http/https)';
    }
    return null;
  }

  // ── إضافة أو تحديث السؤال مباشرة في قاعدة البيانات Firestore ────────────────
  Future<void> _saveOrUpdateQuestionInFirestoreImmediately() async {
    final qText = _qTextController.text.trim();
    final optA = _qOptAController.text.trim();
    final optB = _qOptBController.text.trim();
    final optC = _qOptCController.text.trim();
    final optD = _qOptDController.text.trim();

    if (qText.isEmpty) {
      _showSnackBar('يرجى إدخال نص السؤال أولاً ⚠️', isError: true);
      return;
    }
    if (optA.isEmpty || optB.isEmpty) {
      _showSnackBar('يرجى إدخال الخيار (أ) والخيار (ب) على الأقل ⚠️',
          isError: true);
      return;
    }

    final newOptions = [
      optA,
      optB,
      optC.isNotEmpty ? optC : 'لا يوجد خيار (ج)',
      optD.isNotEmpty ? optD : 'لا يوجد خيار (د)',
    ];

    final newQuestionMap = {
      'question': qText,
      'options': newOptions,
      'correctIndex': _qCorrectIndex,
    };

    setState(() => _isSavingQuestionToDb = true);

    try {
      final db = FirebaseFirestore.instance;
      final subjectDocId = FirebaseSyncService.getSubjectDocId(
          _selectedSubject, _selectedGrade,
          semester: _selectedSemester);
      final subjectDocRef = db.collection('subjects').doc(subjectDocId);

      await db.runTransaction((tx) async {
        final snapshot = await tx.get(subjectDocRef);
        List<dynamic> unitsList = [];
        if (snapshot.exists && snapshot.data() != null) {
          unitsList =
              List<dynamic>.from(snapshot.data()!['units'] as List? ?? []);
        }
        final schoolSubject = kCoreSubjects.firstWhere(
            (s) => s.title == _selectedSubject,
            orElse: () => kCoreSubjects.first);
        if (unitsList.isEmpty) {
          if (schoolSubject.subjectId == 'social' ||
              schoolSubject.subjectId == 'quran' ||
              schoolSubject.subjectId == 'islamic') {
            for (int i = 0; i < schoolSubject.units.length; i++) {
              unitsList.add({
                'index': i,
                'title': schoolSubject.units[i].title,
                'lessons': [],
              });
            }
          } else {
            unitsList = [
              {'title': 'مقدمة المادة', 'lessons': []},
              {'title': 'الوحدة الأولى', 'lessons': []},
              {'title': 'الوحدة الثانية', 'lessons': []},
              {'title': 'الوحدة الثالثة', 'lessons': []},
            ];
          }
        }
        // التأكد من أن عناوين فروع المواد المقسمة محدثة دائماً وبدقة
        for (int i = 0; i < unitsList.length; i++) {
          if (i < schoolSubject.units.length &&
              (schoolSubject.subjectId == 'social' ||
                  schoolSubject.subjectId == 'quran' ||
                  schoolSubject.subjectId == 'islamic')) {
            if (unitsList[i] is Map) {
              final m = Map<String, dynamic>.from(unitsList[i] as Map);
              m['title'] = schoolSubject.units[i].title;
              unitsList[i] = m;
            }
          }
        }
        while (unitsList.length <= _selectedUnitIndex) {
          String fallbackTitle = _unitTitleController.text.trim().isNotEmpty
              ? _unitTitleController.text.trim()
              : 'الوحدة ${unitsList.length + 1}';
          if (unitsList.length < schoolSubject.units.length &&
              (schoolSubject.subjectId == 'social' ||
                  schoolSubject.subjectId == 'quran' ||
                  schoolSubject.subjectId == 'islamic')) {
            fallbackTitle = schoolSubject.units[unitsList.length].title;
          }
          unitsList.add({
            'index': unitsList.length,
            'title': fallbackTitle,
            'lessons': [],
          });
        }

        final unitMap =
            Map<String, dynamic>.from(unitsList[_selectedUnitIndex] as Map? ?? {});

        final lessonsList = List<dynamic>.from(unitMap['lessons'] as List? ?? []);
        final lessonIndex = _selectedLessonNumber - 1;
        while (lessonsList.length <= lessonIndex) {
          lessonsList.add({
            'title': 'الدرس ${lessonsList.length + 1}',
            'videoUrl': _videoUrlController.text.trim(),
            'summaryContent': _summaryTextController.text.trim(),
            'questions': [],
          });
        }

        final lessonMap =
            Map<String, dynamic>.from(lessonsList[lessonIndex] as Map? ?? {});
        final questionsList =
            List<dynamic>.from(lessonMap['questions'] as List? ?? []);

        if (_editingQuestionIndex != null &&
            _editingQuestionIndex! < questionsList.length) {
          questionsList[_editingQuestionIndex!] = newQuestionMap;
        } else {
          questionsList.add(newQuestionMap);
        }

        lessonMap['questions'] = questionsList;
        lessonsList[lessonIndex] = lessonMap;
        unitMap['lessons'] = lessonsList;
        unitsList[_selectedUnitIndex] = unitMap;

        tx.set(
            subjectDocRef,
            {
              'title': _selectedSubject,
              'grade': _selectedGrade,
              'semester': _selectedSemester,
              'units': unitsList,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });

      setState(() {
        if (_editingQuestionIndex != null &&
            _editingQuestionIndex! < _tempQuestionsList.length) {
          _tempQuestionsList[_editingQuestionIndex!] = TempQuestionItem(
            questionText: qText,
            options: newOptions,
            correctIndex: _qCorrectIndex,
          );
          _showSnackBar('تم تعديل وحفظ السؤال مباشرة في قاعدة البيانات بنجاح! ✅✨');
        } else {
          _tempQuestionsList.add(TempQuestionItem(
            questionText: qText,
            options: newOptions,
            correctIndex: _qCorrectIndex,
          ));
          _showSnackBar('تم إضافة وحفظ السؤال مباشرة في قاعدة البيانات بنجاح! 🚀✨');
        }

        _qTextController.clear();
        _qOptAController.clear();
        _qOptBController.clear();
        _qOptCController.clear();
        _qOptDController.clear();
        _qCorrectIndex = 0;
        _editingQuestionIndex = null;
      });
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء حفظ السؤال في الفايربيس: $e ❌',
          isError: true);
    } finally {
      if (mounted) setState(() => _isSavingQuestionToDb = false);
    }
  }

  void _cancelEditingQuestion() {
    setState(() {
      _editingQuestionIndex = null;
      _qTextController.clear();
      _qOptAController.clear();
      _qOptBController.clear();
      _qOptCController.clear();
      _qOptDController.clear();
      _qCorrectIndex = 0;
    });
  }

  Future<void> _deleteQuestionFromFirestoreImmediately(int index) async {
    if (index < 0 || index >= _tempQuestionsList.length) return;

    setState(() => _isSavingQuestionToDb = true);

    try {
      final db = FirebaseFirestore.instance;
      final subjectDocId = FirebaseSyncService.getSubjectDocId(
          _selectedSubject, _selectedGrade,
          semester: _selectedSemester);
      final subjectDocRef = db.collection('subjects').doc(subjectDocId);

      await db.runTransaction((tx) async {
        final snapshot = await tx.get(subjectDocRef);
        if (!snapshot.exists || snapshot.data() == null) return;

        final unitsList =
            List<dynamic>.from(snapshot.data()!['units'] as List? ?? []);
        if (_selectedUnitIndex >= unitsList.length) return;

        final unitMap =
            Map<String, dynamic>.from(unitsList[_selectedUnitIndex] as Map);
        final lessonsList = List<dynamic>.from(unitMap['lessons'] as List? ?? []);
        final lessonIndex = _selectedLessonNumber - 1;
        if (lessonIndex >= lessonsList.length) return;

        final lessonMap =
            Map<String, dynamic>.from(lessonsList[lessonIndex] as Map);
        final questionsList =
            List<dynamic>.from(lessonMap['questions'] as List? ?? []);

        if (index < questionsList.length) {
          questionsList.removeAt(index);
          lessonMap['questions'] = questionsList;
          lessonsList[lessonIndex] = lessonMap;
          unitMap['lessons'] = lessonsList;
          unitsList[_selectedUnitIndex] = unitMap;

          tx.set(
              subjectDocRef,
              {
                'units': unitsList,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        }
      });

      setState(() {
        if (index < _tempQuestionsList.length) {
          _tempQuestionsList.removeAt(index);
        }
        if (_editingQuestionIndex == index) {
          _cancelEditingQuestion();
        } else if (_editingQuestionIndex != null &&
            _editingQuestionIndex! > index) {
          _editingQuestionIndex = _editingQuestionIndex! - 1;
        }
      });

      _showSnackBar('تم حذف السؤال من قاعدة البيانات مباشرة بنجاح 🗑️✅');
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء حذف السؤال من الفايربيس: $e ❌',
          isError: true);
    } finally {
      if (mounted) setState(() => _isSavingQuestionToDb = false);
    }
  }

  Future<void> _deleteCurrentLessonFromDb() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('حذف الدرس من السحابة', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من رغبتك في حذف الدرس رقم "$_selectedLessonNumber" وكل محتوياته وأسئلته نهائياً؟', style: GoogleFonts.tajawal(color: const Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.tajawal(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف الدرس نهائياً', style: GoogleFonts.tajawal(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isPublishing = true);
    try {
      final db = FirebaseFirestore.instance;
      final subjectDocId = FirebaseSyncService.getSubjectDocId(
          _selectedSubject, _selectedGrade,
          semester: _selectedSemester);
      final subjectDocRef = db.collection('subjects').doc(subjectDocId);

      await db.runTransaction((tx) async {
        final snapshot = await tx.get(subjectDocRef);
        if (!snapshot.exists || snapshot.data() == null) return;

        final unitsList = List<dynamic>.from(snapshot.data()!['units'] as List? ?? []);
        if (_selectedUnitIndex >= unitsList.length) return;

        final unitMap = Map<String, dynamic>.from(unitsList[_selectedUnitIndex] as Map);
        final lessonsList = List<dynamic>.from(unitMap['lessons'] as List? ?? []);
        final lessonIndex = _selectedLessonNumber - 1;

        if (lessonIndex < lessonsList.length) {
          lessonsList.removeAt(lessonIndex);
          unitMap['lessons'] = lessonsList;
          unitsList[_selectedUnitIndex] = unitMap;

          tx.set(
            subjectDocRef,
            {
              'units': unitsList,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      });

      if (!mounted) return;
      _clearFormAfterPublish();
      _showSnackBar('تم حذف الدرس بنجاح من السحابة ✅');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('تعذر حذف الدرس: $e ❌', isError: true);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _deleteCurrentUnitFromDb() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('تحذير: حذف الوحدة بالكامل', style: GoogleFonts.tajawal(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text('سيتم مسح الوحدة رقم "${_selectedUnitIndex + 1}" وجميع الدروس والأسئلة التابعة لها نهائياً من مادة "$_selectedSubject"! هل تريد الاستمرار؟', style: GoogleFonts.tajawal(color: const Color(0xFFF8FAFC))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('تراجع', style: GoogleFonts.tajawal(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('نعم، حذف الوحدة بالكامل', style: GoogleFonts.tajawal(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isPublishing = true);
    try {
      final db = FirebaseFirestore.instance;
      final subjectDocId = FirebaseSyncService.getSubjectDocId(
          _selectedSubject, _selectedGrade,
          semester: _selectedSemester);
      final subjectDocRef = db.collection('subjects').doc(subjectDocId);

      await db.runTransaction((tx) async {
        final snapshot = await tx.get(subjectDocRef);
        if (!snapshot.exists || snapshot.data() == null) return;

        final unitsList = List<dynamic>.from(snapshot.data()!['units'] as List? ?? []);
        if (_selectedUnitIndex < unitsList.length) {
          unitsList.removeAt(_selectedUnitIndex);

          tx.set(
            subjectDocRef,
            {
              'units': unitsList,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      });

      if (!mounted) return;
      setState(() {
        _selectedUnitIndex = 0;
        _selectedLessonNumber = 1;
      });
      _clearFormAfterPublish();
      _showSnackBar('تم حذف الوحدة وجميع دروسها بنجاح من السحابة 🗑️✅');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('تعذر حذف الوحدة: $e ❌', isError: true);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  // ── 4) زر "حفظ التغييرات في Firebase" (المزامنة الشاملة) ────────────────────
  Future<void> _saveChangesToFirebase() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('يرجى التأكد من ملء الحقول المطلوبة بشكل صحيح ⚠️',
          isError: true);
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final db = FirebaseFirestore.instance;
      final subjectDocId = FirebaseSyncService.getSubjectDocId(
          _selectedSubject, _selectedGrade,
          semester: _selectedSemester);
      final lessonNumber = _selectedLessonNumber;
      final lessonTitle = _lessonTitleController.text.trim();
      final videoUrlStr = _videoUrlController.text.trim();
      final summaryText = _summaryTextController.text.trim();

      // المسار الاحترافي للمادة: subjects/{subjectDocId}
      final subjectDocRef = db.collection('subjects').doc(subjectDocId);

      // جلب المادة الحالية لتحديث مصفوفة الوحدات والدروس (units)
      final subjectSnapshot = await subjectDocRef.get();
      List<dynamic> unitsList = [];
      if (subjectSnapshot.exists && subjectSnapshot.data() != null) {
        final data = subjectSnapshot.data()!;
        unitsList = List<dynamic>.from(data['units'] as List? ?? []);
      }
      if (unitsList.isEmpty) {
        unitsList = [
          {'title': 'مقدمة المادة', 'lessons': []},
          {'title': 'الوحدة الأولى', 'lessons': []},
          {'title': 'الوحدة الثانية', 'lessons': []},
          {'title': 'الوحدة الثالثة', 'lessons': []},
        ];
      }
      while (unitsList.length <= _selectedUnitIndex) {
        unitsList.add({
          'title': _unitTitleController.text.trim().isNotEmpty
              ? _unitTitleController.text.trim()
              : 'الوحدة ${unitsList.length + 1}',
          'lessons': [],
        });
      }

      final unitMap = Map<String, dynamic>.from(unitsList[_selectedUnitIndex]);
      if (_unitTitleController.text.trim().isNotEmpty) {
        unitMap['title'] = _unitTitleController.text.trim();
      }

      final lessonsList = List<dynamic>.from(unitMap['lessons'] ?? []);
      while (lessonsList.length < lessonNumber) {
        lessonsList.add({
          'title': '',
          'videoUrl': '',
          'summaryContent': '',
          'questions': [],
        });
      }

      final cleanQuestionsList = _tempQuestionsList
          .map((q) => {
                'question': q.questionText,
                'options': q.options,
                'correctIndex': q.correctIndex,
              })
          .toList();

      lessonsList[lessonNumber - 1] = {
        'title': lessonTitle.isNotEmpty ? lessonTitle : 'الدرس $lessonNumber',
        'videoUrl': videoUrlStr,
        'summaryContent': summaryText,
        'questions': cleanQuestionsList,
      };

      unitMap['lessons'] = lessonsList;
      unitsList[_selectedUnitIndex] = unitMap;

      await subjectDocRef.set({
        'title': _selectedSubject,
        'grade': _selectedGrade,
        'semester': _selectedSemester,
        'units': unitsList,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSnackBar(
          'تم حفظ التغييرات في Firebase بنجاح! 🚀✨ (الدرس، الفيديو، الملخص، والأسئلة في خريطة units النظيفة)');
      _clearFormAfterPublish();
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء حفظ التغييرات في Firebase: $e ❌',
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  void _clearFormAfterPublish() {
    _initSubjectData();
    _lessonTitleController.clear();
    _videoUrlController.clear();
    _summaryTextController.clear();
    _qTextController.clear();
    _qOptAController.clear();
    _qOptBController.clear();
    _qOptCController.clear();
    _qOptDController.clear();
    _adminUidController.clear();
    _adminNameController.clear();
    setState(() {
      _qCorrectIndex = 0;
      _tempQuestionsList.clear();
    });
  }

  // ── استيراد أسئلة عبر ملف JSON ──
  void _showJsonImportDialog() {
    final jsonController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.data_object_rounded, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'استيراد أسئلة (JSON)',
                style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: jsonController,
            maxLines: 10,
            textDirection: TextDirection.ltr,
            style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: '[\n  {\n    "questionText": "سؤال؟",\n    "options": ["A","B","C","D"],\n    "correctIndex": 0\n  }\n]',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('إلغاء', style: GoogleFonts.tajawal(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              try {
                final jsonStr = jsonController.text.trim();
                if (jsonStr.isEmpty) return;
                final List<dynamic> parsedList = json.decode(jsonStr);
                int addedCount = 0;
                for (var item in parsedList) {
                  if (item is Map<String, dynamic>) {
                    final qText = item['questionText']?.toString() ?? '';
                    final optsList = item['options'] as List<dynamic>? ?? [];
                    final opts = optsList.map((e) => e.toString()).toList();
                    final cIndex = int.tryParse(item['correctIndex']?.toString() ?? '0') ?? 0;
                    if (qText.isNotEmpty && opts.isNotEmpty) {
                      setState(() {
                        _tempQuestionsList.add(TempQuestionItem(
                          questionText: qText,
                          options: opts,
                          correctIndex: cIndex,
                        ));
                      });
                      addedCount++;
                    }
                  }
                }
                Navigator.of(ctx).pop();
                _showSnackBar('تم استيراد $addedCount سؤال بنجاح! 📥', isError: false);
              } catch (e) {
                _showSnackBar('خطأ في تنسيق JSON. يرجى التأكد من صحة الكود.', isError: true);
              }
            },
            child: Text('استيراد الآن', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor:
            isError ? Colors.redAccent.shade700 : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showChangePinDialog(BuildContext context) {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final errorNotifier = ValueNotifier<String>('');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تغيير رمز دخول المطور',
                style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                style: GoogleFonts.tajawal(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'الرمز الحالي',
                  labelStyle: GoogleFonts.tajawal(color: const Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: newPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                style: GoogleFonts.tajawal(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'الرمز الجديد (4 أرقام فأكثر)',
                  labelStyle: GoogleFonts.tajawal(color: const Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                style: GoogleFonts.tajawal(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'تأكيد الرمز الجديد',
                  labelStyle: GoogleFonts.tajawal(color: const Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: errorNotifier,
                builder: (context, errorText, _) {
                  if (errorText.isEmpty) return const SizedBox.shrink();
                  return Text(
                    errorText,
                    style: GoogleFonts.tajawal(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('إلغاء', style: GoogleFonts.tajawal(color: const Color(0xFF94A3B8))),
          ),
          FilledButton(
            onPressed: () async {
              if (currentPinController.text.trim().isEmpty ||
                  newPinController.text.trim().isEmpty ||
                  confirmPinController.text.trim().isEmpty) {
                errorNotifier.value = 'يرجى تعبئة جميع الحقول';
                return;
              }
              final isCurrentValid = await DeveloperAuthService.verifyPin(currentPinController.text);
              if (!isCurrentValid) {
                errorNotifier.value = 'الرمز الحالي غير صحيح';
                return;
              }
              if (newPinController.text.trim().length < 4) {
                errorNotifier.value = 'الرمز الجديد يجب أن يكون 4 أرقام على الأقل';
                return;
              }
              if (newPinController.text.trim() != confirmPinController.text.trim()) {
                errorNotifier.value = 'الرمز الجديد وتأكيده غير متطابقين';
                return;
              }
              await DeveloperAuthService.changePin(newPinController.text.trim());
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم تحديث رمز دخول المطور بنجاح ✅', style: GoogleFonts.tajawal()),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: Text('حفظ الرمز', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0F172A);
    const cardBgColor = Color(0xFF1E293B);
    const borderColor = Color(0xFF334155);
    const accentColor = Color(0xFF10B981); // Emerald Green
    const textPrimary = Color(0xFFF8FAFC);
    const textSecondary = Color(0xFF94A3B8);

    final currentUserEmail = userProfileNotifier.value.email;
    final isSuperAdmin = DeveloperAuthService.isSuperAdmin(currentUserEmail);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBgColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: textPrimary),
        title: Row(
          children: [
            const Icon(Icons.school_rounded, color: accentColor, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'لوحة المطور / المعلم (إدارة الدروس)',
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded, color: accentColor),
              tooltip: 'تغيير رمز دخول المطور',
              onPressed: () => _showChangePinDialog(context),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: textSecondary),
            tooltip: 'تفريغ الحقول',
            onPressed: _clearFormAfterPublish,
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            if (isSuperAdmin)
              _buildDashboardTabSwitcher(cardBgColor, borderColor, accentColor, textPrimary, textSecondary),
            Expanded(
              child: (_dashboardTab == 1 && isSuperAdmin)
                  ? _buildBroadcastNotificationsTab(cardBgColor, borderColor, accentColor, textPrimary, textSecondary)
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
              // ══════════════════════════════════════════════════════════════
              // القسم الأول: قوائم منسدلة منسقة لاختيار المنهج
              // (الفصل الدراسي، الصف الدراسي، المادة، الوحدة والدرس)
              // ══════════════════════════════════════════════════════════════
              _buildSectionHeader(
                icon: Icons.auto_awesome_mosaic_rounded,
                title:
                    '1. تصنيف الدرس والمنهج الدراسي (قوائم من قاعدة البيانات)',
                accentColor: accentColor,
              ),
              const SizedBox(height: 12),
              if (_isLoadingLessonFromDb)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: LinearProgressIndicator(
                    color: Colors.amberAccent,
                    backgroundColor: Colors.transparent,
                    minHeight: 3.5,
                  ),
                ),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('subjects')
                    .doc(FirebaseSyncService.getSubjectDocId(
                        _selectedSubject, _selectedGrade,
                        semester: _selectedSemester))
                    .snapshots(),
                builder: (context, snapshot) {
                  List<Map<String, dynamic>> dbUnits = [];
                  if (snapshot.hasData &&
                      snapshot.data != null &&
                      snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    if (data != null && data['units'] is List) {
                      for (final item in (data['units'] as List)) {
                        if (item is Map) {
                          dbUnits.add(Map<String, dynamic>.from(item));
                        }
                      }
                    }
                  }
                  if (dbUnits.isEmpty) {
                    dbUnits = [
                      {'title': 'مقدمة المادة', 'lessons': []},
                      {'title': 'الوحدة الأولى', 'lessons': []},
                      {'title': 'الوحدة الثانية', 'lessons': []},
                      {'title': 'الوحدة الثالثة', 'lessons': []},
                    ];
                  }

                  if (_selectedUnitIndex > dbUnits.length) {
                    _selectedUnitIndex = 0;
                  }

                  List<Map<String, dynamic>> dbLessons = [];
                  if (_selectedUnitIndex < dbUnits.length) {
                    final lessonsRaw = dbUnits[_selectedUnitIndex]['lessons'];
                    if (lessonsRaw is List) {
                      for (final l in lessonsRaw) {
                        if (l is Map) {
                          dbLessons.add(Map<String, dynamic>.from(l));
                        }
                      }
                    }
                  }
                  final maxLessonOptions = (dbLessons.length + 2).clamp(10, 30);
                  if (_selectedLessonNumber > maxLessonOptions) {
                    _selectedLessonNumber = 1;
                  }

                  return Card(
                    color: cardBgColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: borderColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // الفصل الدراسي
                          _buildDropdownField<String>(
                            label: 'الفصل الدراسي',
                            value: _selectedSemester,
                            items: _semesterOptions,
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedSemester = v;
                                  _selectedUnitIndex = 0;
                                  _selectedLessonNumber = 1;
                                });
                                _initSubjectData();
                              }
                            },
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(height: 16),
                          // الصف الدراسي + المادة الدراسية
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdownField<String>(
                                  label: 'الصف الدراسي',
                                  value: _selectedGrade,
                                  items: _gradeOptions,
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _selectedGrade = v;
                                        _selectedUnitIndex = 0;
                                        _selectedLessonNumber = 1;
                                      });
                                      _initSubjectData();
                                    }
                                  },
                                  cardBgColor: cardBgColor,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildDropdownField<String>(
                                  label: 'المادة الدراسية',
                                  value: _selectedSubject,
                                  items: kCoreSubjects
                                      .map((s) => s.title)
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _selectedSubject = v;
                                        _selectedUnitIndex = 0;
                                        _selectedLessonNumber = 1;
                                      });
                                      _initSubjectData();
                                    }
                                  },
                                  cardBgColor: cardBgColor,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // بطاقة إدارة كتاب المادة (Google Drive / PDF)
                          _buildBookCard(cardBgColor, borderColor, textPrimary, textSecondary),
                          const SizedBox(height: 20),

                          // الوحدة الدراسية المجلوبة من قاعدة البيانات
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdownField<int>(
                                  label: 'الوحدة الدراسية (من قاعدة البيانات)',
                                  value: _selectedUnitIndex <= dbUnits.length
                                      ? _selectedUnitIndex
                                      : 0,
                                  items: List.generate(
                                      dbUnits.length + 1, (index) => index),
                                  itemLabelBuilder: (index) {
                                    if (index < dbUnits.length) {
                                      final t = dbUnits[index]['title']
                                              as String? ??
                                          '';
                                      return t.isNotEmpty
                                          ? t
                                          : 'الوحدة ${index + 1}';
                                    }
                                    return '+ إضافة وحدة جديدة (الوحدة ${dbUnits.length + 1})';
                                  },
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _selectedUnitIndex = v;
                                        if (v < dbUnits.length) {
                                          _unitTitleController.text =
                                              dbUnits[v]['title'] as String? ??
                                                  '';
                                        } else {
                                          _unitTitleController.text =
                                              'الوحدة ${dbUnits.length + 1}';
                                        }
                                        _selectedLessonNumber = 1;
                                      });
                                      _loadLessonFromDb(1, dbUnits);
                                    }
                                  },
                                  cardBgColor: cardBgColor,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // حقل تعديل اسم الوحدة وحفظه في قواعد البيانات + زر حذف الوحدة
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _buildTextFormField(
                                  label:
                                      'اسم الوحدة المحددة (تعديل وحفظ مباشرة في قاعدة البيانات)',
                                  controller: _unitTitleController,
                                  hint:
                                      'مثال: الوحدة الأولى: الأعداد النسبية وتطبيقاتها',
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  prefixIcon: const Icon(Icons.edit_note_rounded,
                                      color: Colors.amberAccent, size: 22),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.2),
                                ),
                                child: IconButton(
                                  onPressed: _isPublishing ? null : _deleteCurrentUnitFromDb,
                                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 26),
                                  tooltip: 'حذف هذه الوحدة بالكامل وجميع دروسها من السحابة',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // اختيار رقم الدرس والدروس المتاحة في قاعدة البيانات + عنوان الدرس
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildDropdownField<int>(
                                label: 'اختر الدرس (من قاعدة البيانات)',
                                value: _selectedLessonNumber <= maxLessonOptions
                                    ? _selectedLessonNumber
                                    : 1,
                                items: List.generate(
                                    maxLessonOptions, (index) => index + 1),
                                itemLabelBuilder: (n) {
                                  if (n <= dbLessons.length) {
                                    final t = dbLessons[n - 1]['title']
                                            as String? ??
                                        '';
                                    return t.isNotEmpty
                                        ? 'الدرس $n: $t'
                                        : 'الدرس رقم $n';
                                  }
                                  return '+ إضافة الدرس $n (جديد)';
                                },
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _selectedLessonNumber = v);
                                    _loadLessonFromDb(v, dbUnits);
                                  }
                                },
                                cardBgColor: cardBgColor,
                                borderColor: borderColor,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                              const SizedBox(height: 14),
                              _buildTextFormField(
                                label: 'عنوان الدرس (اسم الموضوع)',
                                controller: _lessonTitleController,
                                hint: 'مثال: سورة الفاتحة / قوانين نيوتن',
                                validator: (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'يرجى إدخال عنوان الدرس'
                                        : null,
                                borderColor: borderColor,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // ══════════════════════════════════════════════════════════════
              // القسم الثاني: رابط الفيديو وملخص الدرس
              // ══════════════════════════════════════════════════════════════
              _buildSectionHeader(
                icon: Icons.video_library_rounded,
                title: '2. رابط فيديو الدرس وملخص المحتوى',
                accentColor: accentColor,
              ),
              const SizedBox(height: 12),
              Card(
                color: cardBgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // حقل رابط فيديو الدرس
                      _buildTextFormField(
                        label: 'رابط فيديو الدرس (يوتيوب أو رابط مباشر)',
                        controller: _videoUrlController,
                        hint: 'مثال: dQw4w9WgXcQ أو الرابط الكامل https://...',
                        validator: _validateUrl,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        prefixIcon: const Icon(Icons.link_rounded,
                            color: accentColor, size: 20),
                      ),
                      const SizedBox(height: 18),

                      // حقل نص الملخص الشامل
                      _buildTextFormField(
                        label: 'نص الملخص الشامل وشرح النقاط الرئيسية',
                        controller: _summaryTextController,
                        maxLines: 4,
                        hint:
                            'أدخل أهم الملاحظات والقوانين التي تظهر للطالب في ملخص الدرس...',
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ══════════════════════════════════════════════════════════════
              // القسم الثالث: إضافة الأسئلة وحفظها داخل قائمة مؤقتة وعرضها في ListTile
              // ══════════════════════════════════════════════════════════════
              _buildSectionHeader(
                icon: Icons.quiz_rounded,
                title: '3. منشئ الأسئلة (إضافة الإجابات وحفظها في قائمة مؤقتة)',
                accentColor: accentColor,
              ),
              const SizedBox(height: 12),
              Card(
                color: cardBgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'أدخل نص السؤال والخيارات ثم اضغط "إضافة السؤال إلى القائمة المؤقتة (+)" لحفظه قبل الرفع.',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // نص السؤال
                      _buildTextFormField(
                        label: 'نص السؤال',
                        controller: _qTextController,
                        hint: 'مثال: ما هو حكم النون الساكنة إذا جاء بعدها حرف الباء؟',
                        maxLines: 2,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 16),

                      // الخيارات والإجابة الصحيحة
                      Text(
                        'خيارات الإجابة وتحديد الخيار الصحيح (اختر الدائرة بجانب الجواب الصحيح):',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _buildOptionInputRow(
                        index: 0,
                        letter: 'أ',
                        controller: _qOptAController,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accentColor: accentColor,
                      ),
                      const SizedBox(height: 8),
                      _buildOptionInputRow(
                        index: 1,
                        letter: 'ب',
                        controller: _qOptBController,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accentColor: accentColor,
                      ),
                      const SizedBox(height: 8),
                      _buildOptionInputRow(
                        index: 2,
                        letter: 'ج',
                        controller: _qOptCController,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accentColor: accentColor,
                      ),
                      const SizedBox(height: 8),
                      _buildOptionInputRow(
                        index: 3,
                        letter: 'د',
                        controller: _qOptDController,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accentColor: accentColor,
                      ),
                      const SizedBox(height: 18),

                      // زر الإضافة أو الحفظ المباشر في قاعدة البيانات
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSavingQuestionToDb
                                  ? null
                                  : _saveOrUpdateQuestionInFirestoreImmediately,
                              icon: _isSavingQuestionToDb
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: accentColor),
                                    )
                                  : Icon(
                                      _editingQuestionIndex != null
                                          ? Icons.check_circle_rounded
                                          : Icons.add_circle_rounded,
                                      color: _editingQuestionIndex != null
                                          ? Colors.amberAccent
                                          : accentColor,
                                      size: 22,
                                    ),
                              label: Text(
                                _editingQuestionIndex != null
                                    ? 'حفظ تعديل السؤال في قاعدة البيانات مباشرة (✓)'
                                    : 'حفظ وإضافة السؤال مباشرة إلى قاعدة البيانات (+)',
                                style: GoogleFonts.tajawal(
                                  color: _editingQuestionIndex != null
                                      ? Colors.amberAccent
                                      : accentColor,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: _editingQuestionIndex != null
                                        ? Colors.amberAccent
                                        : accentColor,
                                    width: 1.5),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: (_editingQuestionIndex != null
                                        ? Colors.amberAccent
                                        : accentColor)
                                    .withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          if (_editingQuestionIndex != null) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _isSavingQuestionToDb
                                  ? null
                                  : _cancelEditingQuestion,
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.redAccent, size: 20),
                              label: Text(
                                'إلغاء التعديل (✕)',
                                style: GoogleFonts.tajawal(
                                  color: Colors.redAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Colors.redAccent, width: 1.5),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor:
                                    Colors.redAccent.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showJsonImportDialog,
                  icon: const Icon(Icons.data_object_rounded, color: Colors.blueAccent, size: 20),
                  label: Text(
                    'استيراد أسئلة متعددة عبر نص JSON 📥',
                    style: GoogleFonts.tajawal(
                      color: Colors.blueAccent,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blueAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── عرض الأسئلة المحفوظة في قاعدة البيانات للدرس الحالي في ListTile ──────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt_rounded,
                        color: Colors.amberAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الأسئلة المحفوظة في قاعدة البيانات لهذا الدرس (${_tempQuestionsList.length}):',
                        style: GoogleFonts.tajawal(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_tempQuestionsList.isEmpty)
                Card(
                  color: cardBgColor.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'لم يتم إضافة وحفظ أسئلة في قاعدة البيانات لهذا الدرس بعد. استخدم النموذج بالأعلى لإضافة أسئلة الدرس طوالي.',
                        style: GoogleFonts.tajawal(
                          color: textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tempQuestionsList.length,
                  itemBuilder: (context, index) {
                    final q = _tempQuestionsList[index];
                    final letters = ['أ', 'ب', 'ج', 'د'];
                    final isEditingThis = _editingQuestionIndex == index;
                    return Card(
                      color: isEditingThis
                          ? Colors.amber.withValues(alpha: 0.15)
                          : cardBgColor,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isEditingThis
                              ? Colors.amberAccent
                              : accentColor.withValues(alpha: 0.4),
                          width: isEditingThis ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: isEditingThis
                                      ? Colors.amberAccent
                                      : accentColor,
                                  foregroundColor: isEditingThis
                                      ? Colors.black
                                      : Colors.white,
                                  radius: 16,
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.tajawal(
                                        fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    q.questionText,
                                    style: GoogleFonts.tajawal(
                                      color: textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded,
                                          color: Colors.amberAccent, size: 20),
                                      tooltip: 'تعديل هذا السؤال في قاعدة البيانات',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      onPressed: () {
                                        setState(() {
                                          _qTextController.text = q.questionText;
                                          _qOptAController.text =
                                              q.options.isNotEmpty ? q.options[0] : '';
                                          _qOptBController.text =
                                              q.options.length > 1 ? q.options[1] : '';
                                          _qOptCController.text =
                                              q.options.length > 2 ? q.options[2] : '';
                                          _qOptDController.text =
                                              q.options.length > 3 ? q.options[3] : '';
                                          _qCorrectIndex = q.correctIndex;
                                          _editingQuestionIndex = index;
                                        });
                                        _showSnackBar(
                                            'قم بتعديل السؤال في الحقول أعلاه ثم اضغط على "حفظ تعديل السؤال في قاعدة البيانات مباشرة (✓)" ✏️');
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded,
                                          color: Colors.redAccent, size: 20),
                                      tooltip: 'حذف السؤال مباشرة من قاعدة البيانات',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      onPressed: () =>
                                          _deleteQuestionFromFirestoreImmediately(index),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'الخيارات: ${q.options.asMap().entries.map((e) => "(${letters[e.key]}) ${e.value}").join("  |  ")}',
                              style: GoogleFonts.tajawal(
                                color: textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '✔ الإجابة الصحيحة: (${letters[q.correctIndex]}) ${q.options[q.correctIndex]}',
                                style: GoogleFonts.tajawal(
                                  color: accentColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 32),

              // ══════════════════════════════════════════════════════════════
              // القسم الرابع: زر حفظ التغييرات في Firebase
              // ══════════════════════════════════════════════════════════════
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilledButton.icon(
                  onPressed: _isPublishing ? null : _saveChangesToFirebase,
                  icon: _isPublishing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 24),
                  label: Text(
                    _isPublishing
                        ? 'جاري حفظ التغييرات ومزامنة الدرس...'
                        : 'حفظ التغييرات في Firebase (الدرس والملخص والأسئلة)',
                    style: GoogleFonts.tajawal(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: accentColor.withValues(alpha: 0.4),
                    minimumSize: const Size.fromHeight(60),
                    elevation: 6,
                    shadowColor: accentColor.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton.icon(
                  onPressed: _isPublishing ? null : _deleteCurrentLessonFromDb,
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 22),
                  label: Text(
                    '🗑️ حذف هذا الدرس نهائياً من السحابة (مع أسئلته وملخصه)',
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── قسم إعدادات الذكاء الاصطناعي ────────────────────────────────
              if (isSuperAdmin) ...[
                _buildSectionHeader(
                icon: Icons.smart_toy_rounded,
                title: 'إعدادات الذكاء الاصطناعي (AI Config & Groq Key)',
                accentColor: const Color(0xFF10B981),
              ),
              const SizedBox(height: 12),
              Card(
                color: cardBgColor,
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: borderColor, width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'يمكنك التحكم في مفتاح Groq API واسم نموذج الـ Llama التفاعلي من السحابة مباشرة دون إعادة تحديث التطبيق للمتجر:',
                        style: GoogleFonts.tajawal(
                          fontSize: 13.5,
                          color: textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        label: 'مفتاح Groq API Key:',
                        controller: _apiKeyController,
                        hint: 'gsk_xxxxxxxxx...',
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(height: 14),
                      _buildTextFormField(
                        label: 'اسم نموذج الذكاء الاصطناعي:',
                        controller: _aiModelController,
                        hint: 'llama-3.3-70b-versatile',
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        prefixIcon: const Icon(Icons.psychology_rounded, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSavingAiConfig ? null : _saveAiSettings,
                          icon: _isSavingAiConfig
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_as_rounded, size: 20),
                          label: Text(
                            _isSavingAiConfig ? 'جاري الحفظ في السحابة...' : 'حفظ إعدادات الذكاء الاصطناعي 🤖',
                            style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ],

              const SizedBox(height: 24),
              // ── قسم إدارة المشرفين والصلاحيات ────────────────────────────────
              if (isSuperAdmin) ...[
                _buildSectionHeader(
                icon: Icons.admin_panel_settings_rounded,
                title: 'إدارة المشرفين والصلاحيات السحابية (Admins)',
                accentColor: const Color(0xFF3B82F6), // Blue Accent
              ),
              const SizedBox(height: 12),
              Card(
                color: cardBgColor,
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: borderColor, width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'يمكنك إضافة معرفات الحسابات (UID) للمشرفين والمعلمين ليتمكنوا من تعديل الدروس وإدارة المحتوى من السحابة مباشرة:',
                        style: GoogleFonts.tajawal(
                          fontSize: 13.5,
                          color: textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        label: 'معرف المشرف (User UID):',
                        controller: _adminUidController,
                        hint: 'a1b2c3d4e5f6...',
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        prefixIcon: const Icon(Icons.badge_rounded, color: Color(0xFF3B82F6)),
                      ),
                      const SizedBox(height: 14),
                      _buildTextFormField(
                        label: 'اسم المشرف / الوصف:',
                        controller: _adminNameController,
                        hint: 'أستاذ محمد - مشرف العلوم',
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF3B82F6)),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSavingAdmin ? null : _saveNewAdmin,
                          icon: _isSavingAdmin
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.person_add_alt_1_rounded, size: 20),
                          label: Text(
                            _isSavingAdmin ? 'جاري إضافة المشرف...' : 'إضافة وتفعيل صلاحيات المشرف 🚀',
                            style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'قائمة المشرفين المعتمدين حالياً في قاعدة البيانات:',
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('admins').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Text('تعذر تحميل القائمة: ${snapshot.error}', style: GoogleFonts.tajawal(color: Colors.redAccent, fontSize: 13));
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                          }
                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'لا يوجد مشرفون مضافون بعد عبر هذه القائمة (يعتمد النظام حالياً على قائمة البريد الافتراضية).',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.tajawal(color: textSecondary, fontSize: 13),
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>? ?? {};
                              final uid = docs[index].id;
                              final name = data['name'] as String? ?? 'مشرف سحابي';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.verified_user_rounded, color: Color(0xFF3B82F6), size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.tajawal(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Text(
                                            'UID: $uid',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.tajawal(color: textSecondary, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                                      tooltip: 'سحب الصلاحية',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(6),
                                      onPressed: () => _deleteAdmin(uid, name),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
          ],
        ),
      ),
    );
  }

  // ── مكونات مساعدة لبناء واجهة جميلة للمطور ────────────────────────────

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.tajawal(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFF8FAFC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T)? itemLabelBuilder,
    required Color cardBgColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.tajawal(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          dropdownColor: cardBgColor,
          isExpanded: true,
          style: GoogleFonts.tajawal(
            color: textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            fillColor: const Color(0xFF0F172A),
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF10B981), width: 1.5),
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabelBuilder != null
                    ? itemLabelBuilder(item)
                    : item.toString(),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    Widget? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.tajawal(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.tajawal(
            color: textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.tajawal(
                color: const Color(0xFF64748B), fontSize: 13.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            fillColor: const Color(0xFF0F172A),
            filled: true,
            prefixIcon: prefixIcon,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF10B981), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.redAccent.shade700),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.redAccent.shade700, width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildOptionInputRow({
    required int index,
    required String letter,
    required TextEditingController controller,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color accentColor,
  }) {
    return Row(
      children: [
        // ignore: deprecated_member_use
        Radio<int>(
          value: index,
          // ignore: deprecated_member_use
          groupValue: _qCorrectIndex,
          activeColor: accentColor,
          // ignore: deprecated_member_use
          onChanged: (v) {
            if (v != null) setState(() => _qCorrectIndex = v);
          },
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _buildTextFormField(
            label: 'الخيار ($letter)',
            controller: controller,
            hint: 'أدخل نص الخيار ($letter)',
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBookCard(
    Color cardBgColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📖 إدارة كتاب المادة (Google Drive / PDF)',
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'أدخل عنوان الكتاب ورابط المشاهدة أو التحميل ليظهر للطلاب في المادة',
                      style: GoogleFonts.tajawal(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextFormField(
            label: 'عنوان الكتاب المخصص (اختياري)',
            controller: _bookTitleController,
            hint: 'مثال: كتاب الرياضيات - الجزء الثاني',
            prefixIcon: Icon(Icons.title_rounded, color: textSecondary, size: 20),
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 12),
          _buildTextFormField(
            label: 'رابط Google Drive (أو رابط PDF مباشر)',
            controller: _bookUrlController,
            hint: 'https://drive.google.com/file/d/.../view?usp=sharing',
            prefixIcon: Icon(Icons.add_link_rounded, color: textSecondary, size: 20),
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSavingBook ? null : _saveBookDataToDb,
                  icon: _isSavingBook
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(
                    'حفظ وربط الكتاب بالمادة',
                    style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _isSavingBook ? null : _deleteBookDataFromDb,
                tooltip: 'حذف كتاب المادة الحالي',
                icon: const Icon(Icons.delete_outline_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.12),
                  foregroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTabSwitcher(
    Color cardBgColor,
    Color borderColor,
    Color accentColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _dashboardTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _dashboardTab == 0 ? accentColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 20,
                      color: _dashboardTab == 0 ? Colors.white : textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '📚 إدارة المناهج والدروس',
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _dashboardTab == 0 ? Colors.white : textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _dashboardTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _dashboardTab == 1 ? Colors.red.shade600 : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.campaign_rounded,
                      size: 20,
                      color: _dashboardTab == 1 ? Colors.white : textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '📢 مركز بث الإشعارات للطلاب',
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _dashboardTab == 1 ? Colors.white : textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastNotificationsTab(
    Color cardBgColor,
    Color borderColor,
    Color accentColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.shade600.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.send_rounded, color: Colors.red.shade400, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إرسال إشعار فوري جديد للطلاب',
                          style: GoogleFonts.tajawal(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'سيصل هذا الإشعار فوراً إلى مركز إشعارات الطلاب وأيقونة التنبيه بالصفحة الرئيسية.',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _notifTitleController,
                style: GoogleFonts.tajawal(color: textPrimary, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'عنوان الإشعار (مثال: تنبيه هام من إدارة المدرسة)',
                  labelStyle: GoogleFonts.tajawal(color: textSecondary),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notifBodyController,
                maxLines: 4,
                style: GoogleFonts.tajawal(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'نص الإشعار التفصيلي والتعليمات...',
                  labelStyle: GoogleFonts.tajawal(color: textSecondary),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notifSenderController,
                style: GoogleFonts.tajawal(color: textPrimary, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'اسم المُرسل (مثال: إدارة المدرسة)',
                  labelStyle: GoogleFonts.tajawal(color: textSecondary),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notifImageUrlController,
                style: GoogleFonts.tajawal(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'رابط صورة توضيحية (اختياري)',
                  labelStyle: GoogleFonts.tajawal(color: textSecondary),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notifActionLinkController,
                style: GoogleFonts.tajawal(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'رابط تحويل (اختياري - يفتح عند الضغط)',
                  labelStyle: GoogleFonts.tajawal(color: textSecondary),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الفئة المستهدفة:', style: GoogleFonts.tajawal(color: textSecondary, fontSize: 13)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _notifTargetGrade,
                              isExpanded: true,
                              dropdownColor: cardBgColor,
                              style: GoogleFonts.tajawal(color: textPrimary, fontWeight: FontWeight.w700),
                              items: ['الكل', 'الصف السابع', 'الصف الثامن', 'الصف التاسع', 'الصف العاشر', 'الصف الحادي عشر', 'الصف الثاني عشر']
                                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _notifTargetGrade = v);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('أهمية ونوع الإشعار:', style: GoogleFonts.tajawal(color: textSecondary, fontSize: 13)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _notifType,
                              isExpanded: true,
                              dropdownColor: cardBgColor,
                              style: GoogleFonts.tajawal(color: textPrimary, fontWeight: FontWeight.w700),
                              items: const [
                                DropdownMenuItem(value: 'general', child: Text('🔵 تنبيه عام')),
                                DropdownMenuItem(value: 'urgent', child: Text('🔴 تنبيه عاجل وهام')),
                                DropdownMenuItem(value: 'study', child: Text('🟡 تنبيه دراسي / أكاديمي')),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _notifType = v);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSendingNotif ? null : _sendBroadcastNotification,
                  icon: _isSendingNotif
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.podcasts_rounded, size: 22),
                  label: Text(
                    'إرسال وبث الإشعار للطلاب الآن',
                    style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'قائمة الإشعارات المرتسلَة السابقة (السحابية):',
          style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .orderBy('createdAt', descending: true)
              .limit(30)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('خطأ في تحميل الإشعارات السابقة', style: GoogleFonts.tajawal(color: textSecondary)));
            }
            if (!snapshot.hasData) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: cardBgColor, borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: Text('لم يتم إرسال أي إشعارات حتى الآن', style: GoogleFonts.tajawal(color: textSecondary)),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final title = data['title'] ?? 'بدون عنوان';
                final body = data['body'] ?? '';
                final target = data['targetGrade'] ?? 'الكل';
                final type = data['type'] ?? 'general';

                Color badgeColor = Colors.blue.shade400;
                if (type == 'urgent') badgeColor = Colors.red.shade400;
                if (type == 'study') badgeColor = Colors.amber.shade400;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 48,
                        decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(6)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title.toString(),
                                    style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    target.toString(),
                                    style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                                  ),
                                ),
                              ],
                            ),
                            if (body.toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                body.toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.tajawal(fontSize: 13, color: textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        tooltip: 'حذف الإشعار من السحابة',
                        onPressed: () => _deleteBroadcastNotification(doc.id),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
