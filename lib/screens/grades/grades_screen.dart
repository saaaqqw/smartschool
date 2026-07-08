import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../services/firebase_service.dart';
import '../../core/stores/user_profile_store.dart';

const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

bool _isGeminiApiKeyConfigured() =>
    _geminiApiKey.isNotEmpty && _geminiApiKey != 'PUT_YOUR_GEMINI_API_KEY_HERE';

class GradeRow {
  const GradeRow({
    required this.subject,
    required this.score,
    required this.max,
    required this.color,
  });

  final String subject;
  final int score;
  final int max;
  final Color color;

  static Color getColorForSubject(String subject) {
    switch (subject) {
      case 'الرياضيات':
        return const Color(0xFF5C6BC0);
      case 'العلوم':
        return const Color(0xFF26A69A);
      case 'التربية الإسلامية':
        return const Color(0xFF7E57C2);
      case 'القرآن الكريم':
        return const Color(0xFF43A047);
      case 'اللغة العربية':
        return const Color(0xFFE53935);
      case 'اللغة الإنجليزية':
        return const Color(0xFF1E88E5);
      default:
        return Colors.blueGrey;
    }
  }
}

/// الدرجات — أشرطة تقدم + توصيات.
class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const GradesScreen(),
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
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  final _firebaseService = FirebaseService();
  String _aiRecommendations = '';
  bool _isAIRecommendationsLoading = false;
  bool _hasGeneratedAI = false;

  @override
  void initState() {
    super.initState();
    _initializeGradesIfNeeded();
  }

  Future<void> _initializeGradesIfNeeded() async {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('grades')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      final seeds = [
        {'subjectId': 'الرياضيات', 'score': 92.0, 'maxScore': 100.0},
        {'subjectId': 'العلوم', 'score': 88.0, 'maxScore': 100.0},
        {'subjectId': 'التربية الإسلامية', 'score': 95.0, 'maxScore': 100.0},
        {'subjectId': 'القرآن الكريم', 'score': 90.0, 'maxScore': 100.0},
        {'subjectId': 'اللغة العربية', 'score': 85.0, 'maxScore': 100.0},
        {'subjectId': 'اللغة الإنجليزية', 'score': 78.0, 'maxScore': 100.0},
      ];

      for (final g in seeds) {
        await _firebaseService.saveGrade(
          uid,
          g['subjectId'] as String,
          g['score'] as double,
          g['maxScore'] as double,
        );
      }
    }
  }

  Future<void> _generateAIRecommendations(List<GradeRow> grades) async {
    if (_hasGeneratedAI) return;
    _hasGeneratedAI = true;

    if (!_isGeminiApiKeyConfigured()) {
      setState(() {
        _aiRecommendations = '• لم يتم ضبط مفتاح Gemini API. لعرض نصائح ذكية حقيقية، يرجى تشغيل التطبيق بـ:\n'
            'flutter run --dart-define=GEMINI_API_KEY=your_key';
      });
      return;
    }

    setState(() => _isAIRecommendationsLoading = true);

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _geminiApiKey,
      );

      final gradesText = grades
          .map((g) => '${g.subject}: ${g.score}/${g.max}')
          .join('\n');

      final prompt = '''
أنت: مستشار أكاديمي ذكي لمساعدة الطلاب في تطبيق Smart School.
درجات الطالب الحالية هي:
$gradesText

بناءً على هذه الدرجات، قدم 3 توصيات ذكية ومبسطة باللغة العربية للتعلم والتحسين.
اكتب التوصيات كنقاط واضحة ومقنعة تبدأ بعلامة "•". ركز بشكل خاص على المواد التي حصل فيها الطالب على درجة أقل (مثل اللغة الإنجليزية 78) وشجعه على التميز في المواد الأخرى.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      if (mounted) {
        setState(() {
          _aiRecommendations = response.text ?? 'لم أستطع الحصول على نصائح ذكية حالياً.';
          _isAIRecommendationsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiRecommendations = 'فشل جلب النصائح الذكية: $e';
          _isAIRecommendationsLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = userProfileNotifier.value.uid;

    if (uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('الدرجات')),
        body: const Center(child: Text('يرجى تسجيل الدخول أولاً.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدرجات'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firebaseService.getGradesStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد درجات مسجلة حالياً.'));
          }

          final grades = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final subject = data['subjectId'] ?? '';
            return GradeRow(
              subject: subject,
              score: (data['score'] as num).toInt(),
              max: (data['maxScore'] as num).toInt(),
              color: GradeRow.getColorForSubject(subject),
            );
          }).toList();

          // Trigger AI advice asynchronously
          _generateAIRecommendations(grades);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text(
                'أداء المواد',
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              ...grades.map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GradeCard(row: g, scheme: scheme),
                  )),
              const Divider(height: 32),
              Text(
                'توصيات الذكاء الاصطناعي',
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                color: scheme.secondaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: scheme.onSecondaryContainer,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ملاحظات ذكية',
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isAIRecommendationsLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        Text(
                          _aiRecommendations.isNotEmpty
                              ? _aiRecommendations
                              : '• جاري تحليل الدرجات للحصول على نصائحك الذكية...',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSecondaryContainer.withValues(alpha: 0.95),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.row,
    required this.scheme,
  });

  final GradeRow row;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final ratio = row.score / row.max;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: row.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.subject,
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${row.score}/${row.max}',
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: row.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: row.color.withValues(alpha: 0.15),
                color: row.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
