import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'dart:convert';

class Subtitle {
  final int index;
  final Duration start;
  final Duration end;
  final String text;

  Subtitle({
    required this.index,
    required this.start,
    required this.end,
    required this.text,
  });
}

class SubtitleService {
  // Parse WebVTT content into a list of Subtitle objects
  List<Subtitle> parseWebVTT(String content) {
    final List<Subtitle> subtitles = [];
    final List<String> lines = content.split('\n');
    
    int index = 0;
    int currentLine = 0;
    
    developer.log('Parsing WebVTT content with ${lines.length} lines');
    
    // Skip WebVTT header and metadata
    while (currentLine < lines.length && !lines[currentLine].contains('-->')) {
      currentLine++;
    }
    
    while (currentLine < lines.length) {
      try {
        // Skip empty lines
        while (currentLine < lines.length && lines[currentLine].trim().isEmpty) {
          currentLine++;
        }
        
        if (currentLine >= lines.length) break;
        
        // Parse timestamp line
        final String timestampLine = lines[currentLine];
        developer.log('Processing timestamp line: $timestampLine');
        final List<String> timestamps = timestampLine.split('-->');
        if (timestamps.length != 2) {
          currentLine++;
          continue;
        }
        
        final Duration start = _parseTimestamp(timestamps[0].trim());
        final Duration end = _parseTimestamp(timestamps[1].trim());
        developer.log('Parsed timestamps - Start: $start, End: $end');
        
        currentLine++;
        
        // Parse subtitle text
        String text = '';
        while (currentLine < lines.length && 
               lines[currentLine].trim().isNotEmpty && 
               !lines[currentLine].contains('-->')) {
          if (text.isNotEmpty) text += '\n';
          final line = lines[currentLine].trim();
          // Log each subtitle line for debugging
          developer.log('Subtitle line: $line (length: ${line.length}, codeUnits: ${line.codeUnits})');
          text += line;
          currentLine++;
        }
        
        if (text.isNotEmpty) {
          developer.log('Adding subtitle - Index: $index, Text: $text');
          subtitles.add(Subtitle(
            index: index++,
            start: start,
            end: end,
            text: text,
          ));
        }
      } catch (e) {
        developer.log('Error parsing subtitle entry: $e');
        // Skip malformed entries
        while (currentLine < lines.length && !lines[currentLine].contains('-->')) {
          currentLine++;
        }
      }
    }
    
    developer.log('Finished parsing WebVTT. Found ${subtitles.length} subtitles');
    return subtitles;
  }
  
  // Parse WebVTT timestamp into Duration
  Duration _parseTimestamp(String timestamp) {
    developer.log('Parsing timestamp: $timestamp');
    try {
      final parts = timestamp.split(':');
      if (parts.length != 3) {
        throw FormatException('Invalid timestamp format: expected HH:MM:SS.mmm, got $timestamp');
      }
      
      final hours = int.tryParse(parts[0]);
      final minutes = int.tryParse(parts[1]);
      if (hours == null || minutes == null || minutes >= 60) {
        throw FormatException('Invalid hours/minutes in timestamp: $timestamp');
      }
      
      final secondsAndMillis = parts[2].split('.');
      if (secondsAndMillis.isEmpty || secondsAndMillis.length > 2) {
        throw FormatException('Invalid seconds format in timestamp: $timestamp');
      }
      
      final seconds = int.tryParse(secondsAndMillis[0]);
      if (seconds == null || seconds >= 60) {
        throw FormatException('Invalid seconds in timestamp: $timestamp');
      }
      
      final milliseconds = secondsAndMillis.length > 1 
          ? int.tryParse(secondsAndMillis[1].padRight(3, '0').substring(0, 3))
          : 0;
      
      if (milliseconds == null || milliseconds >= 1000) {
        throw FormatException('Invalid milliseconds in timestamp: $timestamp');
      }
      
      final duration = Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
      developer.log('Parsed timestamp $timestamp to duration: $duration');
      return duration;
    } catch (e) {
      developer.log('Error parsing timestamp: $e');
      rethrow;
    }
  }

  // Load subtitles from a URL
  Future<List<Subtitle>> loadSubtitlesFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to load subtitles: HTTP ${response.statusCode}');
      }
      
      if (response.body.isEmpty) {
        throw Exception('Empty subtitle file received');
      }

      // Check for UTF-8 BOM and remove if present
      List<int> bytes = response.bodyBytes;
      if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        bytes = bytes.sublist(3);
      }
      
      // Decode as UTF-8
      String content = const Utf8Decoder().convert(bytes);
      
      // Log the first few lines for debugging
      developer.log('First 200 characters of subtitle content: ${content.substring(0, content.length > 200 ? 200 : content.length)}');
      
      if (!content.trim().startsWith('WEBVTT')) {
        throw FormatException('Invalid WebVTT file: missing WEBVTT header');
      }

      // Clean any invalid UTF-8 sequences
      content = content.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
      
      return parseWebVTT(content);
    } catch (e) {
      developer.log('Error loading subtitles from URL: $url', error: e);
      throw Exception('Error loading subtitles: $e');
    }
  }
} 