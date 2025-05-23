import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ReceiveNotificationDialog extends StatefulWidget {
  const ReceiveNotificationDialog({super.key});

  @override
  State<ReceiveNotificationDialog> createState() => _ReceiveNotificationDialogState();
}

class _ReceiveNotificationDialogState extends State<ReceiveNotificationDialog> {
  final Map<String, bool> _localReadStatus = {};
  final Map<String, bool> _isUpdating = {};

  Future<void> _markAsRead(String notificationId) async {
    if (_isUpdating[notificationId] == true) return; // Prevent multiple updates

    setState(() {
      _isUpdating[notificationId] = true;
    });

    final userId = FirebaseAuth.instance.currentUser!.uid;
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});

      setState(() {
        _localReadStatus[notificationId] = true;
        _isUpdating[notificationId] = false;
      });
    } catch (e) {
      setState(() {
        _isUpdating[notificationId] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as read: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    try {
      final notifications = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
        setState(() {
          _localReadStatus[doc.id] = true;
        });
      }
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all as read: $e')),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    try {
      final notifications = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('notifications')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      setState(() {
        _localReadStatus.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear notifications: $e')),
        );
      }
    }
  }

  void _showClearConfirmationDialog() {
    showDialog(
      context: context,

      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Clear All Notifications',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E3A8A),
          ),
        ),
        content: Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
          style: GoogleFonts.inter(
            color: const Color(0xFF221E22),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllNotifications();
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Dialog(

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.04),
      ),
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.5,
          maxWidth: mediaQuery.size.width * 0.9,
        ),
        padding: EdgeInsets.all(mediaQuery.size.width * 0.05),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.inter(
                    fontSize: mediaQuery.size.width * 0.05,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF221E22)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: mediaQuery.size.height * 0.01),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Users')
                    .doc(userId)
                    .collection('notifications')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load notifications.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEF4444),
                          fontSize: mediaQuery.size.width * 0.04,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No notifications found.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF221E22).withOpacity(0.6),
                          fontSize: mediaQuery.size.width * 0.04,
                        ),
                      ),
                    );
                  }

                  var notifications = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      var notification = notifications[index];
                      final notificationId = notification.id;
                      final notificationData = notification.data() as Map<String, dynamic>;
                      final title = notificationData['title']?.toString() ?? 'No Title';
                      final message = notificationData['message']?.toString() ?? 'No Message';
                      final timestamp = (notificationData['timestamp'] as Timestamp?)?.toDate();
                      final formattedTime = timestamp != null
                          ? DateFormat('MMM d, yyyy h:mm a').format(timestamp)
                          : 'Unknown Time';
                      final isRead = _localReadStatus[notificationId] ??
                          (notificationData['read'] as bool? ?? false);

                      return GestureDetector(
                        onTap: () {
                          if (!isRead) {
                            _markAsRead(notificationId);
                          }
                        },
                        child: Card(
                          elevation: 2,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                          ),
                          margin: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.005),
                          child: Padding(
                            padding: EdgeInsets.all(mediaQuery.size.width * 0.03),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isRead
                                      ? const Color(0xFF6B7280)
                                      : const Color(0xFF1E3A8A),
                                  radius: mediaQuery.size.width * 0.05,
                                  child: _isUpdating[notificationId] == true
                                      ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                      : Icon(
                                    Icons.notifications,
                                    color: Colors.white,
                                    size: mediaQuery.size.width * 0.05,
                                  ),
                                ),
                                SizedBox(width: mediaQuery.size.width * 0.03),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: GoogleFonts.inter(
                                          fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                          fontSize: mediaQuery.size.width * 0.035,
                                          color: const Color(0xFF221E22),
                                        ),
                                      ),
                                      Text(
                                        message,
                                        style: GoogleFonts.inter(
                                          fontSize: mediaQuery.size.width * 0.03,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                      Text(
                                        formattedTime,
                                        style: GoogleFonts.inter(
                                          fontSize: mediaQuery.size.width * 0.025,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _markAllAsRead,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: mediaQuery.size.width * 0.05,
                      vertical: mediaQuery.size.height * 0.015,
                    ),
                  ),
                  child: Text(
                    'Mark All as Read',
                    style: GoogleFonts.inter(
                      fontSize: mediaQuery.size.width * 0.035,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _showClearConfirmationDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: mediaQuery.size.width * 0.05,
                      vertical: mediaQuery.size.height * 0.015,
                    ),
                  ),
                  child: Text(
                    'Clear All',
                    style: GoogleFonts.inter(
                      fontSize: mediaQuery.size.width * 0.035,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
}