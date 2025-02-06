import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../services/lesson_service.dart';
import '../services/user_service.dart';
import '../widgets/lesson_card.dart';
import 'dart:collection';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final LessonService _lessonService = LessonService();
  final UserService _userService = UserService();
  final _videoInitializationQueue = Queue<Future<void> Function()>();
  final int _maxConcurrentInitializations = 2;
  int _currentInitializations = 0;
  List<Lesson> _lessons = [];
  bool _isLoading = false;
  String? _error;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  
  static const List<String> _levels = ['Beginner', 'Intermediate', 'Advanced'];
  static const List<String> _topics = [
    'Grammar',
    'Vocabulary',
    'Pronunciation',
    'Speaking',
    'Listening',
    'Reading',
    'Writing'
  ];

  List<String> _selectedTopics = [];
  String? _selectedLevel;
  List<String> _filteredLanguages = [];

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _loadLessons();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Clear image cache when screen is loaded
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _queueVideoInitialization(Future<void> Function() initFunction) async {
    _videoInitializationQueue.add(initFunction);
    await _processVideoQueue();
  }

  Future<void> _processVideoQueue() async {
    if (_currentInitializations >= _maxConcurrentInitializations) return;
    
    while (_videoInitializationQueue.isNotEmpty && 
           _currentInitializations < _maxConcurrentInitializations) {
      _currentInitializations++;
      final initFunction = _videoInitializationQueue.removeFirst();
      await initFunction();
      _currentInitializations--;
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      final userProfile = await _userService.getUserProfile();
      if (mounted && userProfile != null) {
        setState(() {
          _filteredLanguages = userProfile.targetLanguages;
          _isLoading = false;
        });
      }
      await _loadLessons();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLessons() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userProfile = await _userService.getUserProfile();
      if (userProfile == null) throw Exception('User profile not found');

      _filteredLanguages = userProfile.targetLanguages;
      final proficiencyLevels = userProfile.proficiencyLevels;

      if (_filteredLanguages.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Stream<List<Lesson>> lessonsStream;
      
      if (_searchController.text.isNotEmpty) {
        lessonsStream = _lessonService.searchLessons(
          _searchController.text,
          languages: _filteredLanguages,
          proficiencyLevels: _selectedLevel != null ? {_selectedLevel!: proficiencyLevels[_selectedLevel!]!} : proficiencyLevels,
        );
      } else if (_selectedTopics.isNotEmpty) {
        lessonsStream = _lessonService.getLessonsByTopics(
          topics: _selectedTopics,
          languages: _filteredLanguages,
          proficiencyLevels: _selectedLevel != null ? {_selectedLevel!: proficiencyLevels[_selectedLevel!]!} : proficiencyLevels,
        );
      } else {
        lessonsStream = _lessonService.getLessons(
          languages: _filteredLanguages,
          proficiencyLevels: _selectedLevel != null ? {_selectedLevel!: proficiencyLevels[_selectedLevel!]!} : proficiencyLevels,
        );
      }

      final lessons = await lessonsStream.first;
      if (mounted) {
        setState(() {
          _lessons = lessons;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading lessons: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showFilterDialog() async {
    String? tempSelectedLevel = _selectedLevel;
    List<String> tempSelectedTopics = List.from(_selectedTopics);

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter Lessons'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Level',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _levels.map((level) {
                        return FilterChip(
                          label: Text(level),
                          selected: tempSelectedLevel == level,
                          onSelected: (bool selected) {
                            setState(() {
                              tempSelectedLevel = selected ? level : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Topics',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _topics.map((topic) {
                        return FilterChip(
                          label: Text(topic),
                          selected: tempSelectedTopics.contains(topic),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                tempSelectedTopics.add(topic);
                              } else {
                                tempSelectedTopics.remove(topic);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (mounted) {
                      this.setState(() {
                        _selectedLevel = tempSelectedLevel;
                        _selectedTopics = tempSelectedTopics;
                      });
                    }
                    Navigator.of(context).pop();
                    _loadLessons();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_filteredLanguages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Video Feed')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No languages selected',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please select your preferred languages in your profile settings.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/settings/language');
                  },
                  child: const Text('Go to Settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search lessons...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              onChanged: (value) {
                _loadLessons();
              },
            )
          : const Text('Video Feed'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _loadLessons();
                }
                _isSearching = !_isSearching;
              });
            },
            tooltip: _isSearching ? 'Clear search' : 'Search lessons',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter lessons',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadLessons,
            child: _lessons.isEmpty && !_isLoading
                ? const Center(
                    child: Text(
                      'No lessons found',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : SafeArea(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      cacheExtent: 500,
                      itemCount: _lessons.length,
                      itemBuilder: (context, index) {
                        return KeepAliveWrapper(
                          child: LessonCard(
                            key: ValueKey(_lessons[index].id),
                            lesson: _lessons[index],
                            onInitialize: (initFunction) => 
                                _queueVideoInitialization(initFunction),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(77),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (_error != null)
            Container(
              color: Colors.black.withAlpha(77),
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, 
                          color: Colors.red, 
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadLessons,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  
  const KeepAliveWrapper({
    super.key,
    required this.child,
  });

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
} 