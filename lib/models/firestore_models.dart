import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final List<String> targetLanguages;
  final Map<String, String> proficiencyLevels;
  final String nativeLanguage;
  final int currentStreak;
  final DateTime lastPracticeDate;
  final Map<String, dynamic> preferences;
  final bool onboardingComplete;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.targetLanguages,
    required this.proficiencyLevels,
    required this.nativeLanguage,
    this.currentStreak = 0,
    required this.lastPracticeDate,
    this.preferences = const {},
    this.onboardingComplete = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'targetLanguages': targetLanguages,
      'proficiencyLevels': proficiencyLevels,
      'nativeLanguage': nativeLanguage,
      'currentStreak': currentStreak,
      'lastPracticeDate': Timestamp.fromDate(lastPracticeDate),
      'preferences': preferences,
      'onboardingComplete': onboardingComplete,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      email: map['email'],
      displayName: map['displayName'],
      targetLanguages: List<String>.from(map['targetLanguages'] ?? []),
      proficiencyLevels: Map<String, String>.from(map['proficiencyLevels'] ?? {}),
      nativeLanguage: map['nativeLanguage'],
      currentStreak: map['currentStreak'] ?? 0,
      lastPracticeDate: (map['lastPracticeDate'] as Timestamp).toDate(),
      preferences: map['preferences'] ?? {},
      onboardingComplete: map['onboardingComplete'] ?? false,
    );
  }
} 