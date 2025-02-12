import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/lesson.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;
import '../services/interaction_service.dart';
import '../services/storage_service.dart';
import '../services/subtitle_service.dart';
import '../services/transcription_service.dart';
import '../widgets/lesson_interaction_buttons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/audio_extraction_service.dart';
import 'dart:io';

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
  bool _isTranscribing = false;
  String? _errorMessage;
  String? _selectedSubtitleLanguage;
  final InteractionService _interactionService = InteractionService();
  final StorageService _storageService = StorageService();
  final SubtitleService _subtitleService = SubtitleService();
  final TranscriptionService _transcriptionService = TranscriptionService();
  final UserService _userService = UserService();
  final AudioExtractionService _audioExtractor = AudioExtractionService();
  List<String> _availableSubtitleLanguages = [];
  List<Subtitle> _currentSubtitles = [];
  String? _userNativeLanguage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadUserProfile();
    _loadSubtitleLanguages();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfile = await _userService.getUserProfile();
      if (mounted && userProfile != null) {
        setState(() {
          _userNativeLanguage = userProfile.nativeLanguage;
        });
      }
    } catch (e) {
      developer.log('Error loading user profile: $e');
    }
  }

  Future<void> _loadSubtitleLanguages() async {
    try {
      final languages = await _storageService.listSubtitleLanguages(widget.lesson.id);
      if (mounted) {
        // Filter languages to only include user's native language and video language
        final filteredLanguages = languages.where((lang) => 
          (_userNativeLanguage != null && lang == _userNativeLanguage) || 
          lang == widget.lesson.language
        ).toList();
        
        setState(() {
          _availableSubtitleLanguages = filteredLanguages;
          // Set default subtitle language if available
          if (widget.lesson.defaultSubtitleLanguage != null &&
              filteredLanguages.contains(widget.lesson.defaultSubtitleLanguage)) {
            _selectedSubtitleLanguage = widget.lesson.defaultSubtitleLanguage;
          }
        });
        if (_selectedSubtitleLanguage != null) {
          _updateSubtitles(_selectedSubtitleLanguage!);
        }
      }
    } catch (e) {
      developer.log('Error loading subtitle languages: $e');
    }
  }

  Future<void> _updateSubtitles(String languageCode) async {
    if (_isTranscribing) return;
    
    setState(() => _isTranscribing = true);
    try {
      if (_chewieController == null) return;

      // First try to get existing subtitle URL
      String? subtitleUrl;
      try {
        subtitleUrl = await _storageService.getSubtitleUrl(widget.lesson.id, languageCode);
      } catch (e) {
        developer.log('Subtitle file not found, will generate: $e');
      }

      if (subtitleUrl != null) {
        // VTT exists, load it directly
        final subtitles = await _subtitleService.loadSubtitlesFromUrl(subtitleUrl);
        _updateSubtitleDisplay(languageCode, subtitles);
        return;
      }

      // VTT doesn't exist, check if we already have the audio file
      final lessonDoc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(widget.lesson.id)
          .get();
      
      if (!lessonDoc.exists) {
        throw Exception('Lesson document not found');
      }
      
      final lessonData = lessonDoc.data();
      if (lessonData == null) {
        throw Exception('Lesson data is null');
      }
      
      final existingAudioUrl = lessonData['audioUrl'] as String?;
      final existingRawAudioUrl = lessonData['rawAudioUrl'] as String?;

      String? audioPath;
      try {
        if (existingRawAudioUrl == null) {
          // No audio file, need to extract it first
          audioPath = await _audioExtractor.extractAudioFromVideo(widget.lesson.videoUrl, widget.lesson.id);
          if (audioPath == null) {
            throw Exception('Failed to extract audio from video');
          }

          // Upload audio file
          final audioUrls = await _audioExtractor.uploadAudioFile(audioPath, widget.lesson.id);
          if (audioUrls == null) {
            throw Exception('Failed to upload audio file');
          }

          // Update lesson document with audio URLs
          await FirebaseFirestore.instance
              .collection('lessons')
              .doc(widget.lesson.id)
              .update({
            'audioUrl': audioUrls['downloadUrl'],
            'rawAudioUrl': audioUrls['gcsUri'],
          });
        }

        // Now call the transcription service
        final result = await _transcriptionService.transcribeVideo(widget.lesson.id);
        developer.log('Transcription result: $result');

        // After transcription, try to get the subtitle URL again
        subtitleUrl = await _storageService.getSubtitleUrl(widget.lesson.id, languageCode);
        final subtitles = await _subtitleService.loadSubtitlesFromUrl(subtitleUrl);
        _updateSubtitleDisplay(languageCode, subtitles);
      } finally {
        // Clean up temporary audio file if it was created
        if (audioPath != null) {
          try {
            await File(audioPath).delete();
          } catch (e) {
            developer.log('Error cleaning up temporary audio file: $e');
          }
        }
      }
    } catch (e) {
      developer.log('Error updating subtitles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading subtitles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  void _updateSubtitleDisplay(String languageCode, List<Subtitle> subtitles) {
    if (!mounted) return;
    setState(() {
      _selectedSubtitleLanguage = languageCode;
      _currentSubtitles = subtitles;
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: _chewieController!.isPlaying,
        looping: _chewieController!.looping,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: const [0.5, 0.75, 1, 1.25, 1.5, 2],
        subtitle: Subtitles(subtitles),
        subtitleBuilder: (context, subtitle) => Container(
          padding: const EdgeInsets.all(10.0),
          child: subtitle.text.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    subtitle.text,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      );
    });
  }

  Future<void> _initializePlayer() async {
    try {
      developer.log('Starting video initialization for: ${widget.lesson.videoUrl}');
      
      String videoUrl = widget.lesson.videoUrl;
      
      // If we have a gs:// URL, convert it to an HTTPS URL
      if (videoUrl.startsWith('gs://')) {
        final storageRef = FirebaseStorage.instance.refFromURL(videoUrl);
        developer.log('Getting download URL...');
        videoUrl = await storageRef.getDownloadURL();
        developer.log('Download URL obtained: $videoUrl');
      }
      
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );
      developer.log('Initializing video player...');
      
      try {
        await _videoPlayerController.initialize();
      } catch (initError) {
        developer.log('Video player initialization failed', error: initError);
        _videoPlayerController.dispose();
        throw Exception('Failed to initialize video player: $initError');
      }
      
      developer.log('Video player initialized');
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: const [0.5, 0.75, 1, 1.25, 1.5, 2],
        subtitle: Subtitles([]),
        subtitleBuilder: (context, subtitle) => Container(
          padding: const EdgeInsets.all(10.0),
          child: subtitle.text.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    subtitle.text,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                )
              : const SizedBox.shrink(),
        ),
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

  Future<void> _generateSubtitles() async {
    if (_isTranscribing) return;
    // Use the video's language by default for transcription
    await _updateSubtitles(widget.lesson.language);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        actions: [
          IconButton(
            icon: _isTranscribing 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.closed_caption),
            tooltip: 'Generate Subtitles',
            onPressed: _isTranscribing ? null : _generateSubtitles,
          ),
          if (_availableSubtitleLanguages.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.subtitles),
              tooltip: 'Select subtitles',
              onSelected: (String languageCode) {
                if (languageCode == 'off') {
                  setState(() {
                    _selectedSubtitleLanguage = null;
                    if (_chewieController != null) {
                      _chewieController = ChewieController(
                        videoPlayerController: _videoPlayerController,
                        autoPlay: _chewieController!.isPlaying,
                        looping: _chewieController!.looping,
                        aspectRatio: _videoPlayerController.value.aspectRatio,
                        allowPlaybackSpeedChanging: true,
                        playbackSpeeds: const [0.5, 0.75, 1, 1.25, 1.5, 2],
                        subtitle: Subtitles([]),
                      );
                    }
                  });
                } else {
                  _updateSubtitles(languageCode);
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'off',
                  child: Text('Off'),
                ),
                ...(_availableSubtitleLanguages.map((languageCode) {
                  final isNative = languageCode == _userNativeLanguage;
                  final isVideoLanguage = languageCode == widget.lesson.language;
                  String label = languageCode.toUpperCase();
                  if (isNative) {
                    label += ' (Native)';
                  } else if (isVideoLanguage) {
                    label += ' (Video)';
                  }
                  return PopupMenuItem<String>(
                    value: languageCode,
                    child: Row(
                      children: [
                        Text(label),
                        if (languageCode == _selectedSubtitleLanguage)
                          const Icon(Icons.check, size: 18),
                      ],
                    ),
                  );
                })),
              ],
            ),
        ],
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
          else if (_errorMessage != null)
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