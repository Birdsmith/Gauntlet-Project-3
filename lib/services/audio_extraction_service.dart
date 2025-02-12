import 'dart:io';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;

class AudioExtractionService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Extracts audio from a video file and returns the path to the audio file
  Future<String?> extractAudioFromVideo(String videoUrl, String lessonId) async {
    try {
      // Get temporary directory for storing the audio file
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/lesson_$lessonId.flac';

      // If we have a GCS URI, try to get the HTTPS URL first
      if (videoUrl.startsWith('gs://')) {
        try {
          final gsPath = videoUrl.replaceFirst('gs://${_storage.bucket}/', '');
          final httpsUrl = await _storage.ref(gsPath).getDownloadURL();
          videoUrl = httpsUrl;
          developer.log('Using HTTPS URL: $videoUrl');
        } catch (e) {
          developer.log('Failed to get HTTPS URL: $e');
        }
      }

      // Download video file to temporary storage
      final videoFile = File('${tempDir.path}/temp_video_$lessonId');
      await _storage.refFromURL(videoUrl).writeToFile(videoFile);

      developer.log('Starting audio extraction from video: ${videoFile.path}');
      developer.log('Output audio path: $outputPath');

      final session = await FFmpegKit.execute(
        '-i ${videoFile.path} -vn -acodec flac -ar 48000 -ac 2 -y $outputPath'
      );

      final returnCode = await session.getReturnCode();

      // Clean up the temporary video file
      if (await videoFile.exists()) {
        await videoFile.delete();
      }

      if (ReturnCode.isSuccess(returnCode)) {
        developer.log('Audio extraction successful');
        return outputPath;
      } else {
        final logs = await session.getLogs();
        throw Exception('FFmpeg process failed: ${logs.join('\n')}');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error extracting audio from video',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Uploads the extracted audio file to Firebase Storage
  /// Returns a map containing both the download URL and GCS URI
  Future<Map<String, String>?> uploadAudioFile(String audioPath, String lessonId) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('Audio file not found at $audioPath');
      }

      // Extract video ID from the video URL path
      final videoIdMatch = RegExp(r'videos/(\d+)/').firstMatch(lessonId);
      String folderPath;
      if (videoIdMatch != null) {
        // If lessonId contains a path, extract just the ID
        folderPath = videoIdMatch.group(0)!;
      } else {
        // If we have a raw lesson ID, construct the path
        folderPath = 'videos/$lessonId/';
      }

      final ref = _storage.ref().child('${folderPath}audio.flac');
      final gcsUri = 'gs://${_storage.bucket}/${folderPath}audio.flac';
      
      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(
          contentType: 'audio/flac',
          customMetadata: {
            'extractedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Clean up the temporary audio file
      await file.delete();

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return {
        'downloadUrl': downloadUrl,
        'gcsUri': gcsUri,
      };
    } catch (e, stackTrace) {
      developer.log(
        'Error uploading audio file',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
} 