import 'package:flutter/material.dart';
import 'dart:collection';
import '../models/lesson.dart';
import '../models/lesson_collection.dart';
import '../services/interaction_service.dart';
import '../services/lesson_service.dart';
import '../services/collection_service.dart';
import '../widgets/lesson_card.dart';
import 'learning_mode_screen.dart';

class SavedLessonsScreen extends StatefulWidget {
  const SavedLessonsScreen({super.key});

  @override
  State<SavedLessonsScreen> createState() => _SavedLessonsScreenState();
}

class _SavedLessonsScreenState extends State<SavedLessonsScreen> with SingleTickerProviderStateMixin {
  final InteractionService _interactionService = InteractionService();
  final LessonService _lessonService = LessonService();
  final CollectionService _collectionService = CollectionService();
  final _videoInitializationQueue = Queue<Future<void> Function()>();
  final int _maxConcurrentInitializations = 2;
  int _currentInitializations = 0;
  
  late TabController _tabController;
  List<Lesson> _lessons = [];
  final List<LessonCollection> _collections = [];
  bool _isLoading = true;
  String? _selectedCollectionId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedLessons();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _loadSavedLessons() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      Stream<List<String>> lessonIdsStream;
      if (_selectedCollectionId != null) {
        lessonIdsStream = _collectionService.getCollectionLessonIds(_selectedCollectionId!);
      } else {
        lessonIdsStream = _interactionService.getSavedLessonIds();
      }
      
      final lessonIds = await lessonIdsStream.first;
      
      if (lessonIds.isNotEmpty) {
        final lessonsStream = _lessonService.getLessonsByIds(lessonIds);
        final lessons = await lessonsStream.first;
        if (mounted) {
          setState(() {
            _lessons = lessons;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _lessons = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading lessons: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createCollection() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String? selectedEmoji;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Collection'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Collection Name',
                    hintText: 'Enter collection name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter collection description',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                // Add emoji picker here if needed
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  try {
                    await _collectionService.createCollection(
                      name: nameController.text,
                      description: descriptionController.text,
                      emoji: selectedEmoji,
                    );
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Collection created successfully')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating collection: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editCollection(LessonCollection collection) async {
    final TextEditingController nameController = TextEditingController(text: collection.name);
    final TextEditingController descriptionController = TextEditingController(text: collection.description);

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Collection'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Collection Name',
                    hintText: 'Enter collection name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter collection description',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Collection name cannot be empty')),
                  );
                  return;
                }

                try {
                  await _collectionService.updateCollection(
                    collection.id,
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                  );
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Collection updated successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating collection: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCollectionGrid() {
    return StreamBuilder<List<LessonCollection>>(
      stream: _collectionService.getUserCollections(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final collections = snapshot.data!;
        if (collections.isEmpty) {
            return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No collections yet'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _createCollection,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Collection'),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: collections.length + 1, // +1 for the "Create New" tile
          itemBuilder: (context, index) {
            if (index == collections.length) {
              return Card(
                child: InkWell(
                  onTap: _createCollection,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, size: 48),
                      SizedBox(height: 8),
                      Text('Create New Collection'),
                    ],
                  ),
                ),
              );
            }

            final collection = collections[index];
            return Card(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCollectionId = collection.id;
                    _loadSavedLessons();
                  });
                },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                    if (collection.emoji != null)
                            Text(
                              collection.emoji!,
                              style: const TextStyle(fontSize: 32),
                      )
                    else
                      const Icon(Icons.folder, size: 32),
                            const SizedBox(height: 8),
                          Text(
                            collection.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '${collection.lessonCount} lessons',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                    const SizedBox(height: 8),
                    Tooltip(
                      message: collection.lessonCount == 0 
                        ? 'Add lessons to the collection to start learning'
                        : 'Start learning session',
                      child: ElevatedButton.icon(
                        onPressed: collection.lessonCount > 0 
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => LearningModeScreen(
                                    collection: collection,
                                  ),
                                ),
                              );
                            }
                          : null, // This will grey out the button when disabled
                        icon: const Icon(Icons.school),
                        label: const Text('Learn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[600],
                        ),
                      ),
                    ),
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Text('Edit'),
                          onTap: () => _editCollection(collection),
                        ),
                        PopupMenuItem(
                          child: const Text('Delete'),
                          onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Collection'),
                              content: Text('Are you sure you want to delete "${collection.name}"? This action cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true && mounted) {
                            try {
                              await _collectionService.deleteCollection(collection.id);
                              if (_selectedCollectionId == collection.id) {
                                setState(() {
                                  _selectedCollectionId = null;
                                  _loadSavedLessons();
                                });
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Collection deleted successfully')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error deleting collection: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLessonGrid() {
    if (_lessons.isEmpty && !_isLoading) {
            return const Center(
              child: Text('No saved lessons yet'),
            );
          }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _lessons.length,
      itemBuilder: (context, index) {
        return LessonCard(
          key: ValueKey(_lessons[index].id),
          lesson: _lessons[index],
          onInitialize: _queueVideoInitialization,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _selectedCollectionId != null
          ? StreamBuilder<List<LessonCollection>>(
              stream: _collectionService.getUserCollections(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Text('Saved Lessons');
                final collection = snapshot.data!.firstWhere(
                  (c) => c.id == _selectedCollectionId,
                  orElse: () => LessonCollection(
                    id: '',
                    name: 'Unknown Collection',
                    description: '',
                    createdById: '',
                    createdAt: DateTime.now(),
                    lessonIds: [],
                    lessonCount: 0,
                  ),
                );
                return Row(
                  children: [
                    Expanded(
                      child: Text(collection.name),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _selectedCollectionId = null;
                          _loadSavedLessons();
                        });
                      },
                    ),
                  ],
                );
              },
            )
          : const Text('Saved Lessons'),
        bottom: _selectedCollectionId == null ? TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Lessons'),
            Tab(text: 'Collections'),
          ],
        ) : null,
      ),
      body: Stack(
        children: [
          if (_selectedCollectionId != null)
            RefreshIndicator(
              onRefresh: _loadSavedLessons,
              child: _buildLessonGrid(),
            )
          else
            TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _loadSavedLessons,
                  child: _buildLessonGrid(),
                ),
                _buildCollectionGrid(),
              ],
            ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
} 