import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/ai_config_service.dart';

/// Chat bot screen using Groq Llama3 model.
///
/// - UI: modern chat bubbles (blue/white)
/// - Logic: Llama3-70b-8192 acting as an educational assistant for students
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
  }

  Future<String> _generateReply(String userText) async {
    // 1. توليد مفتاح فريد مشفر للكاش بناءً على نص السؤال والمادة
    final rawKey = 'ai_cache_${widget.subjectTitle ?? "general"}_$userText';
    final cacheKey = base64UrlEncode(utf8.encode(rawKey));

    // 2. التحقق من وجود إجابة مسبقة في الكاش المحلي (للسرعة وتوفير البيانات)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedResponse = prefs.getString(cacheKey);
      if (cachedResponse != null && cachedResponse.isNotEmpty) {
        return cachedResponse; // إرجاع الإجابة الفورية من الكاش!
      }
    } catch (e) {
      debugPrint('Cache read error: $e');
    }

    final prompt = [
      'أنت مساعد تعليمي ذكي للطلاب في تطبيق Smart School. اشرح لي دائماً باللغة العربية بشكل مبسط ومنظم.',
      if (widget.subjectTitle != null && widget.subjectTitle!.trim().isNotEmpty)
        'سياق دراستي الحالي هو: ${widget.subjectTitle!.trim()}. وجه إجاباتك بما يناسب هذا الموضوع.',
      'سؤال الطالب: $userText',
      'قدّم الإجابة في نقاط مرتبة قدر الإمكان. إذا كان السؤال يتطلب خطوة/حل، ابدأ بالخطوة الأولى ثم التالية.',
    ].join('\n');

    try {
      final apiKey = await AiConfigService.getApiKey();
      if (apiKey.isEmpty) {
        return '⚠️ عذراً، لم يتم إعداد مفتاح الذكاء الاصطناعي في قاعدة البيانات بعد. يرجى من مسؤول النظام إضافة المفتاح (apiKey) في Firestore في المسار (settings/ai_config).';
      }
      final modelName = await AiConfigService.getModelName();
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

      final body = {
        'model': modelName,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.7,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final content = decoded['choices'][0]['message']['content'] as String;
        final finalReply = content.trim();

        // 3. حفظ الإجابة الناجحة في الكاش للاستخدام المستقبلي
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, finalReply);
        } catch (e) {
          debugPrint('Cache save error: $e');
        }

        return finalReply;
      } else {
        debugPrint('Groq API Error: ${response.statusCode} - ${response.body}');
        return 'عذراً، فشل الحصول على رد حالياً. رمز الخطأ: ${response.statusCode}';
      }
    } catch (e) {
      return 'حدث خطأ أثناء الاتصال بالخادم: $e';
    }
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
