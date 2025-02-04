import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveUserPreferences({
    required String targetLanguage,
    required String proficiencyLevel,
    required String nativeLanguage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    await _firestore.collection('users').doc(user.uid).set({
      'targetLanguage': targetLanguage,
      'proficiencyLevel': proficiencyLevel,
      'nativeLanguage': nativeLanguage,
      'onboardingComplete': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserPreferences() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  Future<void> updateUserPreferences({
    String? targetLanguage,
    String? proficiencyLevel,
    String? nativeLanguage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (targetLanguage != null) updates['targetLanguage'] = targetLanguage;
    if (proficiencyLevel != null) updates['proficiencyLevel'] = proficiencyLevel;
    if (nativeLanguage != null) updates['nativeLanguage'] = nativeLanguage;

    await _firestore.collection('users').doc(user.uid).update(updates);
  }
} 