import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// مشغل يوتيوب السينمائي الذكي داخل التطبيق.
/// - يدعم نظام التشغيل الذكي بالطلب (Lazy-Loading Shimmer Poster) لتفادي ثقل الـ WebView عند التمرير.
/// - يتضمن إطار سينمائي متوهج متصل بلون المادة وترويسة جودة عالية مع خيار فتح خارجي.
/// - يدعم التغيير الديناميكي لـ [videoId] بسلاسة تامة.
class YoutubeLessonPlayer extends StatefulWidget {
  const YoutubeLessonPlayer({
    super.key,
    required this.videoId,
    this.autoPlay = false,
    this.mute = false,
    this.subjectColor = const Color(0xFF6366F1),
    this.lessonTitle = '',
    this.onFullScreenChange,
  });

  final String videoId;
  final bool autoPlay;
  final bool mute;
  final Color subjectColor;
  final String lessonTitle;
  final void Function(bool isFullScreen)? onFullScreenChange;

  @override
  State<YoutubeLessonPlayer> createState() => _YoutubeLessonPlayerState();
}

class _YoutubeLessonPlayerState extends State<YoutubeLessonPlayer> {
  YoutubePlayerController? _controller;
  bool _loading = false;
  bool _hasUserTappedPlay = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) {
      _startPlaying();
    }
  }

  void _onPlayerStateChange() {
    if (!mounted || _controller == null) return;
    if (widget.onFullScreenChange != null) {
      widget.onFullScreenChange!(_controller!.value.isFullScreen);
    }
  }

  void _startPlaying() {
    final cleanId =
        YoutubePlayer.convertUrlToId(widget.videoId) ?? widget.videoId;
    _controller = YoutubePlayerController(
      initialVideoId: cleanId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: widget.mute,
        hideControls: false,
        disableDragSeek: false,
        forceHD: true,
      ),
    );
    _controller!.addListener(_onPlayerStateChange);
    setState(() {
      _hasUserTappedPlay = true;
      _loading = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  void didUpdateWidget(covariant YoutubeLessonPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      if (_hasUserTappedPlay && _controller != null) {
        setState(() => _loading = true);
        try {
          final cleanId =
              YoutubePlayer.convertUrlToId(widget.videoId) ?? widget.videoId;
          _controller!.load(cleanId);
        } catch (_) {}
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _loading = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerStateChange);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openExternalYoutube() async {
    final cleanId =
        YoutubePlayer.convertUrlToId(widget.videoId) ?? widget.videoId;
    final uri = Uri.parse('https://www.youtube.com/watch?v=$cleanId');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح رابط اليوتيوب.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الفتح: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanId =
        YoutubePlayer.convertUrlToId(widget.videoId) ?? widget.videoId;

    if (!_hasUserTappedPlay || _controller == null) {
      return _buildCinemaPosterContainer(cleanId);
    }

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: widget.subjectColor,
        topActions: [
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.lessonTitle.isNotEmpty ? widget.lessonTitle : 'فيديو الدرس',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      builder: (context, player) {
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: widget.subjectColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.subjectColor.withValues(alpha: 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: _loading
                  ? Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: CircularProgressIndicator(color: widget.subjectColor),
                      ),
                    )
                  : player,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCinemaPosterContainer(String cleanId) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: _startPlaying,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.subjectColor.withValues(alpha: 0.38),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.subjectColor.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── صورة الغلاف عالية الدقة ────────────────────────────────
                Image.network(
                  'https://img.youtube.com/vi/$cleanId/maxresdefault.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.network(
                      'https://img.youtube.com/vi/$cleanId/hqdefault.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                widget.subjectColor.withValues(alpha: 0.3),
                                widget.subjectColor.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.ondemand_video_rounded,
                                size: 48, color: Colors.white54),
                          ),
                        );
                      },
                    );
                  },
                ),

                // ── تدرج ظلال سينمائي لحماية النصوص والأيقونات ─────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // ── الشريط العلوي: شارة الدرس والجودة + زر اليوتيوب الخارجي ────
                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_filled_rounded,
                              color: widget.subjectColor,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'فيديو الدرس • HD',
                              style: GoogleFonts.tajawal(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _openExternalYoutube();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── زر التشغيل الزجاجي المشع في المنتصف ─────────────────────
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.subjectColor,
                          widget.subjectColor.withValues(alpha: 0.78),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.subjectColor.withValues(alpha: 0.5),
                          blurRadius: 22,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 2.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),

                // ── عنوان الدرس بالأسفل ──────────────────────────────────
                if (widget.lessonTitle.isNotEmpty)
                  Positioned(
                    bottom: 14,
                    left: 14,
                    right: 14,
                    child: Text(
                      widget.lessonTitle,
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [
                          const Shadow(
                            color: Colors.black,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
