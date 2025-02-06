import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload a video file and return the download URL
  Future<String> uploadVideo(File videoFile, String lessonId) async {
    try {
      // Create a reference to the video location
      final videoRef = _storage.ref().child('lessons/$lessonId/video.mp4');
      
      // Upload the file
      final uploadTask = await videoRef.putFile(
        videoFile,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Get the download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  // Upload a subtitle file and return the download URL
  Future<String> uploadSubtitle(File subtitleFile, String lessonId, String languageCode) async {
    try {
      // Create a reference to the subtitle location
      final subtitleRef = _storage.ref().child('lessons/$lessonId/subtitles/$languageCode.vtt');
      
      // Upload the file
      final uploadTask = await subtitleRef.putFile(
        subtitleFile,
        SettableMetadata(
          contentType: 'text/vtt',
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'language': languageCode,
          },
        ),
      );

      // Get the download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload subtitle: $e');
    }
  }

  // Delete a lesson's video and subtitles
  Future<void> deleteLesson(String lessonId) async {
    try {
      // Delete video
      final videoRef = _storage.ref().child('lessons/$lessonId/video.mp4');
      await videoRef.delete();

      // Delete subtitles folder
      final subtitlesRef = _storage.ref().child('lessons/$lessonId/subtitles');
      try {
        final items = await subtitlesRef.listAll();
        await Future.wait(items.items.map((ref) => ref.delete()));
      } catch (e) {
        // Ignore if subtitles folder doesn't exist
      }
    } catch (e) {
      throw Exception('Failed to delete lesson: $e');
    }
  }

  // Get the download URL for a video
  Future<String> getVideoUrl(String lessonId) async {
    try {
      final videoRef = _storage.ref().child('lessons/$lessonId/video.mp4');
      return await videoRef.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to get video URL: $e');
    }
  }

  // Get the download URL for a subtitle file
  Future<String> getSubtitleUrl(String lessonId, String languageCode) async {
    try {
      final subtitleRef = _storage.ref().child('lessons/$lessonId/subtitles/$languageCode.vtt');
      return await subtitleRef.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to get subtitle URL: $e');
    }
  }

  // List available subtitle languages for a lesson
  Future<List<String>> listSubtitleLanguages(String lessonId) async {
    try {
      final subtitlesRef = _storage.ref().child('lessons/$lessonId/subtitles');
      final result = await subtitlesRef.listAll();
      return result.items.map((ref) {
        final filename = ref.name;
        return filename.substring(0, filename.lastIndexOf('.'));
      }).toList();
    } catch (e) {
      return [];
    }
  }
} 