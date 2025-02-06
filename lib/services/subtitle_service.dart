import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;

class SubtitleService {
  // Parse WebVTT content into a list of Subtitle objects
  List<Subtitle> parseWebVTT(String content) {
    final List<Subtitle> subtitles = [];
    final List<String> lines = content.split('\n');
    
    int index = 0;
    int currentLine = 0;
    
    // Skip WebVTT header
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
        final List<String> timestamps = timestampLine.split('-->');
        if (timestamps.length != 2) {
          currentLine++;
          continue;
        }
        
        final Duration start = _parseTimestamp(timestamps[0].trim());
        final Duration end = _parseTimestamp(timestamps[1].trim());
        
        currentLine++;
        
        // Parse subtitle text
        String text = '';
        while (currentLine < lines.length && 
               lines[currentLine].trim().isNotEmpty && 
               !lines[currentLine].contains('-->')) {
          if (text.isNotEmpty) text += '\n';
          text += lines[currentLine].trim();
          currentLine++;
        }
        
        if (text.isNotEmpty) {
          subtitles.add(Subtitle(
            index: index++,
            start: start,
            end: end,
            text: text,
          ));
        }
      } catch (e) {
        // Skip malformed entries
        while (currentLine < lines.length && !lines[currentLine].contains('-->')) {
          currentLine++;
        }
      }
    }
    
    return subtitles;
  }
  
  // Parse WebVTT timestamp into Duration
  Duration _parseTimestamp(String timestamp) {
    // Handle both HH:MM:SS.mmm and MM:SS.mmm formats
    final parts = timestamp.split(':');
    if (parts.length < 2 || parts.length > 3) {
      throw FormatException('Invalid timestamp format: $timestamp');
    }
    
    int hours = 0;
    int minutes = 0;
    double seconds = 0;
    
    if (parts.length == 3) {
      hours = int.parse(parts[0]);
      minutes = int.parse(parts[1]);
      seconds = double.parse(parts[2]);
    } else {
      minutes = int.parse(parts[0]);
      seconds = double.parse(parts[1]);
    }
    
    return Duration(
      hours: hours,
      minutes: minutes,
      milliseconds: (seconds * 1000).round(),
    );
  }
  
  // Load subtitles from a URL
  Future<List<Subtitle>> loadSubtitlesFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return parseWebVTT(response.body);
      } else {
        throw Exception('Failed to load subtitles: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load subtitles: $e');
    }
  }
} 