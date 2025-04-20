import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class SuppliersSection extends StatelessWidget {
  final String userId;
  final VoidCallback onAddSupplier;

  const SuppliersSection({super.key, required this.userId, required this.onAddSupplier});

  static void showAddSupplierDialog(BuildContext context, String userId, VoidCallback onAddSupplier) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController mobileController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    final mediaQuery = MediaQuery.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.04)),
          backgroundColor: Colors.white,
          title: Text(
          'Add Supplier',
          style: GoogleFonts.inter(
            fontSize: mediaQuery.size.width * 0.045,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF221E22),
          ),
        ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: GoogleFonts.inter(color: const Color(0xFF221E22).withOpacity(0.6)), // Dark Gray
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                      borderSide: const BorderSide(color: Color(0xFF05668D)), // Deep Teal
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04, color: const Color(0xFF221E22)), // Dark Gray
                ),
                SizedBox(height: mediaQuery.size.height * 0.015),
                TextField(
                  controller: mobileController,
                  decoration: InputDecoration(
                    labelText: 'Mobile',
                    labelStyle: GoogleFonts.inter(color: const Color(0xFF221E22).withOpacity(0.6)), // Dark Gray
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                      borderSide: const BorderSide(color: Color(0xFF05668D)), // Deep Teal
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04, color: const Color(0xFF221E22)), // Dark Gray
                ),
                SizedBox(height: mediaQuery.size.height * 0.015),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: GoogleFonts.inter(color: const Color(0xFF221E22).withOpacity(0.6)), // Dark Gray
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                      borderSide: const BorderSide(color: Color(0xFF05668D)), // Deep Teal
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04, color: const Color(0xFF221E22)), // Dark Gray
                ),
                SizedBox(height: mediaQuery.size.height * 0.015),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    labelStyle: GoogleFonts.inter(color: const Color(0xFF221E22).withOpacity(0.6)), // Dark Gray
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.02),
                      borderSide: const BorderSide(color: Color(0xFF05668D)), // Deep Teal
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04, color: const Color(0xFF221E22)), // Dark Gray
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xFFD62828), // Vivid Red
                  fontSize: mediaQuery.size.width * 0.04,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || mobileController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Name and Mobile are required',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFFD62828), // Vivid Red
                    ),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('Users')
                      .doc(userId)
                      .collection('Suppliers')
                      .add({
                    'name': nameController.text,
                    'mobile': mobileController.text,
                    'email': emailController.text,
                    'address': addressController.text,
                    'createdAt': Timestamp.now(),
                  });
                  Navigator.of(context).pop();
                  onAddSupplier();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Supplier added successfully',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFF05668D), // Deep Teal
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to add supplier: $e',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFFD62828), // Vivid Red
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF05668D), // Deep Teal
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.03),
                ),
              ),
              child: Text(
                'Add',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: mediaQuery.size.width * 0.04,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteSupplier(BuildContext context, String supplierId) {
    final mediaQuery = MediaQuery.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.04)),
          backgroundColor: const Color(0xFFFFEFD3), // Light Peach
          content: Text(
            'Are you sure you want to delete this supplier?',
            style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04, color: const Color(0xFF221E22)), // Dark Gray
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xFFD62828), // Vivid Red
                  fontSize: mediaQuery.size.width * 0.04,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('Users')
                      .doc(userId)
                      .collection('Suppliers')
                      .doc(supplierId)
                      .delete();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Supplier deleted successfully',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFF05668D), // Deep Teal
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to delete supplier: $e',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFFD62828), // Vivid Red
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62828), // Vivid Red
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.03),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: mediaQuery.size.width * 0.04,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suppliers',
          style: GoogleFonts.inter(
            fontSize: mediaQuery.size.width * 0.045,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF221E22), // Dark Gray
          ),
        ),
        SizedBox(height: mediaQuery.size.height * 0.015),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(userId)
              .collection('Suppliers')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF05668D)), // Deep Teal
                ),
              );
            }
            if (snapshot.hasError) {
              return Text(
                'Failed to load suppliers.',
                style: GoogleFonts.inter(
                  color: const Color(0xFFD62828), // Vivid Red
                  fontSize: mediaQuery.size.width * 0.04,
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Text(
                'No suppliers found.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF221E22).withOpacity(0.6), // Dark Gray
                  fontSize: mediaQuery.size.width * 0.04,
                ),
              );
            }

            var suppliers = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: suppliers.length,
              itemBuilder: (context, index) {
                var doc = suppliers[index];
                final data = doc.data() as Map<String, dynamic>?;
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.04),
                      side: BorderSide(color: const Color(0xFF221E22).withOpacity(0.2), width: 0.5), // Dark Gray
                    ),
                    margin: EdgeInsets.only(bottom: mediaQuery.size.height * 0.015),
                    color: const Color(0xFFFFFFFF), // Light Peach
                    child: ListTile(
                      title: Text(
                        data?['name'] as String? ?? 'Unknown Supplier',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: mediaQuery.size.width * 0.04,
                          color: const Color(0xFF221E22), // Dark Gray
                        ),
                      ),
                      subtitle: Text(
                        'Mobile: ${data?['mobile'] as String? ?? 'No mobile'}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF221E22).withOpacity(0.6), // Dark Gray
                          fontSize: mediaQuery.size.width * 0.035,
                        ),
                      ),
                      leading: const Icon(
                        Icons.person,
                        color: Color(0xFF05668D), // Deep Teal
                        size: 24,
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Color(0xFFD62828), // Vivid Red
                          size: 24,
                        ),
                        onPressed: () => _deleteSupplier(context, doc.id),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}