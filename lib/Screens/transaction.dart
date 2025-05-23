import 'package:arthikapp/Screens/Scanpage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:arthikapp/Screens/analyticspage.dart';
import 'package:arthikapp/Screens/dashboard.dart';
import 'package:arthikapp/Screens/inventorypage.dart';
import 'package:arthikapp/Screens/login_page.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxdart/rxdart.dart';
import 'package:photo_view/photo_view.dart';

class Transactionpage extends StatefulWidget {
  const Transactionpage({super.key});

  @override
  _TransactionpageState createState() => _TransactionpageState();
}

class _TransactionpageState extends State<Transactionpage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // Default filter

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch user details (name and business name)
  Future<Map<String, String>> _fetchUserDetails(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return {
          'Name': data['fullName']?.toString() ?? data['displayName']?.toString() ?? data['Name']?.toString() ?? 'Unknown User',
          'BusinessName': data['companyName']?.toString() ?? data['BusinessName']?.toString() ?? 'Unknown Business',
        };
      }
    } catch (e) {
      print('Error fetching user details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching user details: $e')),
      );
    }
    return {'Name': 'Unknown User', 'BusinessName': 'Unknown Business'};
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
      final suppliersSnap = await FirebaseFirestore.instance.collection('Users').doc(userId).collection('Suppliers').get();
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

  // Generate and download PDF
  Future<void> _generateAndDownloadPDF(List<Map<String, dynamic>> transactions) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDetails = await _fetchUserDetails(user.uid);
    final userName = userDetails['Name']!;
    final businessName = userDetails['BusinessName']!;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Text('Transaction Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('User: $userName', style: const pw.TextStyle(fontSize: 18)),
            pw.Text('Business: $businessName', style: const pw.TextStyle(fontSize: 18)),
            pw.Text('Generated On: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 20),
            pw.Text('Transaction Details', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            transactions.isNotEmpty
                ? pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FixedColumnWidth(100),
                1: const pw.FixedColumnWidth(150),
                2: const pw.FixedColumnWidth(80),
                3: const pw.FixedColumnWidth(80),
                4: const pw.FixedColumnWidth(100),
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Title', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Timestamp', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                ...transactions.map((txn) {
                  final isSeller = txn['source'] == 'seller';
                  final isIncome = !isSeller ? (txn['type'] == 'sale') : false;
                  final amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;
                  final title = isSeller ? '${txn['itemName']} (${txn['status']}) - ${txn['supplierName']}' : _buildTransactionTitle(txn);
                  final date = (txn['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final createdAt = (txn['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final dateStr = DateFormat('MMM d - yyyy').format(date);
                  final timeStr = DateFormat('dd MMM, HH:mm').format(createdAt);

                  return pw.TableRow(
                    children: [
                      pw.Text(dateStr),
                      pw.Text(title),
                      pw.Text(isSeller ? 'Seller' : (isIncome ? 'Cash In' : 'Cash Out')),
                      pw.Text((isIncome ? '+\रु ' : '-\रु ') + amount.toStringAsFixed(2),
                          style: pw.TextStyle(color: isIncome ? PdfColors.green : PdfColors.red)),
                      pw.Text(timeStr),
                    ],
                  );
                }),
              ],
            )
                : pw.Text('No transactions available.'),
          ];
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/Transaction_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareFiles([file.path], text: 'Transaction Report for $userName ($businessName)');
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

  // Create a slide transition route
  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final mediaQuery = MediaQuery.of(context);

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
      });
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              height: mediaQuery.size.height * 0.25,
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
                  padding: EdgeInsets.all(mediaQuery.size.width * 0.06),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildIconButton(
                            icon: Icons.arrow_back_rounded,
                            onPressed: () {
                              Navigator.pushReplacement(context, _createRoute(const DashboardPage()));
                            },
                          ),
                          SizedBox(width: mediaQuery.size.width * 0.03),
                          Text(
                            'Transaction',
                            style: GoogleFonts.inter(
                              fontSize: mediaQuery.size.width * 0.06,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      _buildIconButton(
                        icon: Icons.picture_as_pdf,
                        onPressed: () async {
                          final transactions = await _fetchFilteredTransactions(user.uid);
                          if (transactions.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('No transactions to export')),
                            );
                            return;
                          }
                          await _generateAndDownloadPDF(transactions);
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: mediaQuery.size.width * 0.05,
                    vertical: mediaQuery.size.height * 0.02,
                  ),
                  child: TextField(
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
                        borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: GoogleFonts.inter(fontSize: 16),
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
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.005),
                          child: Container(
                            padding: EdgeInsets.all(mediaQuery.size.width * 0.02),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildFilterButton('All', _selectedFilter == 'All'),
                                _buildFilterButton('Sale', _selectedFilter == 'Sale'),
                                _buildFilterButton('Expense', _selectedFilter == 'Expense'),
                                _buildFilterButton('Seller', _selectedFilter == 'Seller'),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _transactionStream(user.uid),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Error: ${snapshot.error}',
                                    style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04, color: const Color(0xFFEF4444)),
                                  ),
                                );
                              }
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No transactions available',
                                    style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04, color: const Color(0xFF6B7280)),
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
                                padding: EdgeInsets.all(mediaQuery.size.width * 0.05),
                                itemCount: transactionsByDate.length,
                                itemBuilder: (context, index) {
                                  final dateEntry = transactionsByDate.entries.elementAt(index);
                                  final date = dateEntry.key;
                                  final transactions = dateEntry.value;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _transactionDateHeader(date),
                                      ...transactions.map((txn) {
                                        final isSeller = txn['source'] == 'seller';
                                        final isIncome = !isSeller ? (txn['type'] == 'sale') : false;
                                        final amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;
                                        final title = isSeller
                                            ? '${txn['itemName']} (${txn['status']}) - ${txn['supplierName']}'
                                            : _buildTransactionTitle(txn);
                                        final createdAt = (txn['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                                        final timeStr = DateFormat('dd MMM, HH:mm').format(createdAt);
                                        final imageUrl = txn['imageUrl'] as String? ?? '';
                                        return _transactionItem(title, amount, isIncome, timeStr, imageUrl);
                                      }),
                                    ],
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
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1E3A8A),
        unselectedItemColor: const Color(0xFF6B7280),
        currentIndex: 3,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(context, _createRoute(const DashboardPage()));
              break;
            case 1:
              Navigator.pushReplacement(context, _createRoute(const InventoryPage()));
              break;
            case 2:
              Navigator.push(context, _createRoute(const ScanPage()));
              break;
            case 3:
              break;
            case 4:
              Navigator.push(context, _createRoute(const Analyticspage()));
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner_rounded), label: 'Scanner'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_rounded), label: 'Transaction'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Analytics'),
        ],
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
            color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFD1D5DB),
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

  Widget _transactionDateHeader(String date) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.015),
      child: Text(
        date,
        style: GoogleFonts.inter(
          fontSize: mediaQuery.size.width * 0.035,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _transactionItem(String title, double amount, bool isIncome, String timestamp, String imageUrl) {
    final mediaQuery = MediaQuery.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: const Color(0xFFFFFFFF),
      margin: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.005),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: mediaQuery.size.height * 0.015,
          horizontal: mediaQuery.size.width * 0.04,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: mediaQuery.size.width * 0.035,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF221E22),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        isIncome ? 'Cash In' : 'Cash Out',
                        style: GoogleFonts.inter(
                          fontSize: mediaQuery.size.width * 0.03,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      if (imageUrl.isNotEmpty) ...[
                        SizedBox(width: mediaQuery.size.width * 0.02), // Add spacing
                        GestureDetector(
                          onTap: () => _showImagePopup(imageUrl),
                          child: Text(
                            'See Image',
                            style: GoogleFonts.inter(
                              fontSize: mediaQuery.size.width * 0.03,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (isIncome ? '+\रु ' : '-\रु ') + amount.toStringAsFixed(2),
                  style: GoogleFonts.inter(
                    fontSize: mediaQuery.size.width * 0.035,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
                Text(
                  timestamp,
                  style: GoogleFonts.inter(
                    fontSize: mediaQuery.size.width * 0.03,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
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

    return CombineLatestStream.combine2(transactionsStream, ordersStream, (
        QuerySnapshot transactions,
        QuerySnapshot orders,
        ) async {
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
            final amount = (amountRaw is num ? amountRaw.toDouble() : (amountRaw is String ? double.tryParse(amountRaw) ?? 0.0 : 0.0));
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
        final title = '${data['itemName']} (${data['status']}) - $supplierName'.toLowerCase();
        if (searchQuery.isEmpty || title.contains(searchQuery)) {
          if (_selectedFilter == 'All' || _selectedFilter == 'Seller') {
            final amountRaw = data['purchaseAmount'];
            final amount = (amountRaw is num ? amountRaw.toDouble() : (amountRaw is String ? double.tryParse(amountRaw) ?? 0.0 : 0.0));
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
    }).asyncMap((combined) => combined);
  }

  Future<List<Map<String, dynamic>>> _fetchFilteredTransactions(String userId) async {
    final transactionsSnap = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .get();

    final ordersSnap = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('Orders')
        .orderBy('createdAt', descending: true)
        .get();

    final suppliersMap = await _fetchSuppliersMap(userId);
    List<Map<String, dynamic>> combined = [];

    for (var doc in transactionsSnap.docs) {
      final data = doc.data();
      final searchQuery = _searchController.text.toLowerCase();
      final title = _buildTransactionTitle(data).toLowerCase();
      if (searchQuery.isEmpty || title.contains(searchQuery)) {
        if (_selectedFilter == 'All' ||
            (_selectedFilter == 'Sale' && data['type'] == 'sale') ||
            (_selectedFilter == 'Expense' && data['type'] == 'expense')) {
          final amountRaw = data['amount'];
          final amount = (amountRaw is num ? amountRaw.toDouble() : (amountRaw is String ? double.tryParse(amountRaw) ?? 0.0 : 0.0));
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

    for (var doc in ordersSnap.docs) {
      final data = doc.data();
      final supplierId = data['supplierId'] as String? ?? '';
      final supplierName = suppliersMap[supplierId] ?? 'Unknown Supplier';
      final searchQuery = _searchController.text.toLowerCase();
      final title = '${data['itemName']} (${data['status']}) - $supplierName'.toLowerCase();
      if (searchQuery.isEmpty || title.contains(searchQuery)) {
        if (_selectedFilter == 'All' || _selectedFilter == 'Seller') {
          final amountRaw = data['purchaseAmount'];
          final amount = (amountRaw is num ? amountRaw.toDouble() : (amountRaw is String ? double.tryParse(amountRaw) ?? 0.0 : 0.0));
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
  }
}