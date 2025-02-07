import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web-specific sign in
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        
        // Add scopes if needed
        authProvider.addScope('email');
        authProvider.addScope('profile');
        
        // Set custom parameters
        authProvider.setCustomParameters({
          'prompt': 'select_account'
        });
        
        return await _auth.signInWithPopup(authProvider);
      } else {
        // Mobile sign in
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Get the current user's provider data
      final providerData = _auth.currentUser?.providerData;
      final isGoogleUser = providerData?.any((element) => 
        element.providerId == GoogleAuthProvider.PROVIDER_ID) ?? false;

      // If user signed in with Google, handle Google sign out
      if (isGoogleUser) {
        if (!kIsWeb) {
          try {
            await _googleSignIn.signOut();
          } catch (e) {
            print('Google Sign In sign out error: $e');
            // Continue with Firebase sign out even if Google sign out fails
          }
        }
      }

      // Always sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
} 