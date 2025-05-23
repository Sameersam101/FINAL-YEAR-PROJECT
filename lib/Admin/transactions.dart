import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxdart/rxdart.dart';
import 'package:photo_view/photo_view.dart';

class TransactionsSection extends StatefulWidget {
  final String userId;

  const TransactionsSection({super.key, required this.userId});

  @override
  _TransactionsSectionState createState() => _TransactionsSectionState();
}

class _TransactionsSectionState extends State<TransactionsSection> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // Default filter

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch supplier name by supplierId
  Future<String> _fetchSupplierName(String supplierId) async {
    try {
      final supplierDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('Suppliers')
          .doc(supplierId)
          .get();
      if (supplierDoc.exists) {
        final data = supplierDoc.data() as Map<String, dynamic>;
        return data['name']?.toString() ?? 'Unknown Supplier';
      }
    } catch (e) {
      print('Error fetching supplier name: $e');
    }
    return 'Unknown Supplier';
  }

  // Fetch all suppliers and return a map of supplierId to name
  Future<Map<String, String>> _fetchSuppliersMap(String userId) async {
    try {
      final suppliersSnap = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('Suppliers')
          .get();
      final suppliersMap = <String, String>{};
      for (var doc in suppliersSnap.docs) {
        final data = doc.data();
        suppliersMap[doc.id] = data['name']?.toString() ?? 'Unknown Supplier';
      }
      return suppliersMap;
    } catch (e) {
      print('Error fetching suppliers: $e');
      return {};
    }
  }

  // Show zoomable image in a popup
  void _showImagePopup(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            PhotoView(
              imageProvider: NetworkImage(imageUrl),
              backgroundDecoration: const BoxDecoration(color: Colors.transparent),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildTransactionTitle(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return 'Unknown Transaction';
    if (type == 'sale') {
      final quantities = data['quantities'] as Map<String, dynamic>? ?? {};
      final items = quantities.entries.map((e) => '${e.key} (${e.value})').join(', ');
      return quantities.isNotEmpty ? items : 'Unknown Product';
    } else if (type == 'expense') {
      final description = data['description'] as String? ?? 'Unknown';
      return description;
    }
    return 'Unknown Transaction';
  }

  Stream<List<Map<String, dynamic>>> _transactionStream(String userId) {
    final transactionsStream = FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots();

    final ordersStream = FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('Orders')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return CombineLatestStream.combine2(
      transactionsStream,
      ordersStream,
          (QuerySnapshot transactions, QuerySnapshot orders) async {
        final suppliersMap = await _fetchSuppliersMap(userId);
        List<Map<String, dynamic>> combined = [];

        for (var doc in transactions.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final searchQuery = _searchController.text.toLowerCase();
          final title = _buildTransactionTitle(data).toLowerCase();
          if (searchQuery.isEmpty || title.contains(searchQuery)) {
            if (_selectedFilter == 'All' ||
                (_selectedFilter == 'Sale' && data['type'] == 'sale') ||
                (_selectedFilter == 'Expense' && data['type'] == 'expense')) {
              final amountRaw = data['amount'];
              final amount = (amountRaw is num
                  ? amountRaw.toDouble()
                  : (amountRaw is String ? double.tryParse(amountRaw) ?? 0.0 : 0.0));
              combined.add({
                ...data,
                'source': 'transaction',
                'amount': amount,
                'date': data['date'] as Timestamp? ?? Timestamp.now(),
                'createdAt': data['createdAt'] as Timestamp? ?? Timestamp.now(),
              });
            }
          }
        }

        for (var doc in orders.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final supplierId = data['supplierId'] as String? ?? '';
          final supplierName = suppliersMap[supplierId] ?? 'Unknown Supplier';
          final searchQuery = _searchController.text.toLowerCase();
          final title =
          '${data['itemName']} (${data['status']}) - $supplierName'.toLowerCase();
          if (searchQuery.isEmpty || title.contains(searchQuery)) {
            if (_selectedFilter == 'All' || _selectedFilter == 'Seller') {
              final amountRaw = data['purchaseAmount'];
              final amount = (amountRaw is num
                  ? amountRaw.toDouble()
                  : (amountRaw is String ? double.tryParse(amountRaw) ?? 0.0 : 0.0));
              combined.add({
                ...data,
                'source': 'seller',
                'amount': amount,
                'date': data['createdAt'] as Timestamp? ?? Timestamp.now(),
                'createdAt': data['createdAt'] as Timestamp? ?? Timestamp.now(),
                'itemName': data['itemName'] as String? ?? 'Unknown Item',
                'status': data['status'] as String? ?? 'Unknown',
                'supplierName': supplierName,
              });
            }
          }
        }

        combined.sort((a, b) {
          final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

        return combined;
      },
    ).asyncMap((combined) => combined);
  }

  Widget _buildFilterButton(String label, bool isSelected) {
    final mediaQuery = MediaQuery.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = label;
          });
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.01),
          padding: EdgeInsets.symmetric(
            horizontal: mediaQuery.size.width * 0.02,
            vertical: mediaQuery.size.height * 0.012,
          ),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF05668D) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF05668D) : const Color(0xFFD1D5DB),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.033,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transactions',
          style: GoogleFonts.inter(
            fontSize: mediaQuery.size.width * 0.045,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF221E22),
          ),
        ),
        SizedBox(height: mediaQuery.size.height * 0.015),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search transactions...',
            hintStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6B7280)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF05668D)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 13),
            filled: true,
            fillColor: Colors.white,
          ),
          style: GoogleFonts.inter(fontSize: 16),
        ),
        SizedBox(height: mediaQuery.size.height * 0.015),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFilterButton('All', _selectedFilter == 'All'),
            _buildFilterButton('Sale', _selectedFilter == 'Sale'),
            _buildFilterButton('Expense', _selectedFilter == 'Expense'),
            _buildFilterButton('Seller', _selectedFilter == 'Seller'),
          ],
        ),
        SizedBox(height: mediaQuery.size.height * 0.015),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _transactionStream(widget.userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF05668D)),
                ),
              );
            }
            if (snapshot.hasError) {
              return Text(
                'Failed to load transactions.',
                style: GoogleFonts.inter(
                  color: const Color(0xFFD62828),
                  fontSize: mediaQuery.size.width * 0.04,
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Text(
                'No transactions found.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF221E22).withOpacity(0.6),
                  fontSize: mediaQuery.size.width * 0.04,
                ),
              );
            }

            final transactionsByDate = <String, List<Map<String, dynamic>>>{};
            for (final txn in snapshot.data!) {
              final date = (txn['date'] as Timestamp?)?.toDate() ?? DateTime.now();
              final dateStr = DateFormat('MMM d - yyyy').format(date).toUpperCase();
              transactionsByDate.putIfAbsent(dateStr, () => []).add(txn);
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactionsByDate.length,
              itemBuilder: (context, index) {
                final dateEntry = transactionsByDate.entries.elementAt(index);
                final date = dateEntry.key;
                final transactions = dateEntry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: mediaQuery.size.height * 0.015),
                      child: Text(
                        date,
                        style: GoogleFonts.inter(
                          fontSize: mediaQuery.size.width * 0.035,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    ...transactions.map((txn) {
                      final isSeller = txn['source'] == 'seller';
                      final isIncome = !isSeller ? (txn['type'] == 'sale') : false;
                      final amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;
                      final title = isSeller
                          ? '${txn['itemName']} (${txn['status']}) - ${txn['supplierName']}'
                          : _buildTransactionTitle(txn);
                      final createdAt =
                          (txn['createdAt'] as Timestamp?)?.toDate() ??
                              DateTime.now();
                      final timeStr = DateFormat('dd MMM, HH:mm').format(createdAt);
                      final imageUrl = txn['imageUrl'] as String? ?? '';

                      return AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 500),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(mediaQuery.size.width * 0.04),
                            side: BorderSide(
                                color: const Color(0xFF221E22).withOpacity(0.2),
                                width: 0.5),
                          ),
                          margin: EdgeInsets.only(
                              bottom: mediaQuery.size.height * 0.015),
                          color: const Color(0xFFFFFFFF),
                          child: ListTile(
                            title: Text(
                              title,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                fontSize: mediaQuery.size.width * 0.04,
                                color: const Color(0xFF221E22),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isIncome ? 'Cash In' : 'Cash Out',
                                  style: GoogleFonts.inter(
                                    fontSize: mediaQuery.size.width * 0.035,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      timeStr,
                                      style: GoogleFonts.inter(
                                        fontSize: mediaQuery.size.width * 0.035,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                    if (imageUrl.isNotEmpty) ...[
                                      SizedBox(width: mediaQuery.size.width * 0.02),
                                      GestureDetector(
                                        onTap: () => _showImagePopup(imageUrl),
                                        child: Text(
                                          'See Image',
                                          style: GoogleFonts.inter(
                                            fontSize: mediaQuery.size.width * 0.035,
                                            color: const Color(0xFF05668D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: Text(
                              (isIncome ? '+\रु ' : '-\रु ') +
                                  amount.toStringAsFixed(2),
                              style: GoogleFonts.inter(
                                fontSize: mediaQuery.size.width * 0.035,
                                fontWeight: FontWeight.bold,
                                color: isIncome
                                    ? const Color(0xFF05668D)
                                    : const Color(0xFFD62828),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}