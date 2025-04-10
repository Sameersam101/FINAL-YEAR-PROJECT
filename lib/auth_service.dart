// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:google_sign_in/google_sign_in.dart';
//
// class AuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final GoogleSignIn _googleSignIn = GoogleSignIn();
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   Future<bool> checkEmailExists(String email) async {
//     try {
//       final result = await _auth.fetchSignInMethodsForEmail(email);
//       return result.isNotEmpty;
//     } catch (e) {
//       print('Error checking email: $e');
//       return false;
//     }
//   }
//
//   Future<User?> signUpWithEmailPassword({
//     required String email,
//     required String password,
//     required String name,
//     required String mobile,
//     required String businessName,
//     required String address,
//   }) async {
//     try {
//       bool emailExists = await checkEmailExists(email);
//       if (emailExists) {
//         throw FirebaseAuthException(
//           code: 'email-already-in-use',
//           message: 'The email address is already in use by another account.',
//         );
//       }
//
//       UserCredential result = await _auth.createUserWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//
//       await _firestore.collection('Users').doc(result.user!.uid).set({
//         'Name': name,
//         'Email': email,
//         'Mobile': mobile,
//         'BusinessName': businessName,
//         'UserID': result.user!.uid,
//         'Address': address,
//         'CreatedAt': FieldValue.serverTimestamp(),
//       });
//
//       await _auth.signOut();
//       return result.user;
//     } catch (e) {
//       print('Error during sign up: $e');
//       rethrow;
//     }
//   }
//
//   Future<User?> signInWithEmailPassword(String email, String password) async {
//     try {
//       UserCredential result = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       return result.user;
//     } catch (e) {
//       print('Error during sign in: $e');
//       return null;
//     }
//   }
//
//   Future<User?> signInWithGoogle() async {
//     try {
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//       if (googleUser == null) return null;
//
//       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
//
//       final OAuthCredential credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );
//
//       UserCredential result = await _auth.signInWithCredential(credential);
//
//       DocumentSnapshot userDoc = await _firestore
//           .collection('Users')
//           .doc(result.user!.uid)
//           .get();
//
//       if (!userDoc.exists) {
//         await _firestore.collection('Users').doc(result.user!.uid).set({
//           'Name': result.user!.displayName ?? '',
//           'Email': result.user!.email ?? '',
//           'Mobile': '',
//           'BusinessName': '',
//           'UserID': result.user!.uid,
//           'Address': '',
//           'CreatedAt': FieldValue.serverTimestamp(),
//         });
//       }
//
//       return result.user;
//     } catch (e) {
//       print('Error during Google sign in: $e');
//       return null;
//     }
//   }
//
//   Future<void> signOut() async {
//     await _googleSignIn.signOut();
//     await _auth.signOut();
//   }
// }

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'], // Explicitly request email and profile scopes
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> checkEmailExists(String email) async {
    try {
      final result = await _auth.fetchSignInMethodsForEmail(email);
      return result.isNotEmpty;
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }

  Future<User?> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String mobile,
    required String businessName,
    required String address,
  }) async {
    try {
      bool emailExists = await checkEmailExists(email);
      if (emailExists) {
        throw FirebaseAuthException(
          code: '',
          message: 'The email address is already in use by another account.',
        );
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('Users').doc(result.user!.uid).set({
        'Name': name,
        'Email': email,
        'Mobile': mobile,
        'BusinessName': businessName,
        'UserID': result.user!.uid,
        'Address': address,
        'CreatedAt': FieldValue.serverTimestamp(),
      });

      await _auth.signOut();
      return result.user;
    } catch (e) {
      print('Error during sign up: $e');
      rethrow;
    }
  }

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

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google Sign-In was canceled by the user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Google authentication tokens are missing');
        return null;
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      print('Google Sign-In successful for user: ${result.user!.email}');

      DocumentSnapshot userDoc = await _firestore
          .collection('Users')
          .doc(result.user!.uid)
          .get();

      if (!userDoc.exists) {
        print('Creating new user document in Firestore for: ${result.user!.email}');
        await _firestore.collection('Users').doc(result.user!.uid).set({
          'Name': result.user!.displayName ?? '',
          'Email': result.user!.email ?? '',
          'Mobile': '',
          'BusinessName': '',
          'UserID': result.user!.uid,
          'Address': '',
          'CreatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        print('User document already exists for: ${result.user!.email}');
      }

      return result.user;
    } catch (e) {
      print('Error during Google sign in: $e');
      if (e is FirebaseAuthException) {
        print('FirebaseAuthException details: ${e.code} - ${e.message}');
      }
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}