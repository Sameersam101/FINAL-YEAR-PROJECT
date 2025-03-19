import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'dashboard.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    print('step 2 done');

    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {

    await Future.delayed(Duration(seconds: 2)); // Optional delay for splash effect

    User? user = FirebaseAuth.instance.currentUser;
    print('step 3 done');


    if (user != null) {
      // User is logged in, redirect to Dashboard
      print(' yes user');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardPage()),
      );
    } else {
      // User is not logged in, check if they are registered in Firestore
      // This assumes you store user data in Firestore upon signup
      print('no user');
      String? uid = await _checkIfUserExistsInFirestore();
      if (uid != null) {
        // User exists in Firestore but is logged out, redirect to Login
        print('step 4 done');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      } else {
        print('step 5 done');

        // User doesn't exist in Firestore, treat as new user, redirect to Signup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SignupPage()),
        );
      }
    }
  }

  // Helper method to check if a user exists in Firestore
  Future<String?> _checkIfUserExistsInFirestore() async {
    // Assuming you store user data with their email or UID
    // Here, we'll check if any user exists with a matching email from previous sessions
    // This is a simple check; adjust based on your Firestore structure
    try {
      // For this to work, you'd need to store emails or UIDs somewhere
      // Since we don't have a specific email to check without login, we'll assume a generic check
      final querySnapshot = await FirebaseFirestore.instance
          .collection('User')
          .limit(1) // Just check if any user exists (simplified)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // If there’s at least one user, assume registered users exist
        return querySnapshot.docs.first.id; // Return a UID as an example
      }
      return null; // No users found, treat as new
    } catch (e) {
      print('Error checking Firestore: $e');
      return null; // Default to Signup on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'lib/Assets/Group84.png',
              height: 120,
            ),
            SizedBox(height: 20),
            Text(
              'ARTHIK SATHI',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.black),
          ],
        ),
      ),
    );
  }
}