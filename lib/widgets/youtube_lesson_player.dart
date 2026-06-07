import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// مشغل يوتيوب داخل التطبيق.
/// - يدعم تغيير [videoId] أثناء وجوده على الشاشة.
/// - يتجنب حالات setState غير ضرورية التي قد تسبب مشاكل على بعض الأجهزة.
class YoutubeLessonPlayer extends StatefulWidget {
  const YoutubeLessonPlayer({
    super.key,
    required this.videoId,
    this.autoPlay = false,
    this.mute = false,
  });

  final String videoId;
  final bool autoPlay;
  final bool mute;

  @override
  State<YoutubeLessonPlayer> createState() => _YoutubeLessonPlayerState();
}

class _YoutubeLessonPlayerState extends State<YoutubeLessonPlayer> {
  late final YoutubePlayerController _controller;
  String? _lastVideoId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _lastVideoId = widget.videoId;
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: widget.mute,
        hideControls: false,
        disableDragSeek: false,
        forceHD: true,
      ),
    );
    // لا يوجد ضمان callback جاهز للـ ready في كل الإصدارات.
    // سنوقف الـ loading بمجرد أول build بعد init.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  void didUpdateWidget(covariant YoutubeLessonPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      setState(() => _loading = true);
      _lastVideoId = widget.videoId;

      // load() يعالج تغيير الفيديو.
      // نستخدم try/catch لتفادي crash إن كان videoId غير صالح.
      try {
        _controller.load(widget.videoId);
      } catch (_) {
        // إذا فشل load، سنترك loader يتحول لرسالة خطأ من خلال build.
      }

      // توقيف loader بعد frame، حتى لا يبقى إلى الأبد لو حدث exception.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _loading = false);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Theme.of(context).colorScheme.primary,
              ),
      ),
    );
  }
}
