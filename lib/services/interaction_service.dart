import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/comment.dart';
import '../models/lesson.dart';

class InteractionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Toggles the like status of a lesson for the current user.
  /// Throws an exception if the user is not logged in or if the lesson doesn't exist.
  Future<void> toggleLikeLesson(String lessonId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    final userLikesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('likedLessons')
        .doc(lessonId);

    final lessonRef = _firestore.collection('lessons').doc(lessonId);

    return _firestore.runTransaction((transaction) async {
      final userLikeDoc = await transaction.get(userLikesRef);
      final lessonDoc = await transaction.get(lessonRef);

      if (!lessonDoc.exists) throw Exception('Lesson not found');
      
      if (userLikeDoc.exists) {
        // Unlike
        transaction.delete(userLikesRef);
        transaction.update(lessonRef, {
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        // Like
        transaction.set(userLikesRef, {
          'timestamp': FieldValue.serverTimestamp(),
        });
        transaction.update(lessonRef, {
          'likeCount': FieldValue.increment(1),
        });
      }
    });
  }

  /// Toggles the save status of a lesson for the current user.
  /// Throws an exception if the user is not logged in or if the lesson doesn't exist.
  Future<void> toggleSaveLesson(String lessonId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    final userSavesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedLessons')
        .doc(lessonId);

    final lessonRef = _firestore.collection('lessons').doc(lessonId);

    return _firestore.runTransaction((transaction) async {
      final userSaveDoc = await transaction.get(userSavesRef);
      final lessonDoc = await transaction.get(lessonRef);

      if (!lessonDoc.exists) throw Exception('Lesson not found');
      
      if (userSaveDoc.exists) {
        // Unsave
        transaction.delete(userSavesRef);
        transaction.update(lessonRef, {
          'saveCount': FieldValue.increment(-1),
        });
      } else {
        // Save
        transaction.set(userSavesRef, {
          'timestamp': FieldValue.serverTimestamp(),
        });
        transaction.update(lessonRef, {
          'saveCount': FieldValue.increment(1),
        });
      }
    });
  }

  /// Adds a comment to a lesson.
  /// Throws an exception if the user is not logged in.
  Future<Comment> addComment(String lessonId, String text) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    if (text.trim().isEmpty) {
      throw Exception('Comment text cannot be empty');
    }

    final commentRef = _firestore
        .collection('lessons')
        .doc(lessonId)
        .collection('comments')
        .doc();

    final lessonRef = _firestore.collection('lessons').doc(lessonId);

    final comment = Comment(
      id: commentRef.id,
      lessonId: lessonId,
      userId: user.uid,
      userDisplayName: user.displayName ?? 'Anonymous',
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await _firestore.runTransaction((transaction) async {
        final lessonDoc = await transaction.get(lessonRef);
        if (!lessonDoc.exists) throw Exception('Lesson not found');

        transaction.set(commentRef, comment.toMap());
        transaction.update(lessonRef, {
          'commentCount': FieldValue.increment(1),
        });
      });

      return comment;
    } catch (e) {
      debugPrint('Error adding comment: $e');
      throw Exception('Failed to add comment: ${e.toString()}');
    }
  }

  /// Gets a stream of comments for a lesson, ordered by creation time.
  Stream<List<Comment>> getComments(String lessonId) {
    return _firestore
        .collection('lessons')
        .doc(lessonId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Checks if the current user has liked a lesson.
  /// Returns false if the user is not logged in.
  Future<bool> hasLikedLesson(String lessonId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedLessons')
          .doc(lessonId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('Error checking liked status: $e');
      return false;
    }
  }

  /// Checks if the current user has saved a lesson.
  /// Returns false if the user is not logged in.
  Future<bool> hasSavedLesson(String lessonId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedLessons')
          .doc(lessonId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('Error checking saved status: $e');
      return false;
    }
  }

  /// Gets a stream of lesson IDs that the current user has saved.
  /// Returns an empty stream if the user is not logged in.
  Stream<List<String>> getSavedLessonIds() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedLessons')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Shares a lesson using the system share sheet.
  /// Throws an exception if sharing fails.
  Future<void> shareLesson(Lesson lesson) async {
    try {
      final shareText = '${lesson.title}\n\n${lesson.description}\n\nWatch this lesson on our app!';
      await Share.share(shareText, subject: lesson.title);
    } catch (e) {
      debugPrint('Error sharing lesson: $e');
      throw Exception('Failed to share lesson: ${e.toString()}');
    }
  }
} 