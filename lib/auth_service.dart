// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this line for Firestore

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up with email and password
  Future<User?> signUpWithEmailPassword(
      String email, String password, String username) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;


      // Store the username in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'username': username});

      return user;
    } catch (e) {
      print('Sign up failed: $e');
      return null;
    }
  }
  // Log in with email and password
  Future<User?> logInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print('Login failed: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out failed: $e');
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream to listen to authentication changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
