import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/firestore_models.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference<Map<String, dynamic>> get _users => 
      _firestore.collection('users');

  // Create or update user profile
  Future<void> createOrUpdateUserProfile({
    required String email,
    required String displayName,
    List<String>? targetLanguages,
    Map<String, String>? proficiencyLevels,
    String? nativeLanguage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final userProfile = UserProfile(
      id: user.uid,
      email: email,
      displayName: displayName,
      targetLanguages: targetLanguages ?? [],
      proficiencyLevels: proficiencyLevels ?? {},
      nativeLanguage: nativeLanguage ?? '',
      lastPracticeDate: DateTime.now(),
    );

    final userData = userProfile.toMap();
    // Set onboardingComplete to true if user has completed language selection
    if (targetLanguages != null && proficiencyLevels != null && nativeLanguage != null) {
      userData['onboardingComplete'] = true;
    }

    await _users.doc(user.uid).set(userData, SetOptions(merge: true));
  }

  // Get user profile
  Future<UserProfile?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _users.doc(user.uid).get();
    if (!doc.exists) return null;

    return UserProfile.fromMap(doc.data()!);
  }

  // Update language preferences
  Future<void> updateLanguagePreferences({
    required List<String> targetLanguages,
    required Map<String, String> proficiencyLevels,
    required String nativeLanguage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    await _users.doc(user.uid).update({
      'targetLanguages': targetLanguages,
      'proficiencyLevels': proficiencyLevels,
      'nativeLanguage': nativeLanguage,
    });
  }

  // Add a target language with proficiency level
  Future<void> addTargetLanguage({
    required String languageCode,
    required String proficiencyLevel,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final userDoc = await _users.doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User profile not found');

    final userData = userDoc.data()!;
    final targetLanguages = List<String>.from(userData['targetLanguages'] ?? []);
    final proficiencyLevels = Map<String, String>.from(userData['proficiencyLevels'] ?? {});

    if (!targetLanguages.contains(languageCode)) {
      targetLanguages.add(languageCode);
      proficiencyLevels[languageCode] = proficiencyLevel;

      await _users.doc(user.uid).update({
        'targetLanguages': targetLanguages,
        'proficiencyLevels': proficiencyLevels,
      });
    }
  }

  // Remove a target language
  Future<void> removeTargetLanguage(String languageCode) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final userDoc = await _users.doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User profile not found');

    final userData = userDoc.data()!;
    final targetLanguages = List<String>.from(userData['targetLanguages'] ?? []);
    final proficiencyLevels = Map<String, String>.from(userData['proficiencyLevels'] ?? {});

    targetLanguages.remove(languageCode);
    proficiencyLevels.remove(languageCode);

    await _users.doc(user.uid).update({
      'targetLanguages': targetLanguages,
      'proficiencyLevels': proficiencyLevels,
    });
  }

  // Update last practice date and streak
  Future<void> updatePracticeStatus() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final userDoc = await _users.doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User profile not found');

    final userData = userDoc.data()!;
    final lastPractice = (userData['lastPracticeDate'] as Timestamp).toDate();
    final currentStreak = userData['currentStreak'] as int? ?? 0;

    // Calculate if streak should be incremented or reset
    final now = DateTime.now();
    final difference = now.difference(lastPractice).inDays;
    
    int newStreak = currentStreak;
    if (difference == 1) {
      // Consecutive day, increment streak
      newStreak = currentStreak + 1;
    } else if (difference > 1) {
      // Streak broken, reset to 1
      newStreak = 1;
    }

    await _users.doc(user.uid).update({
      'lastPracticeDate': Timestamp.now(),
      'currentStreak': newStreak,
    });
  }

  // Check if user profile exists
  Future<bool> userProfileExists() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _users.doc(user.uid).get();
    return doc.exists;
  }
} 