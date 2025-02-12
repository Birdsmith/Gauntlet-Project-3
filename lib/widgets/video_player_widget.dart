import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/lesson.dart';

class VideoPlayerWidget extends StatefulWidget {
  final Lesson lesson;
  final bool autoPlay;

  const VideoPlayerWidget({
    super.key,
    required this.lesson,
    this.autoPlay = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lesson.id != widget.lesson.id) {
      _disposeController();
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.network(widget.lesson.videoUrl);
      await _controller.initialize();
      if (widget.autoPlay) {
        await _controller.play();
      }
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  void _disposeController() {
    _controller.dispose();
    if (mounted) {
      setState(() => _isInitialized = false);
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading video: $_error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeVideo,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          _PlayPauseOverlay(controller: _controller),
          _VideoProgressIndicator(controller: _controller),
        ],
      ),
    );
  }
}

class _PlayPauseOverlay extends StatefulWidget {
  final VideoPlayerController controller;

  const _PlayPauseOverlay({required this.controller});

  @override
  State<_PlayPauseOverlay> createState() => _PlayPauseOverlayState();
}

class _PlayPauseOverlayState extends State<_PlayPauseOverlay> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateControlsVisibility);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateControlsVisibility);
    super.dispose();
  }

  void _updateControlsVisibility() {
    if (!mounted) return;
    final isPlaying = widget.controller.value.isPlaying;
    if (isPlaying && _showControls) {
      setState(() => _showControls = false);
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
        _showControls = true;
      } else {
        widget.controller.play();
        _showControls = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        color: Colors.transparent,
        child: AnimatedOpacity(
          opacity: _showControls || !widget.controller.value.isPlaying ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            color: Colors.black26,
            child: Center(
              child: Icon(
                widget.controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 64.0,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoProgressIndicator extends StatelessWidget {
  final VideoPlayerController controller;

  const _VideoProgressIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: VideoProgressIndicator(
        controller,
        allowScrubbing: true,
        colors: const VideoProgressColors(
          playedColor: Colors.red,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      ),
    );
  }
} 