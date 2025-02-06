import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String lessonId;
  final String userId;
  final String userDisplayName;
  final String text;
  final DateTime createdAt;
  final int likeCount;
  final List<String> likedByUserIds;

  Comment({
    required this.id,
    required this.lessonId,
    required this.userId,
    required this.userDisplayName,
    required this.text,
    required this.createdAt,
    this.likeCount = 0,
    this.likedByUserIds = const [],
  });

  factory Comment.fromMap(Map<String, dynamic> map, String id) {
    return Comment(
      id: id,
      lessonId: map['lessonId'] ?? '',
      userId: map['userId'] ?? '',
      userDisplayName: map['userDisplayName'] ?? '',
      text: map['text'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      likeCount: map['likeCount'] ?? 0,
      likedByUserIds: List<String>.from(map['likedByUserIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lessonId': lessonId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
      'likedByUserIds': likedByUserIds,
    };
  }

  Comment copyWith({
    String? lessonId,
    String? userId,
    String? userDisplayName,
    String? text,
    DateTime? createdAt,
    int? likeCount,
    List<String>? likedByUserIds,
  }) {
    return Comment(
      id: id,
      lessonId: lessonId ?? this.lessonId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      likedByUserIds: likedByUserIds ?? this.likedByUserIds,
    );
  }
} 