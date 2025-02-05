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

  // Delete a lesson's video
  Future<void> deleteLesson(String lessonId) async {
    try {
      final videoRef = _storage.ref().child('lessons/$lessonId/video.mp4');
      await videoRef.delete();
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
} 