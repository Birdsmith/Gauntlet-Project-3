import 'package:cloud_firestore/cloud_firestore.dart';

class Lesson {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String level;
  final double duration;
  final String language;
  final List<String> topics;
  final int viewCount;
  final DateTime createdAt;
  final String createdById;
  final String createdByName;
  final Map<String, dynamic>? metadata;

  Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.level,
    required this.duration,
    required this.language,
    required this.topics,
    required this.viewCount,
    required this.createdAt,
    required this.createdById,
    required this.createdByName,
    this.metadata,
  });

  // Create from Firestore document
  factory Lesson.fromMap(Map<String, dynamic> map, String id) {
    return Lesson(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      level: map['level'] ?? 'A1',
      duration: (map['duration'] ?? 0).toDouble(),
      language: map['language'] ?? '',
      topics: List<String>.from(map['topics'] ?? []),
      viewCount: map['viewCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdById: map['createdById'] ?? '',
      createdByName: map['createdByName'] ?? '',
      metadata: map['metadata'],
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'level': level,
      'duration': duration,
      'language': language,
      'topics': topics,
      'viewCount': viewCount,
      'createdAt': createdAt,
      'createdById': createdById,
      'createdByName': createdByName,
      'metadata': metadata,
    };
  }

  // Create a copy of the lesson with updated fields
  Lesson copyWith({
    String? title,
    String? description,
    String? videoUrl,
    String? level,
    double? duration,
    String? language,
    List<String>? topics,
    int? viewCount,
    DateTime? createdAt,
    String? createdById,
    String? createdByName,
    Map<String, dynamic>? metadata,
  }) {
    return Lesson(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      level: level ?? this.level,
      duration: duration ?? this.duration,
      language: language ?? this.language,
      topics: topics ?? this.topics,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      metadata: metadata ?? this.metadata,
    );
  }
} 