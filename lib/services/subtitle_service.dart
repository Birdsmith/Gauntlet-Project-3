import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';

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
    // Ensure content is properly decoded UTF-8
    content = content.replaceAll('\r\n', '\n');
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
        
        // Parse subtitle text with proper encoding handling
        String text = '';
        while (currentLine < lines.length && 
               lines[currentLine].trim().isNotEmpty && 
               !lines[currentLine].contains('-->')) {
          if (text.isNotEmpty) text += '\n';
          final line = lines[currentLine].trim();
          // Log each subtitle line for debugging
          developer.log('Subtitle line (${line.length} chars): $line');
          developer.log('Line codeUnits: ${line.codeUnits}');
          text += line;
          currentLine++;
        }
        
        if (text.isNotEmpty) {
          // Clean any potential invalid characters
          text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
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
        throw Exception('Failed to load subtitles: ${response.statusCode}');
      }

      // Explicitly decode the response body as UTF-8
      final decodedContent = utf8.decode(response.bodyBytes, allowMalformed: true);
      developer.log('Loaded subtitle content (first 100 chars): ${decodedContent.substring(0, min(100, decodedContent.length))}');
      
      return parseWebVTT(decodedContent);
    } catch (e) {
      throw Exception('Failed to load subtitles: $e');
    }
  }
} 