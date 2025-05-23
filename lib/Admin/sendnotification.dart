import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SendNotification extends StatefulWidget {
  const SendNotification({super.key});

  @override
  State<SendNotification> createState() => _SendNotificationState();
}

class _SendNotificationState extends State<SendNotification> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String? _selectedUserId;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('Users').get();
      setState(() {
        _users = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['Name']?.toString() ?? 'Unknown',
            'phone': data['Mobile']?.toString() ?? 'N/A',
          };
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching users: $e')),
        );
      }
    }
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both title and message')),
      );
      return;
    }

    try {
      final timestamp = FieldValue.serverTimestamp();
      final notificationData = {
        'title': title.isNotEmpty ? title : 'Notification',
        'message': message,
        'timestamp': timestamp,
        'read': false,
      };

      if (_selectedUserId == 'all') {
        for (var user in _users) {
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(user['id'])
              .collection('notifications')
              .add(notificationData);
        }
      } else {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(_selectedUserId)
            .collection('notifications')
            .add(notificationData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send notification: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.5,
        maxWidth: mediaQuery.size.width * 0.9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.04),
      ),
      padding: EdgeInsets.all(mediaQuery.size.width * 0.05),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Send Notification',
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
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: GoogleFonts.inter(
                  color: const Color(0xFF6B7280),
                  fontSize: mediaQuery.size.width * 0.04,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                  borderSide: const BorderSide(color: Color(0xFF6B7280)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                  borderSide: const BorderSide(color: Color(0xFF6B7280)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                  borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: mediaQuery.size.height * 0.015,
                  horizontal: mediaQuery.size.width * 0.03,
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.035,
                color: const Color(0xFF221E22),
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.015),
            TextField(
              controller: _messageController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Message',
                labelStyle: GoogleFonts.inter(
                  color: const Color(0xFF6B7280),
                  fontSize: mediaQuery.size.width * 0.04,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                  borderSide: const BorderSide(color: Color(0xFF6B7280)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                  borderSide: const BorderSide(color: Color(0xFF6B7280)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                  borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: mediaQuery.size.height * 0.015,
                  horizontal: mediaQuery.size.width * 0.03,
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.035,
                color: const Color(0xFF221E22),
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.015),
            DropdownButtonFormField<String>(
              value: _selectedUserId,
              decoration: InputDecoration(
                labelText: 'Select Recipient',
                labelStyle: GoogleFonts.inter(
                  color: const Color(0xFF6B7280),
                  fontSize: mediaQuery.size.width * 0.04,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                  borderSide: const BorderSide(color: Color(0xFF6B7280)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                  borderSide: const BorderSide(color: Color(0xFF6B7280)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                  borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: mediaQuery.size.height * 0.015,
                  horizontal: mediaQuery.size.width * 0.03,
                ),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: 'all',
                  child: Text(
                    'All Users',
                    style: GoogleFonts.inter(
                      fontSize: mediaQuery.size.width * 0.035,
                      color: const Color(0xFF221E22),
                    ),
                  ),
                ),
                ..._users.map((user) {
                  return DropdownMenuItem<String>(
                    value: user['id'],
                    child: Text(
                      '${user['name']} (${user['phone']})',
                      style: GoogleFonts.inter(
                        fontSize: mediaQuery.size.width * 0.035,
                        color: const Color(0xFF221E22),
                      ),
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedUserId = value;
                });
              },
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _sendNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: mediaQuery.size.width * 0.04,
                    vertical: mediaQuery.size.height * 0.015,
                  ),
                ),
                child: Text(
                  'Send',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: mediaQuery.size.width * 0.035,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}