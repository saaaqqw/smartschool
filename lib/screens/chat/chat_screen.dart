import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// Run: flutter run --dart-define=GEMINI_API_KEY=your_key_here
const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

bool _isGeminiApiKeyConfigured() =>
    _geminiApiKey.isNotEmpty && _geminiApiKey != 'PUT_YOUR_GEMINI_API_KEY_HERE';

/// Chat bot screen using Google Gemini (google_generative_ai).
///
/// - UI: modern chat bubbles (blue/white)
/// - Logic: Gemini 1.5 Flash acting as an educational assistant for students
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.subjectTitle,
  });

  /// Optional: title of the current subject/unit to provide context.
  final String? subjectTitle;

  static Route<void> route({String? subjectTitle}) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          ChatScreen(subjectTitle: subjectTitle),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
    );
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ChatSession? _chatSession;
  GenerativeModel? _model;

  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'مرحباً! أنا مساعدك التعليمي الذكي للطلاب. اكتب سؤالك وسأساعدك بطريقة واضحة خطوة بخطوة.',
      isUser: false,
    ),
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (_isGeminiApiKeyConfigured()) {
      final subjectContext = widget.subjectTitle;
      final systemInstructionText = [
        'أنت: مساعد تعليمي ذكي للطلاب في تطبيق Smart School.',
        'المهمة: اشرح بشكل مبسط ومنظم، وقدم أمثلة عند الحاجة.',
        'اللغة: افترض أن المستخدم يتحدث بالعربية، واستخدم العربية.',
        if (subjectContext != null && subjectContext.trim().isNotEmpty)
          'سياق المستخدم: ${subjectContext.trim()}. وجه الإجابة بما يناسب هذا الموضوع.'
      ].join('\n');

      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _geminiApiKey,
        systemInstruction: Content.system(systemInstructionText),
      );

      _chatSession = _model!.startChat(
        history: [
          Content.model([
            TextPart(
              'مرحباً! أنا مساعدك التعليمي الذكي للطلاب. اكتب سؤالك وسأساعدك بطريقة واضحة خطوة بخطوة.',
            )
          ])
        ],
      );
    }
  }

  Future<String> _generateReply(String userText) async {
    if (!_isGeminiApiKeyConfigured() || _chatSession == null) {
      return 'لم يُضبط مفتاح Gemini. شغّل التطبيق بـ:\n'
          'flutter run --dart-define=GEMINI_API_KEY=your_key';
    }

    final prompt = [
      'سؤال الطالب: $userText',
      'قدّم الإجابة في نقاط مرتبة قدر الإمكان. إذا كان السؤال يتطلب خطوة/حل، ابدأ بالخطوة الأولى ثم التالية.',
    ].join('\n');

    final response = await _chatSession!.sendMessage(Content.text(prompt));

    final text = response.text;
    return (text == null || text.trim().isEmpty)
        ? 'لم أستطع الحصول على رد حالياً، حاول مرة أخرى.'
        : text.trim();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final raw = _controller.text;
    final userText = raw.trim();
    if (userText.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: userText, isUser: true));
      _controller.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final reply = await _generateReply(userText);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: reply, isUser: false));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'حدث خطأ أثناء جلب الرد: $e',
            isUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: scheme.surfaceContainerLowest,
          surfaceTintColor: scheme.surfaceContainerLowest,
          title: Text(
            'مساعد Smart School',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: scheme.onSurface,
            ),
          ),
          centerTitle: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 14),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: scheme.primary,
              ),
            )
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < _messages.length) {
                      final msg = _messages[index];
                      return _MessageBubble(
                        text: msg.text,
                        isUser: msg.isUser,
                      );
                    }

                    // Loading indicator bubble
                    return _TypingBubble(color: scheme.primary);
                  },
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  border: Border(
                    top: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 5,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'اكتب سؤالك...',
                          hintStyle: GoogleFonts.tajawal(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: scheme.outline.withValues(alpha: 0.25),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: scheme.primary,
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _isLoading ? null : _sendMessage,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  color: scheme.onPrimary,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bubbleColor =
        isUser ? scheme.primary.withValues(alpha: 0.15) : Colors.white;
    final borderColor = isUser
        ? scheme.primary.withValues(alpha: 0.45)
        : scheme.outline.withValues(alpha: 0.18);

    final align = isUser ? Alignment.centerLeft : Alignment.centerRight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: align,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 6 : 18),
                bottomRight: Radius.circular(isUser ? 18 : 6),
              ),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                if (!isUser)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                text,
                textAlign: TextAlign.start,
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: isUser ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 26,
                  height: 18,
                  child: _DotsAnimation(color: color),
                ),
                const SizedBox(width: 8),
                Text(
                  'جارٍ الكتابة...',
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotsAnimation extends StatefulWidget {
  const _DotsAnimation({required this.color});

  final Color color;

  @override
  State<_DotsAnimation> createState() => _DotsAnimationState();
}

class _DotsAnimationState extends State<_DotsAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final scales = [
          _easeOut(t),
          _easeOut((t + 0.33) % 1),
          _easeOut((t + 0.66) % 1),
        ];

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (i) {
            return Transform.scale(
              scale: 0.6 + scales[i] * 0.7,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _easeOut(double x) {
    final v = x.clamp(0.0, 1.0);
    // simple ease
    return 1 - (1 - v) * (1 - v);
  }
}
