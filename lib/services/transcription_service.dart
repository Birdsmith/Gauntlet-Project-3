import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'audio_extraction_service.dart';

class TranscriptionService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AudioExtractionService _audioExtractor = AudioExtractionService();

  /// Start transcription of a video
  Future<Map<String, dynamic>> transcribeVideo(String lessonId) async {
    try {
      print('DEBUG: Starting transcription');
      
      // Get the lesson document to get the video URL
      final lessonDoc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(lessonId)
          .get();
      
      if (!lessonDoc.exists) {
        throw Exception('Lesson not found');
      }

      final lessonData = lessonDoc.data();
      final videoUrl = lessonData?['videoUrl'];

      print('DEBUG: Video URL: $videoUrl');

      // Extract audio from video
      final audioPath = await _audioExtractor.extractAudioFromVideo(videoUrl, lessonId);
      if (audioPath == null) {
        throw Exception('Failed to extract audio from video');
      }

      // Upload audio file to Firebase Storage
      final audioUrls = await _audioExtractor.uploadAudioFile(audioPath, lessonId);
      if (audioUrls == null) {
        throw Exception('Failed to upload audio file');
      }

      // Update lesson document with audio URLs
      await FirebaseFirestore.instance
          .collection('lessons')
          .doc(lessonId)
          .update({
        'audioUrl': audioUrls['downloadUrl'],
        'rawAudioUrl': audioUrls['gcsUri'],
        'transcription': {
          'status': 'processing',
          'updatedAt': FieldValue.serverTimestamp(),
        }
      });

      // Call the Cloud Function with the GCS URI
      final callable = _functions.httpsCallable('transcribeVideo');
      final result = await callable.call({
        'videoId': lessonId,
        'audioUrl': audioUrls['gcsUri'],
      });
      
      print('DEBUG: Transcription service response: ${result.data}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('Error calling transcribeVideo function: $e');
      rethrow;
    }
  }

  // Check transcription status
  Future<Map<String, dynamic>> getTranscriptionStatus(String lessonId) async {
    try {
      final result = await _functions.httpsCallable('getTranscriptionStatus').call({
        'lessonId': lessonId,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      developer.log('Error checking transcription status: $e');
      throw Exception('Failed to check transcription status: $e');
    }
  }

  // Get transcription results including detected languages
  Future<Map<String, dynamic>> getTranscriptionResults(String lessonId) async {
    try {
      final result = await _functions.httpsCallable('getTranscriptionResults').call({
        'lessonId': lessonId,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      developer.log('Error getting transcription results: $e');
      throw Exception('Failed to get transcription results: $e');
    }
  }
} 