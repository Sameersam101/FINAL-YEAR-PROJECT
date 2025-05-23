import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '/auth_service.dart';
import '/notifications.dart';
import 'login_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late firebase_auth.User? user;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isPhotoTapped = false;

  @override
  void initState() {
    super.initState();
    user = firebase_auth.FirebaseAuth.instance.currentUser;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user!.uid)
          .get();
      if (doc.exists) {
        setState(() {
          userData = doc.data() as Map<String, dynamic>? ?? {};
          isLoading = false;
        });
      } else {
        setState(() {
          userData = {};
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        userData = {};
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching profile data: $e')),
      );
    }
  }

  Future<void> _promptForNotificationPermissions() async {
    final notificationsServices = Provider.of<NotificationsServices>(context, listen: false);
    final areEnabled = await notificationsServices.areNotificationsEnabled();
    if (!areEnabled) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable Notifications'),
          content: const Text(
            'Low stock alerts require notification permissions. Would you like to enable them now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable', style: TextStyle(color: Color(0xFF1E3A8A))),
            ),
          ],
        ),
      );

      if (shouldRequest == true) {
        await notificationsServices.requestNotificationPermission();
      }
    }
  }

  Future<void> _uploadPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    try {
      final file = File(pickedFile.path);
      final username = userData?['Name'] ?? 'user_${user!.uid}';
      final filePath = 'profiles/$username.jpg';
      final supabase = Supabase.instance.client;

      await supabase.storage.from('profiles').upload(filePath, file);
      final photoURL = supabase.storage.from('profiles').getPublicUrl(filePath);

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user!.uid)
          .update({'photoURL': photoURL});

      setState(() {
        userData?['photoURL'] = photoURL;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading photo: $e')),
      );
    }
  }

  Future<void> _updateUserPreference(String field, bool value) async {
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user!.uid)
            .update({field: value});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating preference: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              height: mediaQuery.size.height * 0.30,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E3A8A), Color(0xFFFFFFFF)],
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: mediaQuery.size.width * 0.05,
                    vertical: mediaQuery.size.height * 0.02,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildIconButton(
                        icon: Icons.arrow_back_ios_new,
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Profile',
                        style: GoogleFonts.inter(
                          fontSize: mediaQuery.size.width * 0.055,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      _buildIconButton(
                        icon: Icons.logout,
                        onPressed: () async {
                          await authService.signOut();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => LoginPage()),
                                (Route<dynamic> route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.02),
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () {
                      if (userData?['photoURL'] != null) {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                InteractiveViewer(
                                  child: Image.network(
                                    userData!['photoURL'],
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(8.0),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black54,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isPhotoTapped ? const Color(0xFF1E3A8A) : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundImage: userData?['photoURL'] != null
                                ? NetworkImage(userData!['photoURL'])
                                : const AssetImage('lib/Assets/profile.png') as ImageProvider,
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          transform: Matrix4.identity()..scale(isPhotoTapped ? 0.9 : 1.0),
                          child: GestureDetector(
                            onTap: _uploadPhoto,
                            child: Container(
                              padding: EdgeInsets.all(mediaQuery.size.width * 0.015),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Icon(
                                Icons.add,
                                color: Colors.white,
                                size: mediaQuery.size.width * 0.04,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(mediaQuery.size.width * 0.08),
                        topRight: Radius.circular(mediaQuery.size.width * 0.08),
                      ),
                    ),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(mediaQuery.size.width * 0.05),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User Info',
                              style: GoogleFonts.inter(
                                fontSize: mediaQuery.size.width * 0.05,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF221E22),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Card(
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(mediaQuery.size.width * 0.01),
                                child: Column(
                                  children: [
                                    buildProfileItem(
                                      icon: Icons.person,
                                      title: 'NAME',
                                      value: userData?['Name'] ?? 'N/A',
                                    ),
                                    buildProfileItem(
                                      icon: Icons.email,
                                      title: 'EMAIL',
                                      value: userData?['Email'] ?? user?.email ?? 'N/A',
                                    ),
                                    buildProfileItem(
                                      icon: Icons.phone,
                                      title: 'MOBILE',
                                      value: userData?['Mobile'] ?? 'N/A',
                                    ),
                                    buildProfileItem(
                                      icon: Icons.business,
                                      title: 'BUSINESS',
                                      value: userData?['BusinessName'] ?? 'N/A',
                                    ),
                                    buildProfileItem(
                                      icon: Icons.location_on,
                                      title: 'ADDRESS',
                                      value: userData?['Address'] ?? 'N/A',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Notifications',
                              style: GoogleFonts.inter(
                                fontSize: mediaQuery.size.width * 0.05,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF221E22),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.all(mediaQuery.size.width * 0),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFFFF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  SwitchListTile(
                                    secondary: const Icon(
                                      Icons.notifications,
                                      color: Color(0xFF6B7280),
                                    ),
                                    title: Text(
                                      'Low Stock Alerts',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF221E22),
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Notify when items fall below threshold',
                                      style: GoogleFonts.inter(
                                        fontSize: mediaQuery.size.width * 0.030,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                    value: userData?['lowStockAlerts'] ?? false,
                                    onChanged: (val) async {
                                      if (val) {
                                        await _promptForNotificationPermissions();
                                        final notificationsServices = Provider.of<NotificationsServices>(context, listen: false);
                                        final areEnabled = await notificationsServices.areNotificationsEnabled();
                                        if (!areEnabled) return;
                                      }
                                      setState(() {
                                        userData?['lowStockAlerts'] = val;
                                      });
                                      await _updateUserPreference('lowStockAlerts', val);
                                    },
                                    activeColor: const Color(0xFF1E3A8A),
                                  ),
                                  SwitchListTile(
                                    secondary: const Icon(
                                      Icons.payment,
                                      color: Color(0xFF6B7280),
                                    ),
                                    title: Text(
                                      'Due Payment Alerts',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF221E22),
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Notify when payments are due',
                                      style: GoogleFonts.inter(
                                        fontSize: mediaQuery.size.width * 0.030,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                    value: userData?['duePaymentAlerts'] ?? false,
                                    onChanged: (val) {
                                      setState(() {
                                        userData?['duePaymentAlerts'] = val;
                                      });
                                      _updateUserPreference('duePaymentAlerts', val);
                                    },
                                    activeColor: const Color(0xFF1E3A8A),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed}) {
    final mediaQuery = MediaQuery.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(mediaQuery.size.width * 0.02),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: mediaQuery.size.width * 0.06,
        ),
      ),
    );
  }

  Widget buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.01),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B7280), size: mediaQuery.size.width * 0.05),
          SizedBox(width: mediaQuery.size.width * 0.03),
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.035,
                color: const Color(0xFF6B7280),
                textStyle: const TextStyle(fontFeatures: [FontFeature.enable('smcp')]),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.04,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF221E22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}