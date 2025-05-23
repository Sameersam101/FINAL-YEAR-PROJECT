import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'content.dart';
import 'package:arthikapp/Screens/splash_screen.dart';
import 'sendnotification.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  Stream<int> _getTotalUsers() {
    return FirebaseFirestore.instance
        .collection('Users')
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((e) {
      debugPrint('Error in _getTotalUsers: $e');
      throw e;
    });
  }

  Stream<double> _getTotalIncome() {
    return FirebaseFirestore.instance
        .collection('Users')
        .snapshots()
        .asyncMap((userSnapshot) async {
      double totalIncome = 0.0;
      for (var userDoc in userSnapshot.docs) {
        final userId = userDoc.id;
        final transactionsSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .doc(userId)
            .collection('transactions')
            .where('type', isEqualTo: 'sale')
            .get();
        for (var doc in transactionsSnapshot.docs) {
          final data = doc.data();
          final amount = data['amount'] as num? ?? 0;
          totalIncome += amount.toDouble();
        }
      }
      return totalIncome;
    }).handleError((e) {
      debugPrint('Error in _getTotalIncome: $e');
      throw e;
    });
  }

  Future<void> _logout(BuildContext context) async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF05668D),
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.inter(
            color: const Color(0xFF221E22),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xFF05668D),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Yes',
              style: GoogleFonts.inter(
                color: const Color(0xFFEE5622), // Vivid Orange for emphasis
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => SplashScreen()),
              (route) => false,
        );
      } catch (e) {
        debugPrint('Failed to log out: $e');
      }
    }
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return;
    }
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      debugPrint('Could not launch $phoneUri');
    }
  }

  Future<void> _deleteUser(BuildContext context, String userId, String userName) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Delete',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF05668D),
          ),
        ),
        content: Text(
          'Are you sure you want to delete $userName?',
          style: GoogleFonts.inter(
            color: const Color(0xFF221E22),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xFF05668D),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Yes',
              style: GoogleFonts.inter(
                color: const Color(0xFFEE5622), // Vivid Orange for emphasis
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('Users').doc(userId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User $userName deleted successfully',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF0DAB76), // Vibrant Green for success
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete user: $e',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEE5622), // Vivid Orange for error
          ),
        );
      }
    }
  }

  void _showNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: SendNotification(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final cardHeight = mediaQuery.size.height * 0.12;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF05668D), Color(0xFF221E22)], // Dark Purple to Vibrant Green
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: mediaQuery.size.width * 0.05,
                  vertical: mediaQuery.size.height * 0.02,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Admin Dashboard',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: mediaQuery.size.width * 0.06,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showNotifications(context),
                          child: Container(
                            padding: EdgeInsets.all(mediaQuery.size.width * 0.02),
                            decoration: BoxDecoration(
                              color: const Color(0xFF05668D).withOpacity(0.2), // Dark Gray
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        SizedBox(width: mediaQuery.size.width * 0.02),
                        GestureDetector(
                          onTap: () => _logout(context),
                          child: Container(
                            padding: EdgeInsets.all(mediaQuery.size.width * 0.02),
                            decoration: BoxDecoration(
                              color: const Color(0xFF05668D).withOpacity(0.2), // Dark Gray
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.logout,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(mediaQuery.size.width * 0.08),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: mediaQuery.size.width * 0.05,
                      vertical: mediaQuery.size.height * 0.02,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AnimatedOpacity(
                                opacity: 1.0,
                                duration: const Duration(milliseconds: 500),
                                child: _buildSummaryCard(
                                  context,
                                  title: 'Total Users',
                                  stream: _getTotalUsers(),
                                  icon: Icons.people,
                                  color: const Color(0xFFECA72C), // Warm Yellow
                                  height: cardHeight,
                                ),
                              ),
                            ),
                            SizedBox(width: mediaQuery.size.width * 0.04),
                            Expanded(
                              child: AnimatedOpacity(
                                opacity: 1.0,
                                duration: const Duration(milliseconds: 500),
                                child: _buildSummaryCard(
                                  context,
                                  title: 'Total Income',
                                  stream: _getTotalIncome(),
                                  icon: Icons.account_balance_wallet,
                                  color: const Color(0xFF0DAB76), // Vibrant Green
                                  isCurrency: true,
                                  height: cardHeight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: mediaQuery.size.height * 0.03),
                        Text(
                          'Users',
                          style: GoogleFonts.inter(
                            fontSize: mediaQuery.size.width * 0.05,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF221E22), // Dark Gray
                          ),
                        ),
                        SizedBox(height: mediaQuery.size.height * 0.02),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('Users')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF0DAB76)), // Vibrant Green
                                  ),
                                );
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Failed to load users.',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFEE5622), // Vivid Orange
                                      fontSize: mediaQuery.size.width * 0.04,
                                    ),
                                  ),
                                );
                              }
                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No users found.',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF221E22).withOpacity(0.6), // Dark Gray
                                      fontSize: mediaQuery.size.width * 0.04,
                                    ),
                                  ),
                                );
                              }

                              var users = snapshot.data!.docs;

                              return ListView.builder(
                                itemCount: users.length,
                                itemBuilder: (context, index) {
                                  var user = users[index];
                                  final userData =
                                  user.data() as Map<String, dynamic>?;
                                  final email = userData?['Email']
                                      ?.toString()
                                      .toLowerCase() ??
                                      '';
                                  if (email.contains('@admin')) {
                                    return const SizedBox.shrink();
                                  }

                                  final mobile = userData != null &&
                                      userData.containsKey('Mobile')
                                      ? userData['Mobile'] as String? ?? ''
                                      : '';
                                  final userName = userData != null &&
                                      userData.containsKey('Name')
                                      ? userData['Name'] as String? ?? 'Unknown'
                                      : 'Unknown';

                                  return AnimatedOpacity(
                                    opacity: 1.0,
                                    duration: const Duration(milliseconds: 500),
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            mediaQuery.size.width * 0.04),
                                        side: const BorderSide(
                                            color: Color(0xFF221E22), width: 0.5), // Dark Gray
                                      ),
                                      color: const Color(0xFFFFFFFF),
                                      margin: EdgeInsets.only(
                                          bottom: mediaQuery.size.height * 0.010),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: mediaQuery.size.width * 0.04,
                                          vertical: mediaQuery.size.height * 0.01,
                                        ),
                                        leading: CircleAvatar(
                                          backgroundColor:
                                          const Color(0xFF05668D),
                                          radius: mediaQuery.size.width * 0.06,
                                          child: Text(
                                            userData != null &&
                                                userData.containsKey('Name') &&
                                                userData['Name'] != null
                                                ? userData['Name'][0]
                                                .toString()
                                                .toUpperCase()
                                                : 'U',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: mediaQuery.size.width * 0.04,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          userName,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontSize: mediaQuery.size.width * 0.04,
                                            color: const Color(0xFF05668D), // Dark Gray
                                          ),
                                        ),
                                        subtitle: Text(
                                          mobile.isNotEmpty
                                              ? mobile
                                              : 'No mobile',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF05668D)
                                                .withOpacity(0.6), // Dark Gray
                                            fontSize: mediaQuery.size.width * 0.035,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.phone,
                                                color: mobile.isNotEmpty
                                                    ? const Color(
                                                    0xFF221E22) // Vibrant Green
                                                    : const Color(0xFFD62828)
                                                    .withOpacity(0.4),
                                                size: mediaQuery.size.width * 0.05,
                                              ),
                                              onPressed: mobile.isNotEmpty
                                                  ? () => _makePhoneCall(mobile)
                                                  : null,
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Color(0xFFEE5622), // Vivid Orange
                                                size: 20,
                                              ),
                                              onPressed: () => _deleteUser(context, user.id, userName),
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  AdminUserDetailsPage(
                                                      userId: user.id),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, {
        required String title,
        required Stream<dynamic> stream,
        required IconData icon,
        required Color color,
        bool isCurrency = false,
        required double height,
      }) {
    final formatter = NumberFormat('#,##0.00');
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.04),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF05668D).withOpacity(0.1), // Dark Gray
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(mediaQuery.size.width * 0.03),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: mediaQuery.size.width * 0.05,
              child: Icon(
                icon,
                color: color,
                size: mediaQuery.size.width * 0.05,
              ),
            ),
            SizedBox(width: mediaQuery.size.width * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: mediaQuery.size.width * 0.032,
                      color: const Color(0xFF05668D).withOpacity(0.7), // Dark Gray
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: mediaQuery.size.height * 0.005),
                  StreamBuilder<dynamic>(
                    stream: stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SizedBox(
                          height: mediaQuery.size.width * 0.04,
                          width: mediaQuery.size.width * 0.04,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF0DAB76)), // Vibrant Green
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Text(
                          'Error',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEE5622), // Vivid Orange
                            fontSize: mediaQuery.size.width * 0.035,
                          ),
                        );
                      }

                      String value = snapshot.hasData
                          ? isCurrency
                          ? '₹${formatter.format(snapshot.data)}'
                          : snapshot.data.toString()
                          : '0';

                      return Text(
                        value,
                        style: GoogleFonts.inter(
                          fontSize: mediaQuery.size.width * 0.025,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF05668D), // Dark Gray
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}