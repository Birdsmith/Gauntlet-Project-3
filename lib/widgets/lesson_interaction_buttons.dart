import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../services/interaction_service.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/add_to_collection_sheet.dart';
import 'dart:developer' as developer;

class LessonInteractionButtons extends StatefulWidget {
  final Lesson lesson;
  final InteractionService interactionService;

  const LessonInteractionButtons({
    super.key,
    required this.lesson,
    required this.interactionService,
  });

  @override
  State<LessonInteractionButtons> createState() => _LessonInteractionButtonsState();
}

class _LessonInteractionButtonsState extends State<LessonInteractionButtons> {
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInteractionState();
  }

  Future<void> _loadInteractionState() async {
    try {
      final hasLiked = await widget.interactionService.hasLikedLesson(widget.lesson.id);
      final hasSaved = await widget.interactionService.hasSavedLesson(widget.lesson.id);
      
      if (mounted) {
        setState(() {
          _isLiked = hasLiked;
          _isSaved = hasSaved;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error loading interaction state',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading interaction state: $e')),
        );
      }
    }
  }

  Future<void> _toggleLike() async {
    try {
      await widget.interactionService.toggleLikeLesson(widget.lesson.id);
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleSave() async {
    try {
      await widget.interactionService.toggleSaveLesson(widget.lesson.id);
      if (mounted) {
        setState(() {
          _isSaved = !_isSaved;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _showAddToCollectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddToCollectionSheet(lesson: widget.lesson),
      ),
    );
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => CommentsSheet(
          lesson: widget.lesson,
          interactionService: widget.interactionService,
          scrollController: controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            color: _isLiked ? Colors.red : null,
          ),
          onPressed: _isLoading ? null : _toggleLike,
          tooltip: 'Like',
        ),
        IconButton(
          icon: Icon(
            _isSaved ? Icons.bookmark : Icons.bookmark_border,
            color: _isSaved ? Colors.blue : null,
          ),
          onPressed: _isLoading ? null : _toggleSave,
          tooltip: 'Save',
        ),
        IconButton(
          icon: const Icon(Icons.folder),
          onPressed: _isLoading ? null : _showAddToCollectionSheet,
          tooltip: 'Add to Collection',
        ),
        IconButton(
          icon: const Icon(Icons.comment_outlined),
          onPressed: _isLoading ? null : _showComments,
          tooltip: 'Comments',
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: _isLoading ? null : () => widget.interactionService.shareLesson(widget.lesson),
          tooltip: 'Share',
        ),
      ],
    );
  }
} 