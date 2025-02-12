import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/learning_session.dart';

class LearningSessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates a new learning session for a collection
  Future<LearningSession> createSession(String collectionId, List<String> lessonIds) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    // Create the session document
    final session = LearningSession.create(collectionId, lessonIds);
    final docRef = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('learning_sessions')
        .add(session.toMap());

    return session.copyWith(id: docRef.id);
  }

  /// Updates a learning session with a lesson result
  Future<LearningSession> updateSessionProgress(
    String sessionId,
    String lessonId,
    bool understood,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    final sessionRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('learning_sessions')
        .doc(sessionId);

    late final LearningSession updatedSession;
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(sessionRef);
      if (!doc.exists) throw Exception('Session not found');

      final session = LearningSession.fromMap(doc.data()!, doc.id);
      List<String> remainingLessonIds = List.from(session.remainingLessonIds);
      List<String> masteredLessonIds = List.from(session.masteredLessonIds);

      remainingLessonIds.remove(lessonId);
      if (understood) {
        masteredLessonIds.add(lessonId);
      } else {
        remainingLessonIds.add(lessonId); // Add back to the end for review
      }

      final isCompleted = remainingLessonIds.isEmpty;
      final updates = {
        'remainingLessonIds': remainingLessonIds,
        'masteredLessonIds': masteredLessonIds,
        'isCompleted': isCompleted,
      };

      transaction.update(sessionRef, updates);
      updatedSession = session.copyWith(
        remainingLessonIds: remainingLessonIds,
        masteredLessonIds: masteredLessonIds,
        isCompleted: isCompleted,
      );
    });

    return updatedSession;
  }

  /// Gets the current learning session
  Stream<LearningSession?> getCurrentSession(String sessionId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('learning_sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => doc.exists ? LearningSession.fromMap(doc.data()!, doc.id) : null);
  }

  /// Deletes a learning session
  Future<void> deleteSession(String sessionId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('learning_sessions')
        .doc(sessionId)
        .delete();
  }
} 