import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;

class TranscriptionService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Start transcription with automatic language detection
  Future<void> transcribeAudio(String lessonId) async {
    try {
      // Call the Cloud Function that will trigger the Speech-to-Text process
      final result = await _functions.httpsCallable('transcribeAudio').call({
        'lessonId': lessonId,
        'config': {
          'autoDetectLanguage': true, // Enable automatic language detection
          'multipleLanguages': true,  // Allow detection of multiple languages
          'model': 'latest_long',     // Use the latest model for best accuracy
          'useEnhanced': true,        // Use enhanced model for better quality
        }
      });

      developer.log('Transcription started: ${result.data}');
    } catch (e) {
      developer.log('Error starting transcription: $e');
      throw Exception('Failed to start transcription: $e');
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