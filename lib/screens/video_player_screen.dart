import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/lesson.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;
import '../services/interaction_service.dart';
import '../widgets/lesson_interaction_buttons.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Lesson lesson;

  const VideoPlayerScreen({
    super.key,
    required this.lesson,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;
  final InteractionService _interactionService = InteractionService();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      developer.log('Starting video initialization for: ${widget.lesson.videoUrl}');
      
      // Convert gs:// URL to https:// download URL
      final storageRef = FirebaseStorage.instance.refFromURL(widget.lesson.videoUrl);
      developer.log('Getting download URL...');
      final downloadUrl = await storageRef.getDownloadURL();
      developer.log('Download URL obtained: $downloadUrl');
      
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(downloadUrl),
      );
      developer.log('Initializing video player...');
      await _videoPlayerController.initialize();
      developer.log('Video player initialized');
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: const [0.5, 0.75, 1, 1.25, 1.5, 2],
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 42),
                const SizedBox(height: 8),
                Text(
                  'Error playing video: $errorMessage',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error initializing video player',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading video: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading video...'),
                ],
              ),
            )
          else if (_chewieController != null)
            AspectRatio(
              aspectRatio: _videoPlayerController.value.aspectRatio,
              child: Chewie(controller: _chewieController!),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 42),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Error loading video',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializePlayer,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          LessonInteractionButtons(
            lesson: widget.lesson,
            interactionService: _interactionService,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lesson.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.lesson.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.bar_chart, size: 16),
                      const SizedBox(width: 4),
                      Text('Level: ${widget.lesson.level}'),
                      const SizedBox(width: 16),
                      const Icon(Icons.timer, size: 16),
                      const SizedBox(width: 4),
                      Text('${widget.lesson.duration.toStringAsFixed(1)} min'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: widget.lesson.topics.map((topic) {
                      return Chip(
                        label: Text(topic),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }
} 