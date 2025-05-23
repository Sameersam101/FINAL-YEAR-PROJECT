import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'transactions.dart';
import 'suppliers.dart';
import 'inventory.dart';

class AdminUserDetailsPage extends StatefulWidget {
  final String userId;

  const AdminUserDetailsPage({super.key, required this.userId});

  @override
  _AdminUserDetailsPageState createState() => _AdminUserDetailsPageState();
}

class _AdminUserDetailsPageState extends State<AdminUserDetailsPage> {
  String _filter = 'Overview';
  final Map<String, dynamic> _cachedData = {};

  Stream<int> _getTotalProductsSold() {
    return FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.userId)
        .collection('transactions')
        .where('type', isEqualTo: 'sale')
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('quantities') && data['quantities'] is Map) {
          final quantities = data['quantities'] as Map<String, dynamic>;
          total += quantities.values.fold(0, (sum, value) => sum + (value as num).toInt());
        }
      }
      _cachedData['totalProductsSold'] = total;
      return total;
    }).handleError((e) {
      debugPrint('Error in _getTotalProductsSold: $e');
      return 0;
    });
  }

  Stream<int> _getTotalSuppliers() {
    return FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.userId)
        .collection('Suppliers')
        .snapshots()
        .map((snapshot) {
      _cachedData['totalSuppliers'] = snapshot.docs.length;
      return snapshot.docs.length;
    }).handleError((e) {
      debugPrint('Error in _getTotalSuppliers: $e');
      return 0;
    });
  }

  Stream<double> _getTotalIncome() {
    return FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.userId)
        .collection('transactions')
        .where('type', isEqualTo: 'sale')
        .snapshots()
        .map((snapshot) {
      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('amount')) {
          total += (data['amount'] as num).toDouble();
        }
      }
      _cachedData['totalIncome'] = total;
      return total;
    }).handleError((e) {
      debugPrint('Error in _getTotalIncome: $e');
      return 0.0;
    });
  }

  Stream<double> _getTotalExpenses() {
    return FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.userId)
        .collection('transactions')
        .where('type', isEqualTo: 'expense')
        .snapshots()
        .map((snapshot) {
      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('amount')) {
          total += (data['amount'] as num).toDouble();
        }
      }
      _cachedData['totalExpenses'] = total;
      return total;
    }).handleError((e) {
      debugPrint('Error in _getTotalExpenses: $e');
      return 0.0;
    });
  }

  Stream<int> _getTotalProducts() {
    return FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.userId)
        .collection('Inventory')
        .snapshots()
        .map((snapshot) {
      _cachedData['totalProducts'] = snapshot.docs.length;
      return snapshot.docs.length;
    }).handleError((e) {
      debugPrint('Error in _getTotalProducts: $e');
      return 0;
    });
  }

  Stream<double> _getTodaysSales() {
    final today = DateTime.now();
    return FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.userId)
        .collection('transactions')
        .where('type', isEqualTo: 'sale')
        .snapshots()
        .map((snapshot) {
      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('amount') && data.containsKey('date')) {
          final date = (data['date'] as Timestamp).toDate();
          if (date.year == today.year && date.month == today.month && date.day == today.day) {
            total += (data['amount'] as num).toDouble();
          }
        }
      }
      _cachedData['todaysSales'] = total;
      return total;
    }).handleError((e) {
      debugPrint('Error in _getTodaysSales: $e');
      return 0.0;
    });
  }

  Future<void> _generateAndDownloadPDF(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .get();
      final userData = userDoc.data() ?? {};
      final inventory = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .collection('Inventory')
          .get();
      final suppliers = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .collection('Suppliers')
          .get();
      final transactions = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .collection('transactions')
          .orderBy('date', descending: true)
          .get();

      double totalCashIn = 0;
      double totalCashOut = 0;
      for (var doc in transactions.docs) {
        final data = doc.data();
        final isIncome = data['type'] == 'sale';
        final amount = ((data['amount'] as num?)?.toDouble() ?? 0.0);
        if (isIncome) {
          totalCashIn += amount;
        } else {
          totalCashOut += amount;
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            pw.Text(
              'User Details Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text('User Information', style: const pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 10),
            pw.Text('Name: ${userData['Name'] ?? 'Unknown'}'),
            pw.Text('Mobile: ${userData['Mobile'] ?? 'No mobile'}'),
            pw.Text('Email: ${userData['Email'] ?? 'No email'}'),
            pw.Text('Business: ${userData['BusinessName'] ?? 'No business'}'),
            pw.Text(
              'Generated On: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Overview Statistics', style: const pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 10),
            pw.Text('Total Products Sold: ${_cachedData['totalProductsSold'] ?? 0}'),
            pw.Text('Total Suppliers: ${_cachedData['totalSuppliers'] ?? 0}'),
            pw.Text('Total Income: रु ${(_cachedData['totalIncome'] ?? 0.0).toStringAsFixed(2)}'),
            pw.Text('Total Expenses: रु ${(_cachedData['totalExpenses'] ?? 0.0).toStringAsFixed(2)}'),
            pw.Text('Total Products: ${_cachedData['totalProducts'] ?? 0}'),
            pw.Text('Today\'s Sales: रु ${(_cachedData['todaysSales'] ?? 0.0).toStringAsFixed(2)}'),
            pw.SizedBox(height: 20),
            pw.Text('Inventory', style: const pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 10),
            inventory.docs.isNotEmpty
                ? pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FixedColumnWidth(200),
                1: const pw.FixedColumnWidth(100),
                2: const pw.FixedColumnWidth(100),
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Text('Product Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Quantity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                ...inventory.docs.map((doc) {
                  final data = doc.data();
                  return pw.TableRow(
                    children: [
                      pw.Text(data['productName'] ?? 'Unknown'),
                      pw.Text((data['quantity'] ?? 0).toString()),
                      pw.Text('रु ${(data['price'] ?? 0).toStringAsFixed(2)}'),
                    ],
                  );
                }),
              ],
            )
                : pw.Text('No inventory available.'),
            pw.SizedBox(height: 20),
            pw.Text('Suppliers', style: const pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 10),
            suppliers.docs.isNotEmpty
                ? pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FixedColumnWidth(150),
                1: const pw.FixedColumnWidth(150),
                2: const pw.FixedColumnWidth(200),
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Text('Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Mobile', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Email', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                ...suppliers.docs.map((doc) {
                  final data = doc.data();
                  return pw.TableRow(
                    children: [
                      pw.Text(data['name'] ?? 'Unknown'),
                      pw.Text(data['mobile'] ?? 'No mobile'),
                      pw.Text(data['email'] ?? 'No email'),
                    ],
                  );
                }),
              ],
            )
                : pw.Text('No suppliers available.'),
            pw.SizedBox(height: 20),
            pw.Text('Transactions', style: const pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 10),
            transactions.docs.isNotEmpty
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
                ...transactions.docs.map((doc) {
                  final data = doc.data();
                  final isIncome = data['type'] == 'sale';
                  final amount = ((data['amount'] as num?)?.toDouble() ?? 0.0);
                  final title = _buildTransactionTitle(data);
                  final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final dateStr = DateFormat('MMM d - yyyy').format(date);
                  final timeStr = DateFormat('dd MMM, HH:mm').format(createdAt);
                  return pw.TableRow(
                    children: [
                      pw.Text(dateStr),
                      pw.Text(title),
                      pw.Text(isIncome ? 'Cash In' : 'Cash Out'),
                      pw.Text(
                        (isIncome ? '+रु ' : '-रु ') + amount.toStringAsFixed(2),
                        style: pw.TextStyle(
                          color: isIncome ? PdfColors.green : PdfColors.red,
                        ),
                      ),
                      pw.Text(timeStr),
                    ],
                  );
                }),
                pw.TableRow(
                  children: [
                    pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(''),
                    pw.Text(''),
                    pw.Text(
                      'Cash In: +रु ${totalCashIn.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green),
                    ),
                    pw.Text(''),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Text(''),
                    pw.Text(''),
                    pw.Text(''),
                    pw.Text(
                      'Cash Out: -रु ${totalCashOut.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red),
                    ),
                    pw.Text(''),
                  ],
                ),
              ],
            )
                : pw.Text('No transactions available.'),
          ],
        ),
      );

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/user_details_${widget.userId}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareFiles(
        [file.path],
        text: 'User Details Report for ${userData['Name'] ?? 'Unknown'} (${userData['BusinessName'] ?? 'Unknown Business'})',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF generated and shared', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: const Color(0xFF05668D), // Deep Teal
        ),
      );
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: const Color(0xFFD62828), // Vivid Red
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF05668D), Color(0xFF6E9075)], // Deep Teal to Sage Green
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
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(mediaQuery.size.width * 0.02),
                        decoration: BoxDecoration(
                          color: const Color(0xFF221E22).withOpacity(0.2), // Dark Gray
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'User Details',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: mediaQuery.size.width * 0.06,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _generateAndDownloadPDF(context),
                      child: Container(
                        padding: EdgeInsets.all(mediaQuery.size.width * 0.02),
                        decoration: BoxDecoration(
                          color: const Color(0xFF221E22).withOpacity(0.2), // Dark Gray
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.download,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
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
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(mediaQuery.size.width * 0.05),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('Users')
                                .doc(widget.userId)
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
                                  'Failed to load user details.',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFD62828), // Vivid Red
                                    fontSize: mediaQuery.size.width * 0.04,
                                  ),
                                );
                              }
                              if (!snapshot.hasData || !snapshot.data!.exists) {
                                return Text(
                                  'User not found.',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFD62828), // Vivid Red
                                    fontSize: mediaQuery.size.width * 0.04,
                                  ),
                                );
                              }

                              var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                              final name = userData['Name'] ?? 'Unknown';
                              final mobile = userData['Mobile'] ?? 'No mobile';
                              final email = userData['Email'] ?? 'No email';
                              final businessName = userData['BusinessName'] ?? 'No business';

                              return AnimatedOpacity(
                                opacity: 1.0,
                                duration: const Duration(milliseconds: 500),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.inter(
                                        fontSize: mediaQuery.size.width * 0.05,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF221E22), // Dark Gray
                                      ),
                                    ),
                                    SizedBox(height: mediaQuery.size.height * 0.01),
                                    Text(
                                      'Mobile: $mobile',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF221E22).withOpacity(0.6), // Dark Gray
                                        fontSize: mediaQuery.size.width * 0.035,
                                      ),
                                    ),
                                    Text(
                                      'Email: $email',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF221E22).withOpacity(0.6), // Dark Gray
                                        fontSize: mediaQuery.size.width * 0.035,
                                      ),
                                    ),
                                    Text(
                                      'Business: $businessName',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF221E22).withOpacity(0.6), // Dark Gray
                                        fontSize: mediaQuery.size.width * 0.035,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          SizedBox(height: mediaQuery.size.height * 0.02),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('Overview'),
                                SizedBox(width: mediaQuery.size.width * 0.02),
                                _buildFilterChip('Inventory'),
                                SizedBox(width: mediaQuery.size.width * 0.02),
                                _buildFilterChip('Suppliers'),
                                SizedBox(width: mediaQuery.size.width * 0.02),
                                _buildFilterChip('Transactions'),
                              ],
                            ),
                          ),
                          SizedBox(height: mediaQuery.size.height * 0.02),
                          Visibility(
                            visible: _filter == 'Overview',
                            maintainState: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Overview',
                                  style: GoogleFonts.inter(
                                    fontSize: mediaQuery.size.width * 0.045,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF221E22), // Dark Gray
                                  ),
                                ),
                                SizedBox(height: mediaQuery.size.height * 0.015),
                                GridView.count(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: mediaQuery.size.width * 0.04,
                                  mainAxisSpacing: mediaQuery.size.height * 0.015,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 1.8,
                                  children: [
                                    _buildOverviewCard(
                                      title: 'Total Stock out',
                                      stream: _getTotalProductsSold(),
                                      icon: Icons.sell,
                                      color: const Color(0xFF6E9075), // Sage Green
                                    ),
                                    _buildOverviewCard(
                                      title: 'Total Suppliers',
                                      stream: _getTotalSuppliers(),
                                      icon: Icons.group,
                                      color: const Color(0xFF05668D), // Deep Teal
                                    ),
                                    _buildOverviewCard(
                                      title: 'Total Income',
                                      stream: _getTotalIncome(),
                                      icon: Icons.account_balance_wallet,
                                      color: const Color(0xFF05668D), // Deep Teal
                                      isCurrency: true,
                                    ),
                                    _buildOverviewCard(
                                      title: 'Total Expenses',
                                      stream: _getTotalExpenses(),
                                      icon: Icons.money_off,
                                      color: const Color(0xFFD62828), // Vivid Red
                                      isCurrency: true,
                                    ),
                                    _buildOverviewCard(
                                      title: 'Total Products',
                                      stream: _getTotalProducts(),
                                      icon: Icons.inventory_2,
                                      color: const Color(0xFF6E9075), // Sage Green
                                    ),
                                    _buildOverviewCard(
                                      title: 'Today\'s Sales',
                                      stream: _getTodaysSales(),
                                      icon: Icons.today,
                                      color: const Color(0xFFD62828), // Vivid Red
                                      isCurrency: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Visibility(
                            visible: _filter == 'Inventory',
                            maintainState: true,
                            child: InventorySection(userId: widget.userId),
                          ),
                          Visibility(
                            visible: _filter == 'Suppliers',
                            maintainState: true,
                            child: SuppliersSection(
                              userId: widget.userId,
                              onAddSupplier: () => setState(() {}),
                            ),
                          ),
                          Visibility(
                            visible: _filter == 'Transactions',
                            maintainState: true,
                            child: TransactionsSection(userId: widget.userId),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _filter == 'Suppliers'
          ? FloatingActionButton(
        onPressed: () {
          SuppliersSection.showAddSupplierDialog(context, widget.userId, () => setState(() {}));
        },
        backgroundColor: const Color(0xFF05668D), // Deep Teal
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 24,
        ),
      )
          : null,
    );
  }

  Widget _buildFilterChip(String filterName) {
    final mediaQuery = MediaQuery.of(context);
    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = filterName;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: mediaQuery.size.width * 0.04,
          vertical: mediaQuery.size.height * 0.015,
        ),
        decoration: BoxDecoration(
          color: _filter == filterName ? const Color(0xFF05668D) : const Color(0xFF221E22).withOpacity(0.1), // Deep Teal or Dark Gray
          borderRadius: BorderRadius.circular(mediaQuery.size.width * 0.03),
          boxShadow: _filter == filterName
              ? [
            BoxShadow(
              color: const Color(0xFF221E22).withOpacity(0.2), // Dark Gray
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ]
              : [],
        ),
        child: Text(
          filterName,
          style: GoogleFonts.inter(
            fontSize: mediaQuery.size.width * 0.035,
            color: _filter == filterName ? Colors.white : const Color(0xFF221E22), // White or Dark Gray
            fontWeight: _filter == filterName ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required Stream<dynamic> stream,
    required IconData icon,
    required Color color,
    bool isCurrency = false,
  }) {
    final mediaQuery = MediaQuery.of(context);
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
        color: const Color(0xFFFFFFFF),
        child: Padding(
          padding: EdgeInsets.all(mediaQuery.size.width * 0.03),
          child: Row(
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: mediaQuery.size.width * 0.032,
                        color: const Color(0xFF221E22).withOpacity(0.7), // Dark Gray
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    SizedBox(height: mediaQuery.size.height * 0.005),
                    StreamBuilder<dynamic>(
                      stream: stream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                            'Error: ${snapshot.error}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFD62828), // Vivid Red
                              fontSize: mediaQuery.size.width * 0.035,
                            ),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return SizedBox(
                            height: mediaQuery.size.width * 0.04,
                            width: mediaQuery.size.width * 0.04,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF05668D)), // Deep Teal
                            ),
                          );
                        }
                        final value = snapshot.data ?? (isCurrency ? 0.0 : 0);
                        return Text(
                          isCurrency ? 'रु ${value.toStringAsFixed(2)}' : value.toString(),
                          style: GoogleFonts.inter(
                            fontSize: mediaQuery.size.width * 0.035,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF221E22), // Dark Gray
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}