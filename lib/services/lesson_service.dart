import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/lesson.dart';
import 'dart:developer' as developer;

class LessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create a new lesson
  Future<String> createLesson({
    required String title,
    required String description,
    required String language,
    required String level,
    required String videoUrl,
    required List<String> topics,
    required double duration,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user found');

      String rawVideoUrl;
      String downloadUrl;
      
      if (videoUrl.startsWith('gs://')) {
        // If we receive a GCS URI, store it and get the download URL
        rawVideoUrl = videoUrl;
        try {
          final ref = _storage.refFromURL(videoUrl);
          downloadUrl = await ref.getDownloadURL();
        } catch (e) {
          developer.log('Error getting download URL for video: $e');
          throw Exception('Failed to get download URL for video');
        }
      } else if (videoUrl.startsWith('https://firebasestorage.googleapis.com')) {
        // If we receive an HTTPS URL, store it and extract the GCS URI
        downloadUrl = videoUrl;
        try {
          // Extract the path and convert to GCS URI
          final uri = Uri.parse(videoUrl);
          final pathSegments = uri.pathSegments;
          final bucket = pathSegments[1];  // After 'v0/b/'
          final encodedPath = pathSegments.sublist(3).join('/');  // After 'o/'
          final path = Uri.decodeComponent(encodedPath);
          rawVideoUrl = 'gs://$bucket/$path';
        } catch (e) {
          developer.log('Error converting HTTPS URL to GCS URI: $e');
          throw Exception('Failed to convert video URL to GCS URI');
        }
      } else {
        throw Exception('Invalid video URL format. Must be either a GCS URI or Firebase Storage HTTPS URL');
      }

      final docRef = await _firestore.collection('lessons').add({
        'title': title,
        'description': description,
        'language': language,
        'level': level,
        'videoUrl': downloadUrl,
        'rawVideoUrl': rawVideoUrl,  // Store the GCS URI
        'topics': topics,
        'duration': duration,
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user.uid,
        'createdByName': user.displayName ?? 'Anonymous',
        'viewCount': 0,
        'metadata': metadata,
      });
      
      return docRef.id;
    } catch (e) {
      developer.log('Error creating lesson: $e');
      throw Exception('Failed to create lesson: $e');
    }
  }

  // Get lessons filtered by languages and level
  Stream<List<Lesson>> getLessons({
    List<String>? languages,
    Map<String, String>? proficiencyLevels,
  }) {
    Query query = _firestore.collection('lessons');

    if (languages != null && languages.isNotEmpty) {
      query = query.where('language', whereIn: languages);
    }

    return query.orderBy('createdAt', descending: true).snapshots().asyncMap((snapshot) async {
      List<Lesson> lessons = [];
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          // Get the download URL for the video if it's a storage reference
          String? videoUrl = data['videoUrl'] as String?;
          if (videoUrl != null && videoUrl.startsWith('gs://')) {
            try {
              final ref = _storage.refFromURL(videoUrl);
              data['videoUrl'] = await ref.getDownloadURL();
            } catch (e) {
              developer.log('Error getting download URL for video: $e');
              continue; // Skip this lesson if we can't get the video URL
            }
          }
          lessons.add(Lesson.fromMap(data, doc.id));
        } catch (e) {
          developer.log('Error processing lesson document: $e');
          continue;
        }
      }
      return lessons;
    });
  }

  // Get lessons filtered by topics and languages
  Stream<List<Lesson>> getLessonsByTopics({
    required List<String> topics,
    List<String>? languages,
    Map<String, String>? proficiencyLevels,
  }) {
    Query query = _firestore.collection('lessons');

    if (languages != null && languages.isNotEmpty) {
      query = query.where('language', whereIn: languages);
    }

    if (topics.isNotEmpty) {
      query = query.where('topics', arrayContainsAny: topics);
    }

    return query.snapshots().asyncMap((snapshot) async {
      List<Lesson> lessons = [];
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          // Get the download URL for the video if it's a storage reference
          String? videoUrl = data['videoUrl'] as String?;
          if (videoUrl != null && videoUrl.startsWith('gs://')) {
            try {
              final ref = _storage.refFromURL(videoUrl);
              data['videoUrl'] = await ref.getDownloadURL();
            } catch (e) {
              developer.log('Error getting download URL for video: $e');
              continue; // Skip this lesson if we can't get the video URL
            }
          }
          lessons.add(Lesson.fromMap(data, doc.id));
        } catch (e) {
          developer.log('Error processing lesson document: $e');
          continue;
        }
      }
      return lessons;
    });
  }

  // Get lessons by creator
  Stream<List<Lesson>> getLessonsByCreator(String creatorId) {
    return _firestore
        .collection('lessons')
        .where('createdById', isEqualTo: creatorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Lesson.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Get popular lessons
  Stream<List<Lesson>> getPopularLessons({
    String? language,
    int limit = 10,
  }) {
    Query query = _firestore.collection('lessons');

    if (language != null) {
      query = query.where('language', isEqualTo: language);
    }

    return query
        .orderBy('viewCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Lesson.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  // Get all lessons (renamed to getAllLessons to avoid naming conflict)
  Stream<List<Lesson>> getAllLessons() {
    return _firestore
        .collection('lessons')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Lesson.fromMap(doc.data(), doc.id)).toList());
  }

  // Get lessons by IDs
  Stream<List<Lesson>> getLessonsByIds(List<String> ids) {
    if (ids.isEmpty) return Stream.value([]);
    
    return _firestore
        .collection('lessons')
        .where(FieldPath.documentId, whereIn: ids)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Lesson.fromMap(doc.data(), doc.id)).toList());
  }

  // Get lessons by level
  Stream<List<Lesson>> getLessonsByLevel(String level) {
    return _firestore
        .collection('lessons')
        .where('level', isEqualTo: level)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Lesson.fromMap(doc.data(), doc.id)).toList());
  }

  // Get lessons by language
  Stream<List<Lesson>> getLessonsByLanguage(String language) {
    return _firestore
        .collection('lessons')
        .where('language', isEqualTo: language)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Lesson.fromMap(doc.data(), doc.id)).toList());
  }

  // Get lessons by topic
  Stream<List<Lesson>> getLessonsByTopic(String topic) {
    return _firestore
        .collection('lessons')
        .where('topics', arrayContains: topic)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Lesson.fromMap(doc.data(), doc.id)).toList());
  }

  // Search lessons by query
  Stream<List<Lesson>> searchLessons(String query, {
    List<String>? languages,
    Map<String, String>? proficiencyLevels,
  }) {
    if (query.trim().isEmpty) {
      return getLessons(languages: languages, proficiencyLevels: proficiencyLevels);
    }

    final lowercaseQuery = query.toLowerCase();
    
    return _firestore
        .collection('lessons')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Lesson.fromMap(doc.data(), doc.id))
              .where((lesson) {
                final title = lesson.title.toLowerCase();
                final description = lesson.description.toLowerCase();
                final creatorName = lesson.createdByName.toLowerCase();
                
                return title.contains(lowercaseQuery) ||
                       description.contains(lowercaseQuery) ||
                       creatorName.contains(lowercaseQuery);
              })
              .where((lesson) => languages == null || 
                               languages.isEmpty || 
                               languages.contains(lesson.language))
              .toList();
        });
  }

  // Increment view count
  Future<void> incrementViewCount(String lessonId) async {
    await _firestore.collection('lessons').doc(lessonId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  /// Get a single lesson by ID
  Future<Lesson?> getLessonById(String lessonId) async {
    try {
      final doc = await _firestore.collection('lessons').doc(lessonId).get();
      if (!doc.exists) return null;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      // If we have a rawVideoUrl, keep it
      String? rawVideoUrl = data['rawVideoUrl'] as String?;
      
      // Get the download URL for the video if it's a storage reference
      String? videoUrl = data['videoUrl'] as String?;
      if (videoUrl != null && videoUrl.startsWith('gs://')) {
        try {
          final ref = _storage.refFromURL(videoUrl);
          data['videoUrl'] = await ref.getDownloadURL();
        } catch (e) {
          developer.log('Error getting download URL for video: $e');
          return null;
        }
      }

      // If we don't have a rawVideoUrl but have an HTTPS URL, try to convert it
      if (rawVideoUrl == null && videoUrl != null && videoUrl.startsWith('https://firebasestorage.googleapis.com')) {
        try {
          final uri = Uri.parse(videoUrl);
          final pathSegments = uri.pathSegments;
          final bucket = pathSegments[1];  // After 'v0/b/'
          final encodedPath = pathSegments.sublist(3).join('/');  // After 'o/'
          final path = Uri.decodeComponent(encodedPath);
          data['rawVideoUrl'] = 'gs://$bucket/$path';
        } catch (e) {
          developer.log('Error converting HTTPS URL to GCS URI: $e');
        }
      }

      return Lesson.fromMap(data, doc.id);
    } catch (e) {
      developer.log('Error getting lesson by ID: $e');
      return null;
    }
  }
} 