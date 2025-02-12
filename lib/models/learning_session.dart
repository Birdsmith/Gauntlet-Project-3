import 'package:cloud_firestore/cloud_firestore.dart';

class LearningSession {
  final String id;
  final String collectionId;
  final DateTime startedAt;
  final List<String> remainingLessonIds;
  final List<String> masteredLessonIds;
  final bool isCompleted;

  LearningSession({
    required this.id,
    required this.collectionId,
    required this.startedAt,
    required this.remainingLessonIds,
    required this.masteredLessonIds,
    required this.isCompleted,
  });

  factory LearningSession.create(String collectionId, List<String> lessonIds) {
    return LearningSession(
      id: '', // Will be set by Firestore
      collectionId: collectionId,
      startedAt: DateTime.now(),
      remainingLessonIds: List.from(lessonIds),
      masteredLessonIds: [],
      isCompleted: false,
    );
  }

  factory LearningSession.fromMap(Map<String, dynamic> map, String id) {
    return LearningSession(
      id: id,
      collectionId: map['collectionId'],
      startedAt: (map['startedAt'] as Timestamp).toDate(),
      remainingLessonIds: List<String>.from(map['remainingLessonIds']),
      masteredLessonIds: List<String>.from(map['masteredLessonIds']),
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'collectionId': collectionId,
      'startedAt': Timestamp.fromDate(startedAt),
      'remainingLessonIds': remainingLessonIds,
      'masteredLessonIds': masteredLessonIds,
      'isCompleted': isCompleted,
    };
  }

  LearningSession copyWith({
    String? id,
    String? collectionId,
    DateTime? startedAt,
    List<String>? remainingLessonIds,
    List<String>? masteredLessonIds,
    bool? isCompleted,
  }) {
    return LearningSession(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      startedAt: startedAt ?? this.startedAt,
      remainingLessonIds: remainingLessonIds ?? this.remainingLessonIds,
      masteredLessonIds: masteredLessonIds ?? this.masteredLessonIds,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
} 