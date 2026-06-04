import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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
  late YoutubePlayerController _controller;
  bool _isReady = false;
  Completer<void>? _initCompleter;

  Future<void> _init(String videoId) async {
    _initCompleter = Completer<void>();

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: widget.mute,
        hideControls: false,
        disableDragSeek: false,
        forceHD: true,
      ),
    );

    // youtube_player_flutter قد لا يوفر callback جاهز للإعداد.
    // سنعتبره جاهزاً مباشرة بعد إنشاء الـ controller.
    _isReady = true;
    _initCompleter?.complete();
  }

  @override
  void initState() {
    super.initState();
    _init(widget.videoId);
  }

  @override
  void didUpdateWidget(covariant YoutubeLessonPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      setState(() {
        _isReady = false;
      });
      _controller.load(widget.videoId);
      setState(() {
        _isReady = true;
      });
    }
  }

  @override
  void dispose() {
    // youtube_player_flutter >=9: إغلاق الـ controller قد لا يكون close() حسب النسخة
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
        child: _isReady
            ? YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Theme.of(context).colorScheme.primary,
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
