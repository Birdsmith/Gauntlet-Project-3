import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Converts a Firebase Storage HTTPS URL to a GCS URI
  /// Returns null if the URL is not a valid Firebase Storage URL
  static String? httpsToGcsUri(String httpsUrl) {
    try {
      if (!httpsUrl.startsWith('https://firebasestorage.googleapis.com')) {
        return null;
      }

      final uri = Uri.parse(httpsUrl);
      final pathSegments = uri.pathSegments;
      
      // Path segments should be ['v0', 'b', 'bucket-name.firebasestorage.app', 'o', 'path', 'to', 'file']
      if (pathSegments.length < 4) {
        return null;
      }

      // The bucket name is the full domain (e.g., 'gauntlet-project-3.firebasestorage.app')
      final bucket = pathSegments[2];  // After 'v0/b/'
      
      // Get everything after 'o/' in the path
      final encodedPath = pathSegments.sublist(4).join('/');  // After 'o/'
      final path = Uri.decodeComponent(encodedPath);
      
      print('DEBUG: Converting URL to GCS URI:');
      print('DEBUG: Bucket: $bucket');
      print('DEBUG: Path: $path');
      
      return 'gs://$bucket/$path';
    } catch (e) {
      print('Error converting HTTPS URL to GCS URI: $e');
      return null;
    }
  }

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

  // Get the subtitle URL for a given lesson and language
  Future<String> getSubtitleUrl(String lessonId, String languageCode) async {
    try {
      // Get the lesson document to find the video path
      final lessonDoc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(lessonId)
          .get();
      
      if (!lessonDoc.exists) {
        throw Exception('Lesson not found');
      }

      final lessonData = lessonDoc.data();
      if (lessonData == null) {
        throw Exception('Lesson data is null');
      }

      // Get the video URL (try both rawVideoUrl and videoUrl)
      final videoUrl = lessonData['rawVideoUrl'] ?? lessonData['videoUrl'];
      if (videoUrl == null) {
        throw Exception('Video URL not found in lesson');
      }

      // Extract the lesson ID from the video path
      final videoPathMatch = RegExp(r'videos/(\d+)/').firstMatch(videoUrl);
      if (videoPathMatch == null) {
        throw Exception('Invalid video path format');
      }

      // Construct the subtitle path directly
      final subtitlePath = 'videos/${videoPathMatch.group(1)}/subtitles/$languageCode.vtt';
      
      // Create a reference to the subtitle location
      final subtitleRef = _storage.ref().child(subtitlePath);
      
      try {
        // Get the download URL with a longer timeout
        final downloadUrl = await subtitleRef.getDownloadURL();
        return downloadUrl;
      } catch (e) {
        throw Exception('Subtitle file not found: $e');
      }
    } catch (e) {
      throw Exception('Failed to get subtitle URL: $e');
    }
  }

  // List available subtitle languages for a lesson
  Future<List<String>> listSubtitleLanguages(String lessonId) async {
    try {
      // Get the lesson document to find the video path
      final lessonDoc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(lessonId)
          .get();
      
      if (!lessonDoc.exists) {
        return [];
      }

      final lessonData = lessonDoc.data();
      if (lessonData == null) {
        return [];
      }

      final videoPath = lessonData['rawVideoUrl'] ?? lessonData['videoUrl'];
      if (videoPath == null) {
        return [];
      }

      // Extract the folder path from the video URL
      final folderMatch = RegExp(r'videos/\d+/').firstMatch(videoPath.toString());
      if (folderMatch == null) {
        return [];
      }
      final folderPath = folderMatch.group(0)!;

      // List files in the subtitles subfolder
      final subtitlesRef = _storage.ref().child('${folderPath}subtitles');
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