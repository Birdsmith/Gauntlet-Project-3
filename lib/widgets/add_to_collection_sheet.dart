import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../models/lesson_collection.dart';
import '../services/collection_service.dart';

class AddToCollectionSheet extends StatefulWidget {
  final Lesson lesson;

  const AddToCollectionSheet({
    super.key,
    required this.lesson,
  });

  @override
  State<AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<AddToCollectionSheet> {
  final CollectionService _collectionService = CollectionService();
  bool _isLoading = false;

  Future<void> _addToCollection(LessonCollection collection) async {
    setState(() => _isLoading = true);
    try {
      await _collectionService.addLessonToCollection(collection.id, widget.lesson.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to ${collection.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to collection: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createAndAddToCollection() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

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
                    final collectionId = await _collectionService.createCollection(
                      name: nameController.text,
                      description: descriptionController.text,
                    );
                    if (mounted) {
                      Navigator.of(context).pop();
                      await _collectionService.addLessonToCollection(
                        collectionId,
                        widget.lesson.id,
                      );
                      if (mounted) {
                        Navigator.pop(context); // Close the bottom sheet
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to ${nameController.text}'),
                          ),
                        );
                      }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add to Collection',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: StreamBuilder<List<LessonCollection>>(
              stream: _collectionService.getUserCollections(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final collections = snapshot.data!;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _createAndAddToCollection,
                      icon: const Icon(Icons.add),
                      label: const Text('Create New Collection'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (collections.isEmpty)
                      const Center(
                        child: Text('No collections yet'),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: collections.length,
                          itemBuilder: (context, index) {
                            final collection = collections[index];
                            return ListTile(
                              leading: collection.emoji != null
                                  ? Text(
                                      collection.emoji!,
                                      style: const TextStyle(fontSize: 24),
                                    )
                                  : const Icon(Icons.folder),
                              title: Text(collection.name),
                              subtitle: Text(
                                '${collection.lessonCount} lessons',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                              onTap: () => _addToCollection(collection),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
} 