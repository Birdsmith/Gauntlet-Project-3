import 'package:cloud_functions/cloud_functions.dart';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

class TranscriptionService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Start transcription/translation of a video
  /// If targetLanguage is specified, translates to that language
  /// If not specified, transcribes in the original language
  Future<Map<String, dynamic>> transcribeVideo(
    DocumentReference lessonRef,
    String? targetLanguage,
  ) async {
    try {
      developer.log('Starting transcription/translation to ${targetLanguage ?? 'original language'}');

      // Call the Cloud Function with the lesson reference path and target language
      final callable = _functions.httpsCallable('transcribeVideo');
      final result = await callable.call({
        'lessonPath': lessonRef.path,
        'targetLanguage': targetLanguage,
      });

      return result.data as Map<String, dynamic>;
    } catch (e) {
      developer.log('Error in transcription service: $e');
      rethrow;
    }
  }

  /// Generate a summary for a lesson in the specified language
  Future<String?> generateSummary(
    DocumentReference lessonRef,
    String language,
  ) async {
    try {
      developer.log('Generating summary in $language');

      final callable = _functions.httpsCallable('generateLessonSummary');
      final result = await callable.call({
        'lessonPath': lessonRef.path,
        'language': language,
      });

      final data = result.data as Map<String, dynamic>;
      return data['summary'] as String?;
    } catch (e) {
      developer.log('Error generating summary: $e');
      return null;
    }
  }

  // Check transcription status
  Future<Map<String, dynamic>> getTranscriptionStatus(DocumentReference lessonRef) async {
    try {
      final result = await _functions.httpsCallable('getTranscriptionStatus').call({
        'lessonPath': lessonRef.path,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      developer.log('Error checking transcription status: $e');
      throw Exception('Failed to check transcription status: $e');
    }
  }

  // Get transcription results including detected languages
  Future<Map<String, dynamic>> getTranscriptionResults(DocumentReference lessonRef) async {
    try {
      final result = await _functions.httpsCallable('getTranscriptionResults').call({
        'lessonPath': lessonRef.path,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      developer.log('Error getting transcription results: $e');
      throw Exception('Failed to get transcription results: $e');
    }
  }
} 