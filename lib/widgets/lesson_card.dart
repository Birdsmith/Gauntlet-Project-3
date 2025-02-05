import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/lesson.dart';
import '../screens/video_player_screen.dart';

class LessonCard extends StatefulWidget {
  final Lesson lesson;
  final Function(Future<void> Function())? onInitialize;

  const LessonCard({
    super.key,
    required this.lesson,
    this.onInitialize,
  });

  @override
  State<LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<LessonCard> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _downloadUrl;
  bool _isVisible = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  @override
  void didUpdateWidget(LessonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lesson.videoUrl != widget.lesson.videoUrl) {
      _resetState();
    }
  }

  void _resetState() {
    if (_isInitialized) {
      _controller.dispose();
    }
    setState(() {
      _isInitialized = false;
      _downloadUrl = null;
      _error = null;
    });
    _checkVisibility();
  }

  void _checkVisibility() {
    if (!mounted) return;
    
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject == null || !renderObject.attached) return;
    
    final RenderBox box = renderObject as RenderBox;
    final Offset position = box.localToGlobal(Offset.zero);
    final Size size = box.size;
    
    // Consider the widget visible if at least 50% of it is in the viewport
    final double visibleThreshold = size.height * 0.5;
    final bool isVisible = position.dy + visibleThreshold >= 0 && 
                         position.dy + size.height - visibleThreshold <= MediaQuery.of(context).size.height;
    
    if (isVisible && !_isInitialized && !_isVisible) {
      setState(() => _isVisible = true);
      if (widget.onInitialize != null) {
        widget.onInitialize!(() => _initializeController());
      } else {
        _initializeController();
      }
    }
  }

  Future<void> _initializeController() async {
    try {
      if (!mounted) return;

      // Cache the download URL
      if (_downloadUrl == null) {
        final storageRef = FirebaseStorage.instance.refFromURL(widget.lesson.videoUrl);
        _downloadUrl = await storageRef.getDownloadURL();
      }
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(_downloadUrl!),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
        ),
      );
      
      // Optimize for thumbnail
      await _controller.initialize();
      await _controller.setVolume(0.0);
      await _controller.setLooping(false);
      await _controller.seekTo(const Duration(milliseconds: 500));
      await _controller.pause();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              lesson: widget.lesson.copyWith(
                videoUrl: _downloadUrl ?? widget.lesson.videoUrl,
              ),
            ),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _isInitialized
                  ? VideoPlayer(_controller)
                  : Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: _error != null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Error loading video',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              )
                            : const CircularProgressIndicator(),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lesson.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.lesson.description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withAlpha(26),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.lesson.level,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.lesson.duration.toInt()} min',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 