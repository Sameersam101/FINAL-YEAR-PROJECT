import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class InventorySection extends StatelessWidget {
  final String userId;

  const InventorySection({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inventory',
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
              .collection('Inventory')
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
                'Failed to load inventory.',
                style: GoogleFonts.inter(
                  color: const Color(0xFFD62828), // Vivid Red
                  fontSize: mediaQuery.size.width * 0.04,
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Text(
                'No inventory found.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF221E22).withOpacity(0.6), // Dark Gray
                  fontSize: mediaQuery.size.width * 0.04,
                ),
              );
            }

            var inventory = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: inventory.length,
              itemBuilder: (context, index) {
                var doc = inventory[index];
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
                        data?['productName'] as String? ?? 'Unknown Item',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: mediaQuery.size.width * 0.04,
                          color: const Color(0xFF221E22), // Dark Gray
                        ),
                      ),
                      subtitle: Text(
                        'Quantity: ${data?['quantity']?.toString() ?? '0'}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF221E22).withOpacity(0.6), // Dark Gray
                          fontSize: mediaQuery.size.width * 0.035,
                        ),
                      ),
                      leading: const Icon(
                        Icons.inventory,
                        color: Color(0xFF05668D), // Deep Teal
                        size: 24,
                      ),
                      trailing: Text(
                        'रु ${data != null && data.containsKey('price') && data['price'] != null ? (data['price'] as num).toStringAsFixed(2) : '0.00'}',
                        style: GoogleFonts.inter(
                          fontSize: mediaQuery.size.width * 0.035,
                          color: const Color(0xFF05668D), // Deep Teal
                        ),
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