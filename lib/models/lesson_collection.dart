import 'package:cloud_firestore/cloud_firestore.dart';

class LessonCollection {
  final String id;
  final String name;
  final String description;
  final String createdById;
  final DateTime createdAt;
  final List<String> lessonIds;
  final String? emoji;
  final int lessonCount;

  LessonCollection({
    required this.id,
    required this.name,
    required this.description,
    required this.createdById,
    required this.createdAt,
    required this.lessonIds,
    this.emoji,
    this.lessonCount = 0,
  });

  factory LessonCollection.fromMap(Map<String, dynamic> map, String id) {
    return LessonCollection(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      createdById: map['createdById'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lessonIds: List<String>.from(map['lessonIds'] ?? []),
      emoji: map['emoji'],
      lessonCount: map['lessonCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdById': createdById,
      'createdAt': Timestamp.fromDate(createdAt),
      'lessonIds': lessonIds,
      'emoji': emoji,
      'lessonCount': lessonCount,
    };
  }

  LessonCollection copyWith({
    String? name,
    String? description,
    String? createdById,
    DateTime? createdAt,
    List<String>? lessonIds,
    String? emoji,
    int? lessonCount,
  }) {
    return LessonCollection(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      lessonIds: lessonIds ?? this.lessonIds,
      emoji: emoji ?? this.emoji,
      lessonCount: lessonCount ?? this.lessonCount,
    );
  }
} 