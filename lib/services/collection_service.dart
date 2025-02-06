import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lesson_collection.dart';

class CollectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates a new collection for the current user
  Future<String> createCollection({
    required String name,
    required String description,
    String? emoji,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    // First ensure the user document exists
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final now = FieldValue.serverTimestamp();
    final docRef = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .add({
      'name': name,
      'description': description,
      'createdById': user.uid,
      'createdAt': now,
      'updatedAt': now,
      'lessonIds': [],
      'emoji': emoji,
      'lessonCount': 0,
    });

    return docRef.id;
  }

  /// Gets all collections for the current user
  Stream<List<LessonCollection>> getUserCollections() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LessonCollection.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Adds a lesson to a collection
  Future<void> addLessonToCollection(String collectionId, String lessonId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    final collectionRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .doc(collectionId);

    await _firestore.runTransaction((transaction) async {
      final collectionDoc = await transaction.get(collectionRef);
      if (!collectionDoc.exists) throw Exception('Collection not found');

      final lessonIds = List<String>.from(collectionDoc.data()?['lessonIds'] ?? []);
      if (!lessonIds.contains(lessonId)) {
        lessonIds.add(lessonId);
        transaction.update(collectionRef, {
          'lessonIds': lessonIds,
          'lessonCount': FieldValue.increment(1),
        });
      }
    });
  }

  /// Removes a lesson from a collection
  Future<void> removeLessonFromCollection(String collectionId, String lessonId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    final collectionRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .doc(collectionId);

    await _firestore.runTransaction((transaction) async {
      final collectionDoc = await transaction.get(collectionRef);
      if (!collectionDoc.exists) throw Exception('Collection not found');

      final lessonIds = List<String>.from(collectionDoc.data()?['lessonIds'] ?? []);
      if (lessonIds.contains(lessonId)) {
        lessonIds.remove(lessonId);
        transaction.update(collectionRef, {
          'lessonIds': lessonIds,
          'lessonCount': FieldValue.increment(-1),
        });
      }
    });
  }

  /// Updates a collection's details
  Future<void> updateCollection(String collectionId, {
    String? name,
    String? description,
    String? emoji,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (emoji != null) updates['emoji'] = emoji;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .doc(collectionId)
        .update(updates);
  }

  /// Deletes a collection
  Future<void> deleteCollection(String collectionId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .doc(collectionId)
        .delete();
  }

  /// Gets lessons in a specific collection
  Stream<List<String>> getCollectionLessonIds(String collectionId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .doc(collectionId)
        .snapshots()
        .map((doc) => List<String>.from(doc.data()?['lessonIds'] ?? []));
  }
} 