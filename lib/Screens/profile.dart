import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '/auth_service.dart';
import 'login_page.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User? user;
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (user == null) {
      print('No user is currently logged in');
      setState(() => isLoading = false);
      return;
    }

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('Users') // Changed to 'Users' to match AuthService
          .doc(user!.uid)
          .get();
      if (doc.exists) {
        setState(() {
          userData = doc.data() as Map<String, dynamic>? ?? {};
          print('Fetched user data: $userData'); // Debug output
          isLoading = false;
        });
      } else {
        print('No user data found in Firestore for UID: ${user!.uid}');
        setState(() {
          userData = {}; // Initialize as empty map if no data
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        userData = {}; // Fallback to empty map on error
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching profile data: $e')),
      );
    }
  }

  // Refresh data manually if needed
  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    await _fetchUserData();
  }

  @override
  void dispose() {
    // Clean up if needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Color(0xFFFFA726),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Color(0xFFFFA726),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              padding: EdgeInsets.only(top: 20, bottom: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : AssetImage('lib/Assets/profile.png')
                    as ImageProvider, // Fallback to asset
                  ),
                  SizedBox(height: 10),
                  Text(
                    userData?['Name'] ?? user?.displayName ?? 'User Name',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  buildProfileItem('Name', userData?['Name'] ?? 'N/A'),
                  buildProfileItem('Email', userData?['Email'] ?? user?.email ?? 'N/A'),
                  buildProfileItem('Mobile', userData?['Mobile'] ?? 'N/A'),
                  buildProfileItem('Business Name', userData?['BusinessName'] ?? 'N/A'), // Changed to match AuthService
                  buildProfileItem('Password', '*************', isPassword: true),
                  SizedBox(height: 20),
                  SwitchListTile(
                    title: Text('Low Stock Alerts'),
                    value: userData?['lowStockAlerts'] ?? false, // Add to Firestore if needed
                    onChanged: (val) {
                      setState(() {
                        userData?['lowStockAlerts'] = val;
                      });
                      _updateUserPreference('lowStockAlerts', val);
                    },
                  ),
                  SwitchListTile(
                    title: Text('Due Payment Alerts'),
                    value: userData?['duePaymentAlerts'] ?? false, // Add to Firestore if needed
                    onChanged: (val) {
                      setState(() {
                        userData?['duePaymentAlerts'] = val;
                      });
                      _updateUserPreference('duePaymentAlerts', val);
                    },
                  ),
                  SwitchListTile(
                    title: Text('Funds To Receive'),
                    value: userData?['fundsToReceive'] ?? false, // Add to Firestore if needed
                    onChanged: (val) {
                      setState(() {
                        userData?['fundsToReceive'] = val;
                      });
                      _updateUserPreference('fundsToReceive', val);
                    },
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFFA726),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                    ),
                    onPressed: () async {
                      await authService.signOut();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: Text('Log Out', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProfileItem(String title, String value, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.blue),
              ),
              Text(
                isPassword ? '*************' : value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Icon(Icons.edit, color: Colors.grey),
        ],
      ),
    );
  }

  Future<void> _updateUserPreference(String field, bool value) async {
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user!.uid)
            .update({field: value});
        print('Updated $field to $value in Firestore');
      } catch (e) {
        print('Error updating preference: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating preference: $e')),
        );
      }
    }
  }
}