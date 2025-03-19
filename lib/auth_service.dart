import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Check if email already exists
  Future<bool> checkEmailExists(String email) async {
    try {
      final result = await _auth.fetchSignInMethodsForEmail(email);
      return result.isNotEmpty;
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }

  // Sign up with email and password
  Future<User?> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String mobile,
    required String businessName,
  }) async {
    try {
      // Check if email already exists
      bool emailExists = await checkEmailExists(email);
      if (emailExists) {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The email address is already in use by another account.',
        );
      }

      // Create user with email and password
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save additional user data to Firestore
      await FirebaseFirestore.instance.collection('Users').doc(result.user!.uid).set({
        'Name': name,
        'Email': email,
        'Mobile': mobile,
        'BusinessName': businessName,
        'UserID': result.user!.uid,
        'CreatedAt': FieldValue.serverTimestamp(),
      });

      // Sign out the user after signup so they need to log in
      await _auth.signOut();
      return result.user;
    } catch (e) {
      print('Error during sign up: $e');
      rethrow; // Throw the error to be caught in the UI
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print('Error during sign in: $e');
      return null;
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);

      // Check if user exists in Firestore, if not, create a new document
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(result.user!.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection('Users').doc(result.user!.uid).set({
          'Name': result.user!.displayName ?? '',
          'Email': result.user!.email ?? '',
          'Mobile': '',
          'BusinessName': '',
          'UserID': result.user!.uid,
          'CreatedAt': FieldValue.serverTimestamp(),
        });
      }

      return result.user;
    } catch (e) {
      print('Error during Google sign in: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}