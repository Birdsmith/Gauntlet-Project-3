import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:provider/provider.dart';
import '../models/lesson.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;
import '../services/interaction_service.dart';
import '../services/storage_service.dart';
import '../services/subtitle_service.dart';
import '../services/transcription_service.dart';
import '../widgets/lesson_interaction_buttons.dart';
import '../services/quiz_service.dart';
import '../widgets/quiz_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/audio_extraction_service.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';

class CustomPortraitControls extends StatelessWidget {
  const CustomPortraitControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base layer for showing/hiding controls
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final flickManager = Provider.of<FlickManager>(context, listen: false);
              flickManager.flickDisplayManager?.handleShowPlayerControls();
            },
          ),
        ),
        // Controls overlay
        Positioned.fill(
          child: FlickShowControlsAction(
            child: FlickSeekVideoAction(
              child: Center(
                child: FlickVideoBuffer(
                  child: FlickAutoHideChild(
                    showIfVideoNotInitialized: false,
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FlickVideoProgressBar(
                            flickProgressBarSettings: FlickProgressBarSettings(
                              height: 5,
                              handleRadius: 7,
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              backgroundColor: Colors.white24,
                              bufferedColor: Colors.white38,
                              playedColor: Colors.white,
                              handleColor: Colors.white,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                FlickPlayToggle(size: 32),
                                FlickSoundToggle(size: 32),
                                const SizedBox(width: 8),
                                FlickCurrentPosition(),
                                const Text(' / ', style: TextStyle(color: Colors.white)),
                                FlickTotalDuration(),
                                const Spacer(),
                                FlickFullScreenToggle(size: 32),
                                PopupMenuButton<double>(
                                  icon: const Icon(
                                    Icons.speed,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  onSelected: (double speed) {
                                    final flickManager = Provider.of<FlickManager>(context, listen: false);
                                    flickManager.flickVideoManager?.videoPlayerController?.setPlaybackSpeed(speed);
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                                    const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                                    const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                                    const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                                    const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                                    const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CustomLandscapeControls extends StatelessWidget {
  const CustomLandscapeControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base layer for showing/hiding controls
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final flickManager = Provider.of<FlickManager>(context, listen: false);
              flickManager.flickDisplayManager?.handleShowPlayerControls();
            },
          ),
        ),
        // Controls overlay
        Positioned.fill(
          child: FlickShowControlsAction(
            child: FlickSeekVideoAction(
              child: Center(
                child: FlickVideoBuffer(
                  child: FlickAutoHideChild(
                    showIfVideoNotInitialized: false,
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            color: Colors.black.withOpacity(0.5),
                            child: FlickVideoProgressBar(
                              flickProgressBarSettings: FlickProgressBarSettings(
                                height: 5,
                                handleRadius: 7,
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                backgroundColor: Colors.white24,
                                bufferedColor: Colors.white38,
                                playedColor: Colors.white,
                                handleColor: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            color: Colors.black26,
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                FlickPlayToggle(size: 32),
                                FlickSoundToggle(size: 32),
                                const SizedBox(width: 8),
                                FlickCurrentPosition(),
                                const Text(' / ', style: TextStyle(color: Colors.white)),
                                FlickTotalDuration(),
                                const Spacer(),
                                FlickFullScreenToggle(size: 32),
                                PopupMenuButton<double>(
                                  icon: const Icon(
                                    Icons.speed,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  onSelected: (double speed) {
                                    final flickManager = Provider.of<FlickManager>(context, listen: false);
                                    flickManager.flickVideoManager?.videoPlayerController?.setPlaybackSpeed(speed);
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                                    const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                                    const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                                    const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                                    const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                                    const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
  late FlickManager flickManager;
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
  final QuizService _quizService = QuizService();
  List<String> _availableSubtitleLanguages = [];
  List<Subtitle> _currentSubtitles = [];
  String? _userNativeLanguage;
  final String _userLanguage = 'en'; // Changed from 'en-US' to 'en'
  bool _isFullscreen = false;
  String? _summary;
  bool _isGeneratingQuiz = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoAndSubtitles();
    
    // Set allowed orientations and system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Initialize in immersive mode
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );

    flickManager = FlickManager(
      videoPlayerController: VideoPlayerController.network(
        widget.lesson.videoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      ),
      onVideoEnd: () {
        // Handle video end if needed
      },
    );

    // Listen for fullscreen changes
    flickManager.flickControlManager?.addListener(_onFullscreenChanged);

    // Add position listener for subtitle updates with more frequent updates
    flickManager.flickVideoManager?.videoPlayerController?.addListener(_onVideoPositionChanged);
    
    // Set up a periodic timer to ensure subtitle updates
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _onVideoPositionChanged();
    });
  }

  void _onFullscreenChanged() {
    final bool isFullscreen = flickManager.flickControlManager?.isFullscreen ?? false;
    if (_isFullscreen != isFullscreen) {
      setState(() {
        _isFullscreen = isFullscreen;
      });
      _updateSystemUIOverlay(isFullscreen);
    }
  }

  void _updateSystemUIOverlay(bool isFullscreen) {
    if (isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void _onVideoPositionChanged() {
    if (!mounted) return;
    final position = flickManager.flickVideoManager?.videoPlayerController?.value.position;
    if (position != null) {
      setState(() {
        // Trigger rebuild for subtitle updates
      });
    }
  }

  Future<void> _initializeVideoAndSubtitles() async {
    try {
      print('🎬 STARTING VIDEO INITIALIZATION');
      developer.log('Starting initialization sequence');
      await _initializePlayer();
      
      // Load user profile first and wait for it
      print('👤 LOADING USER PROFILE');
      developer.log('Loading user profile');
      await _loadUserProfile();
      print('👤 USER LANGUAGE: $_userNativeLanguage');
      developer.log('User native language after profile load: $_userNativeLanguage');
      
      if (_userNativeLanguage == null) {
        print('⚠️ NO USER LANGUAGE - USING DEFAULT "en"');
        developer.log('Warning: User native language is not set, using default language "en"');
        setState(() {
          _userNativeLanguage = 'en';  // Set default language if none is set
        });
      }
      
      // Now that we have the language, generate summary
      print('📝 STARTING SUMMARY GENERATION');
      developer.log('Starting summary generation');
      await _generateAndStoreSummary();
      print('📝 SUMMARY RESULT: $_summary');
      developer.log('Summary after generation: $_summary');
      
      // Load subtitles last
      print('💬 LOADING SUBTITLES');
      await _loadSubtitleLanguages();
    } catch (e, stackTrace) {
      print('❌ ERROR IN INITIALIZATION: $e');
      developer.log('Error in initialization sequence', error: e, stackTrace: stackTrace);
    }
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

        // Wait a short moment for the video player to be fully ready
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (_selectedSubtitleLanguage != null) {
          await _updateSubtitles(_selectedSubtitleLanguage!);
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

      // Get reference to the lesson document
      final lessonRef = FirebaseFirestore.instance
          .collection('lessons')
          .doc(widget.lesson.id);

      // Start transcription process
      final result = await _transcriptionService.transcribeVideo(
        lessonRef,
        languageCode,
      );
      developer.log('Transcription result: $result');

      // Wait for transcription to complete by watching Firestore
      bool transcriptionComplete = false;
      final completer = Completer<void>();
      
      final subscription = lessonRef.snapshots().listen((snapshot) {
        if (!snapshot.exists) return;
        
        final data = snapshot.data();
        if (data == null) return;
        
        final transcriptionData = data['transcription'] as Map<String, dynamic>?;
        if (transcriptionData == null) return;
        
        final status = transcriptionData['status'] as String?;
        
        if (status == 'completed') {
          transcriptionComplete = true;
          completer.complete();
        } else if (status == 'failed') {
          completer.completeError(transcriptionData['error'] ?? 'Transcription failed');
        }
      });

      try {
        // Wait for completion or timeout after 5 minutes
        await completer.future.timeout(const Duration(minutes: 5));
      } finally {
        subscription.cancel();
      }

      if (!transcriptionComplete) {
        throw Exception('Transcription timed out after 5 minutes');
      }

      // After transcription is complete, get the subtitle URL
        subtitleUrl = await _storageService.getSubtitleUrl(widget.lesson.id, languageCode);
        final subtitles = await _subtitleService.loadSubtitlesFromUrl(subtitleUrl);
        _updateSubtitleDisplay(languageCode, subtitles);
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

  void _updateSubtitleDisplay(String? languageCode, List<Subtitle> subtitles) {
    if (!mounted) return;
    
    // Log subtitle content for debugging
    developer.log('Updating subtitle display - Language: $languageCode, Number of subtitles: ${subtitles.length}');
    for (var subtitle in subtitles.take(3)) {
      developer.log('Sample subtitle - Start: ${subtitle.start}, End: ${subtitle.end}');
      developer.log('Text (${subtitle.text.length} chars): ${subtitle.text}');
      developer.log('Text codeUnits: ${subtitle.text.codeUnits}');
      developer.log('Text runes: ${subtitle.text.runes.toList()}');
    }

    setState(() {
      _selectedSubtitleLanguage = languageCode;
      _currentSubtitles = subtitles.map((subtitle) {
        // Clean any potential invalid characters
        final cleanText = subtitle.text
          .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '') // Remove control characters
          .replaceAll(RegExp(r'[\uFFFD]'), ''); // Remove replacement characters
        
        return Subtitle(
          index: subtitle.index,
          start: subtitle.start,
          end: subtitle.end,
          text: cleanText,
        );
      }).toList();
    });
  }

  Future<void> _generateAndStoreSummary() async {
    if (_userNativeLanguage == null) {
      print('⚠️ SKIPPING SUMMARY - NO USER LANGUAGE');
      developer.log('Skipping summary generation - no user native language set');
      return;
    }

    try {
      print('📝 GENERATING SUMMARY FOR LANGUAGE: $_userNativeLanguage');
      developer.log('Starting summary generation for native language: $_userNativeLanguage');
      
      // Get reference to the lesson document
      final lessonRef = FirebaseFirestore.instance
          .collection('lessons')
          .doc(widget.lesson.id);
      
      print('📄 CHECKING LESSON: ${lessonRef.path}');
      developer.log('Checking lesson document: ${lessonRef.path}');
      
      // First check if summary exists in Firestore
      final lessonDoc = await lessonRef.get();
      if (!lessonDoc.exists) {
        print('❌ LESSON NOT FOUND');
        developer.log('Error: Lesson document does not exist');
        return;
      }
      
      final lessonData = lessonDoc.data();
      print('📄 LESSON DATA: $lessonData');
      developer.log('Lesson data: $lessonData');
      
      // Check if summary already exists
      if (lessonData != null && 
          lessonData['summaries'] != null && 
          lessonData['summaries'][_userNativeLanguage] != null) {
        final existingSummary = lessonData['summaries'][_userNativeLanguage] as String;
        print('📝 FOUND EXISTING SUMMARY: $existingSummary');
        developer.log('Found existing summary in Firestore: $existingSummary');
        if (mounted) {
          setState(() {
            _summary = existingSummary;
          });
        }
        return;
      }
      
      // Check transcription status
      var transcriptionData = lessonData?['transcription'] as Map<String, dynamic>?;
      print('🎙️ TRANSCRIPTION DATA: $transcriptionData');
      developer.log('Transcription data: $transcriptionData');
      
      // If no transcription exists or it's not in the user's language, start transcription
      if (transcriptionData == null || 
          transcriptionData['status'] != 'completed' ||
          transcriptionData['outputLanguage'] != _userNativeLanguage) {
        print('🎙️ STARTING TRANSCRIPTION IN ${_userNativeLanguage}');
        developer.log('Starting transcription process in ${_userNativeLanguage}');
        
        // Start transcription process
        final result = await _transcriptionService.transcribeVideo(
          lessonRef,
          _userNativeLanguage,
        );
        developer.log('Transcription started: $result');

        // Wait for transcription to complete
        bool transcriptionComplete = false;
        final completer = Completer<void>();
        
        final subscription = lessonRef.snapshots().listen((snapshot) {
          if (!snapshot.exists) return;
          
          final data = snapshot.data();
          if (data == null) return;
          
          final updatedTranscriptionData = data['transcription'] as Map<String, dynamic>?;
          if (updatedTranscriptionData == null) return;
          
          final status = updatedTranscriptionData['status'] as String?;
          
          if (status == 'completed') {
            transcriptionComplete = true;
            completer.complete();
          } else if (status == 'failed') {
            completer.completeError(updatedTranscriptionData['error'] ?? 'Transcription failed');
          }
        });

        try {
          print('⏳ WAITING FOR TRANSCRIPTION TO COMPLETE');
          // Wait for completion or timeout after 5 minutes
          await completer.future.timeout(const Duration(minutes: 5));
          print('✅ TRANSCRIPTION COMPLETED');
        } catch (e) {
          print('❌ TRANSCRIPTION ERROR: $e');
          developer.log('Error waiting for transcription: $e');
          subscription.cancel();
          return;
        } finally {
          subscription.cancel();
        }

        // Refresh lesson data after transcription
        final updatedDoc = await lessonRef.get();
        final updatedData = updatedDoc.data();
        if (updatedData == null) return;
        
        // Update transcription data reference
        transcriptionData = updatedData['transcription'] as Map<String, dynamic>?;
      }

      // Now generate summary
      if (transcriptionData != null && transcriptionData['status'] == 'completed') {
        print('📝 GENERATING SUMMARY FROM TRANSCRIPTION');
        developer.log('Generating summary from completed transcription');
        
        final summary = await _transcriptionService.generateSummary(
          lessonRef,
          _userNativeLanguage!,
        );

        if (summary != null && mounted) {
          setState(() {
            _summary = summary;
          });
          print('✅ SUMMARY GENERATED AND SAVED');
          developer.log('Summary generated and saved successfully');
        }
      }
    } catch (e, stackTrace) {
      print('❌ ERROR GENERATING SUMMARY: $e');
      developer.log('Error generating summary', error: e, stackTrace: stackTrace);
      // Don't show error to user as summary is not critical
    }
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

      // Create controller with optimized configuration
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
        formatHint: VideoFormat.other, // Changed from hls to other for better compatibility
        httpHeaders: const {
          'Range': 'bytes=0-', // Support range requests
          'Connection': 'keep-alive', // Keep connection alive
          'Accept': '*/*', // Accept any content type
        },
      );

      // Initialize with better error handling and codec configuration
      bool initializationSuccess = false;
      String? initializationError;
      
      try {
        developer.log('Initializing video controller...');
        
        // Set platform-specific options before initialization
        if (Platform.isAndroid) {
          await SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.immersiveSticky,
            overlays: [],
          );
        }

        // Initialize with retries
        int retryCount = 0;
        const maxRetries = 3;
        
        while (retryCount < maxRetries) {
          try {
            // Initialize with a reasonable timeout
            await controller.initialize().timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException('Video initialization timed out');
              },
            );
            
            // Wait for codec to stabilize
            await Future.delayed(const Duration(milliseconds: 300));
            
            if (controller.value.hasError) {
              throw Exception(controller.value.errorDescription);
            }
            
            // Test if video is actually playable
            await controller.play();
            await Future.delayed(const Duration(milliseconds: 100));
            await controller.pause();
            
            initializationSuccess = true;
            break;
          } catch (e) {
            retryCount++;
            developer.log('Initialization attempt $retryCount failed: $e');
            
            if (retryCount < maxRetries) {
              await Future.delayed(Duration(seconds: retryCount)); // Exponential backoff
              continue;
            }
            rethrow;
          }
        }

        // Additional setup after successful initialization
        await controller.setVolume(1.0);
        await controller.setLooping(true);
        
        developer.log('Video controller initialized successfully');
      } catch (e) {
        initializationError = e.toString();
        developer.log('Error during controller initialization: $e');
        await controller.dispose();
        rethrow;
      }

      // Additional validation
      if (!initializationSuccess || !controller.value.isInitialized) {
        await controller.dispose();
        throw Exception('Video initialization failed: ${initializationError ?? 'Unknown error'}');
      }

      // Create FlickManager with proper initialization
      if (mounted) {
        setState(() {
          flickManager = FlickManager(
            videoPlayerController: controller,
            autoInitialize: false, // Already initialized
            autoPlay: false, // Don't autoplay initially
          );
          _isLoading = false;
          _errorMessage = null;
        });

        // Add listeners after initialization
        flickManager.flickControlManager?.addListener(_onFullscreenChanged);
        flickManager.flickVideoManager?.videoPlayerController?.addListener(_onVideoPositionChanged);
      } else {
        await controller.dispose();
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
      }
    }
  }

  Widget _buildCCButton() {
    return PopupMenuButton<String>(
      icon: _isTranscribing 
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(
              Icons.closed_caption,
              color: Colors.white,
            ),
      tooltip: 'Subtitles',
      enabled: !_isTranscribing,
      iconSize: 28,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'off',
          child: Text(
            'Off',
            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
          ),
        ),
        PopupMenuItem<String>(
          value: _userLanguage,
          child: Text(
            'English',
            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
          ),
        ),
        if (widget.lesson.language != _userLanguage)
          PopupMenuItem<String>(
            value: widget.lesson.language,
            child: Text(
              widget.lesson.language == 'es-ES' ? 'Spanish' : widget.lesson.language,
              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
            ),
          ),
      ],
      onSelected: (String value) {
        if (value == 'off') {
          setState(() => _selectedSubtitleLanguage = null);
        } else {
          _updateSubtitles(value);
        }
      },
      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
    );
  }

  Future<void> _showQuiz() async {
    setState(() {
      _isGeneratingQuiz = true;
    });

    try {
      // First try to get existing subtitle URL
      String? subtitleUrl;
      try {
        subtitleUrl = await _storageService.getSubtitleUrl(widget.lesson.id, widget.lesson.language);
      } catch (e) {
        developer.log('Subtitle file not found, will generate: $e');
      }

      if (subtitleUrl == null) {
        // Get reference to the lesson document
        final lessonRef = FirebaseFirestore.instance
            .collection('lessons')
            .doc(widget.lesson.id);

        // Start transcription process
        final result = await _transcriptionService.transcribeVideo(
          lessonRef,
          widget.lesson.language,
        );
        developer.log('Transcription result: $result');

        // Wait for transcription to complete by watching Firestore
        bool transcriptionComplete = false;
        final completer = Completer<void>();
        
        final subscription = lessonRef.snapshots().listen((snapshot) {
          if (!snapshot.exists) return;
          
          final data = snapshot.data();
          if (data == null) return;
          
          final transcriptionData = data['transcription'] as Map<String, dynamic>?;
          if (transcriptionData == null) return;
          
          final status = transcriptionData['status'] as String?;
          
          if (status == 'completed') {
            transcriptionComplete = true;
            completer.complete();
          } else if (status == 'failed') {
            completer.completeError(transcriptionData['error'] ?? 'Transcription failed');
          }
        });

        try {
          // Wait for completion or timeout after 5 minutes
          await completer.future.timeout(const Duration(minutes: 5));
        } finally {
          subscription.cancel();
        }

        if (!transcriptionComplete) {
          throw Exception('Transcription timed out after 5 minutes');
        }

        // After transcription is complete, get the subtitle URL
        subtitleUrl = await _storageService.getSubtitleUrl(widget.lesson.id, widget.lesson.language);
      }

      // Load subtitles and generate quiz
      final subtitles = await _subtitleService.loadSubtitlesFromUrl(subtitleUrl);
      final vttContent = subtitles.map((s) => s.text).join(' ');
      
      // Generate quiz question
      QuizQuestion question = await _quizService.generateQuizFromSubtitles(vttContent);
      
      if (!mounted) return;

      // Show quiz dialog
      showDialog(
        context: context,
        builder: (context) => QuizDialog(question: question),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate quiz: ${e.toString()}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingQuiz = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Cleanup resources properly
    flickManager.flickVideoManager?.videoPlayerController?.removeListener(_onVideoPositionChanged);
    flickManager.flickControlManager?.removeListener(_onFullscreenChanged);
    flickManager.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 28,
        ),
        actions: [
          _buildCCButton(),
          IconButton(
            icon: Icon(
              Icons.quiz,
              color: Colors.white.withOpacity(_isGeneratingQuiz ? 0.5 : 1.0),
            ),
            onPressed: _isGeneratingQuiz ? null : _showQuiz,
            tooltip: 'Generate Quiz',
          ),
        ],
      ),
      body: Provider.value(
        value: flickManager,
        child: SafeArea(
          child: _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 42),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          // Video container at the top
                          Container(
                            width: constraints.maxWidth,
                            color: Colors.black,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: FlickVideoPlayer(
                                flickManager: flickManager,
                                flickVideoWithControls: FlickVideoWithControls(
                                  controls: _isFullscreen
                                      ? const CustomLandscapeControls()
                                      : const CustomPortraitControls(),
                                ),
                              ),
                            ),
                          ),
                          // Interaction buttons below video
                          Container(
                            width: constraints.maxWidth,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.grey[900],
                            child: LessonInteractionButtons(
                              lesson: widget.lesson,
                              interactionService: _interactionService,
                            ),
                          ),
                          // Subtitle display below interaction buttons
                          Container(
                            width: constraints.maxWidth,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            color: Colors.grey[900],
                            child: Consumer<FlickManager>(
                              builder: (context, flickManager, child) {
                                if (_selectedSubtitleLanguage == null || _currentSubtitles.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return ValueListenableBuilder<VideoPlayerValue>(
                                  valueListenable: flickManager.flickVideoManager?.videoPlayerController ?? ValueNotifier(VideoPlayerValue(duration: Duration.zero)),
                                  builder: (context, value, child) {
                                    if (!value.isPlaying && value.position == Duration.zero) {
                                      return const SizedBox.shrink();
                                    }

                                    final currentPosition = value.position;
                                    
                                    // Find all subtitles that should be visible at the current position
                                    final currentSubtitles = _currentSubtitles.where(
                                      (subtitle) => currentPosition >= subtitle.start && 
                                                   currentPosition <= subtitle.end
                                    ).toList();
                                    
                                    if (currentSubtitles.isEmpty) return const SizedBox.shrink();
                                    
                                    // Display all current subtitles (in case there are multiple)
                                    return Column(
                                      children: currentSubtitles.map((subtitle) =>
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            subtitle.text,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              height: 1.5,
                                              fontFamily: Platform.isIOS ? '.SF UI Text' : 'Noto Sans JP',
                                              fontFamilyFallback: Platform.isIOS ? 
                                                ['Hiragino Sans', 'Hiragino Kaku Gothic ProN'] : 
                                                ['Noto Sans CJK JP', 'DroidSansFallback'],
                                              letterSpacing: 0.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                            softWrap: true,
                                            overflow: TextOverflow.visible,
                                          ),
                                        ),
                                      ).toList(),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          // Summary section
                          if (_summary != null)
                            Container(
                              width: constraints.maxWidth,
                              padding: const EdgeInsets.all(16),
                              color: Colors.grey[900],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Summary',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _summary!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
} 