import 'dart:math';
import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../models/learning_session.dart';
import '../models/lesson_collection.dart';
import '../services/learning_session_service.dart';
import '../services/lesson_service.dart';
import '../widgets/video_player_widget.dart';

class LearningModeScreen extends StatefulWidget {
  final LessonCollection collection;

  const LearningModeScreen({
    super.key,
    required this.collection,
  });

  @override
  State<LearningModeScreen> createState() => _LearningModeScreenState();
}

class _LearningModeScreenState extends State<LearningModeScreen> {
  final LearningSessionService _learningSessionService = LearningSessionService();
  final LessonService _lessonService = LessonService();
  
  late LearningSession _session;
  Lesson? _currentLesson;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.collection.lessonIds.isEmpty) {
      // If collection is empty, show error and pop back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot start learning mode with an empty collection'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
      });
      return;
    }
    _startLearningSession();
  }

  Future<void> _startLearningSession() async {
    try {
      setState(() => _isLoading = true);
      
      // Create a new learning session
      _session = await _learningSessionService.createSession(
        widget.collection.id,
        widget.collection.lessonIds,
      );
      
      await _loadNextLesson();
    } catch (e) {
      setState(() {
        _error = 'Failed to start learning session: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNextLesson() async {
    try {
      setState(() => _isLoading = true);

      if (_session.remainingLessonIds.isEmpty) {
        // Session completed
        setState(() {
          _currentLesson = null;
          _isLoading = false;
        });
        return;
      }

      // Randomly select next lesson
      final random = Random();
      final nextLessonId = _session.remainingLessonIds[
        random.nextInt(_session.remainingLessonIds.length)
      ];

      // Load the lesson
      final lesson = await _lessonService.getLessonById(nextLessonId);
      if (lesson == null) throw Exception('Lesson not found');

      setState(() {
        _currentLesson = lesson;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load next lesson: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleResponse(bool understood) async {
    try {
      setState(() => _isLoading = true);

      if (_currentLesson == null) return;

      // Update session progress
      _session = await _learningSessionService.updateSessionProgress(
        _session.id,
        _currentLesson!.id,
        understood,
      );

      if (_session.isCompleted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Congratulations! You\'ve completed this learning session!'),
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop(); // Return to previous screen
        }
        return;
      }

      await _loadNextLesson();
    } catch (e) {
      setState(() {
        _error = 'Failed to update progress: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Learning Session?'),
        content: const Text(
          'Are you sure you want to end this learning session? Your progress will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('END SESSION'),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Learning: ${widget.collection.name}'),
          actions: [
            TextButton.icon(
              onPressed: () => _onWillPop().then((shouldPop) {
                if (shouldPop) Navigator.of(context).pop();
              }),
              icon: const Icon(Icons.exit_to_app),
              label: const Text('End Session'),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _startLearningSession,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentLesson == null) {
      return const Center(
        child: Text('No more lessons to review!'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: VideoPlayerWidget(
            lesson: _currentLesson!,
            autoPlay: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleResponse(false),
                  icon: const Icon(Icons.thumb_down),
                  label: const Text('Still Learning'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleResponse(true),
                  icon: const Icon(Icons.thumb_up),
                  label: const Text('Got It!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            'Progress: ${_session.masteredLessonIds.length}/${_session.masteredLessonIds.length + _session.remainingLessonIds.length} mastered',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
} 