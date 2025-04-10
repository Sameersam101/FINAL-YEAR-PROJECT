import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'dashboard.dart';
import 'inventorypage.dart';
import 'transaction.dart';
import 'Scanpage.dart';
import 'Prediction.dart'; // Add import for prediction.dart

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});


  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        errorMessage = 'Please log in to view analytics';
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Fetch user details (name and business name)
  Future<Map<String, String>> _fetchUserDetails(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return {
          'Name': data['fullName']?.toString() ?? data['displayName']?.toString() ?? data['Name']?.toString() ?? 'Unknown User',
          'BusinessName': data['companyName']?.toString() ??  data['BusinessName']?.toString() ?? 'Unknown Business',
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
  Future<void> _generateAndDownloadPDF() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDetails = await _fetchUserDetails(user.uid);
    final userName = userDetails['Name']!;
    final businessName = userDetails['BusinessName']!;
    final suppliersMap = await _fetchSuppliersMap(user.uid);

    // Fetch transactions and orders
    final transactionsSnap = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .get();

    final ordersSnap = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('Orders')
        .orderBy('createdAt', descending: true)
        .get();

    final inventorySnap = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('Inventory')
        .get();

    // Calculate stats
    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    double totalSupplierPayments = 0.0;
    Map<String, double> productPrices = {};
    Map<String, double> totalRevenuePerProduct = {};
    Map<String, int> totalQuantityPerProduct = {};

    // Process transactions
    for (var doc in transactionsSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final type = data['type'] as String? ?? '';
      if (type == 'sale') {
        totalIncome += amount;
      } else if (type == 'expense') {
        totalExpenses += amount;
      }
    }

    // Process orders
    for (var doc in ordersSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final paymentAmount = _parseAmount(data['paymentAmount']);
      totalSupplierPayments += paymentAmount;
    }

    // Process inventory
    for (var doc in inventorySnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final productName = data['productName'] as String? ?? 'Unknown';
      final price = (data['sellingPrice'] as num?)?.toDouble() ?? 0.0;
      productPrices[productName] = price;
    }

    for (var doc in transactionsSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['type'] == 'sale') {
        final quantities = data['quantities'] as Map<String, dynamic>? ?? {};
        for (var entry in quantities.entries) {
          final productName = entry.key as String;
          final quantity = (entry.value as num?)?.toInt() ?? 0;
          final price = productPrices[productName] ?? 0.0;
          totalRevenuePerProduct[productName] =
              (totalRevenuePerProduct[productName] ?? 0.0) + (quantity * price);
          totalQuantityPerProduct[productName] =
              (totalQuantityPerProduct[productName] ?? 0) + quantity;
        }
      }
    }

    final combinedExpenses = totalExpenses + totalSupplierPayments;
    final netProfit = totalIncome - combinedExpenses;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Text('Analytics Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('User: $userName', style: const pw.TextStyle(fontSize: 18)),
            pw.Text('Business: $businessName', style: const pw.TextStyle(fontSize: 18)),
            pw.Text('Generated On: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 20),
            pw.Text('Summary', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Total Income: Rs ${totalIncome.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 16)),
            pw.Text('Total Expenses: Rs ${combinedExpenses.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 16)),
            pw.Text('Net Profit: Rs ${netProfit.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 20),
            pw.Text('Product-Wise Revenue', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            totalRevenuePerProduct.isNotEmpty
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
                    pw.Text('Product', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Units Sold', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                ...totalRevenuePerProduct.entries.map((entry) {
                  final productName = entry.key;
                  final revenue = entry.value;
                  final quantity = totalQuantityPerProduct[productName] ?? 0;
                  return pw.TableRow(
                    children: [
                      pw.Text(productName),
                      pw.Text(quantity.toString()),
                      pw.Text('Rs ${revenue.toStringAsFixed(2)}'),
                    ],
                  );
                }),
              ],
            )
                : pw.Text('No product sales data available.'),
            pw.SizedBox(height: 20),
            pw.Text('Sales Transactions', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            transactionsSnap.docs.any((doc) => doc['type'] == 'sale')
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
                ...transactionsSnap.docs.where((doc) => doc['type'] == 'sale').map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                  final quantities = data['quantities'] as Map<String, dynamic>? ?? {};
                  final title = quantities.entries.map((e) => '${e.key} (${e.value})').join(', ');
                  final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final dateStr = DateFormat('MMM d - yyyy').format(date);
                  final timeStr = DateFormat('dd MMM, HH:mm').format(createdAt);
                  return pw.TableRow(
                    children: [
                      pw.Text(dateStr),
                      pw.Text(title.isNotEmpty ? title : 'Unknown Product'),
                      pw.Text('Cash In'),
                      pw.Text('+\Rs ${amount.toStringAsFixed(2)}', style: const pw.TextStyle(color: PdfColors.green)),
                      pw.Text(timeStr),
                    ],
                  );
                }),
              ],
            )
                : pw.Text('No sales transactions available.'),
            pw.SizedBox(height: 20),
            pw.Text('Expense Transactions', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            transactionsSnap.docs.any((doc) => doc['type'] == 'expense')
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
                ...transactionsSnap.docs.where((doc) => doc['type'] == 'expense').map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                  final description = data['description'] as String? ?? 'Unknown';
                  final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final dateStr = DateFormat('MMM d - yyyy').format(date);
                  final timeStr = DateFormat('dd MMM, HH:mm').format(createdAt);
                  return pw.TableRow(
                    children: [
                      pw.Text(dateStr),
                      pw.Text(description),
                      pw.Text('Cash Out'),
                      pw.Text('-\Rs ${amount.toStringAsFixed(2)}', style: const pw.TextStyle(color: PdfColors.red)),
                      pw.Text(timeStr),
                    ],
                  );
                }),
              ],
            )
                : pw.Text('No expense transactions available.'),
            pw.SizedBox(height: 20),
            pw.Text('Seller Transactions', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            ordersSnap.docs.isNotEmpty
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
                ...ordersSnap.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final amount = _parseAmount(data['paymentAmount']);
                  final supplierId = data['supplierId'] as String? ?? '';
                  final supplierName = suppliersMap[supplierId] ?? 'Unknown Supplier';
                  final title = '${data['itemName']} (${data['status']}) - $supplierName';
                  final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final dateStr = DateFormat('MMM d - yyyy').format(date);
                  final timeStr = DateFormat('dd MMM, HH:mm').format(createdAt);
                  return pw.TableRow(
                    children: [
                      pw.Text(dateStr),
                      pw.Text(title),
                      pw.Text('Seller'),
                      pw.Text('-\Rs ${amount.toStringAsFixed(2)}', style: const pw.TextStyle(color: PdfColors.red)),
                      pw.Text(timeStr),
                    ],
                  );
                }),
              ],
            )
                : pw.Text('No seller transactions available.'),
          ];
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/Analytics_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareFiles([file.path], text: 'Analytics Report for $userName ($businessName)');
  }

  Widget _buildStatCard(String title, double value, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'रु  ${value.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('transactions')
          .snapshots(),
      builder: (context, transactionSnapshot) {
        if (transactionSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (transactionSnapshot.hasError) {
          return Center(
            child: Text(
              'Error loading stats: ${transactionSnapshot.error}',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
            ),
          );
        }

        // Fetch supplier payments
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .collection('Orders')
              .snapshots(),
          builder: (context, orderSnapshot) {
            if (orderSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (orderSnapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading supplier payments: ${orderSnapshot.error}',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
                ),
              );
            }

            double totalIncome = 0.0;
            double totalExpenses = 0.0;
            double totalSupplierPayments = 0.0;

            // Calculate transaction-based income and expenses
            if (transactionSnapshot.hasData) {
              for (var doc in transactionSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                final type = data['type'] as String? ?? '';
                if (type == 'sale') {
                  totalIncome += amount;
                } else if (type == 'expense') {
                  totalExpenses += amount;
                }
              }
            }

            // Calculate supplier payments
            if (orderSnapshot.hasData) {
              for (var doc in orderSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final paymentAmount = _parseAmount(data['paymentAmount']);
                totalSupplierPayments += paymentAmount;
              }
            }

            // Combine expenses and supplier payments
            final combinedExpenses = totalExpenses + totalSupplierPayments;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatCard('Total Income', totalIncome, const Color(0xFF10B981)),
                const SizedBox(width: 12),
                _buildStatCard('Total Expenses', combinedExpenses, const Color(0xFFEF4444)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNetProfit() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('transactions')
          .snapshots(),
      builder: (context, transactionSnapshot) {
        if (transactionSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (transactionSnapshot.hasError) {
          return Center(
            child: Text(
              'Error loading net profit: ${transactionSnapshot.error}',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
            ),
          );
        }

        // Fetch supplier payments
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .collection('Orders')
              .snapshots(),
          builder: (context, orderSnapshot) {
            if (orderSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (orderSnapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading supplier payments: ${orderSnapshot.error}',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
                ),
              );
            }

            double totalIncome = 0.0;
            double totalExpenses = 0.0;
            double totalSupplierPayments = 0.0;

            // Calculate transaction-based income and expenses
            if (transactionSnapshot.hasData) {
              for (var doc in transactionSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                final type = data['type'] as String? ?? '';
                if (type == 'sale') {
                  totalIncome += amount;
                } else if (type == 'expense') {
                  totalExpenses += amount;
                }
              }
            }

            // Calculate supplier payments
            if (orderSnapshot.hasData) {
              for (var doc in orderSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final paymentAmount = _parseAmount(data['paymentAmount']);
                totalSupplierPayments += paymentAmount;
              }
            }

            // Combine expenses and supplier payments
            final combinedExpenses = totalExpenses + totalSupplierPayments;
            final netProfit = totalIncome - combinedExpenses;

            return Center(
              child: Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Net Profit',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF221E22),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'रु  ${netProfit.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
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
    );
  }

  double _parseAmount(dynamic value) {
    if (value is double) {
      return value;
    } else if (value is int) {
      return value / 100.0;
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Widget _buildIncomeBreakdown() {
    final mediaQuery = MediaQuery.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('transactions')
          .where('type', isEqualTo: 'sale')
          .snapshots(),
      builder: (context, transactionSnapshot) {
        if (transactionSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (transactionSnapshot.hasError) {
          return Center(
            child: Text(
              'Error loading sales data: ${transactionSnapshot.error}',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
            ),
          );
        }
        if (!transactionSnapshot.hasData || transactionSnapshot.data!.docs.isEmpty) {
          return Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Income Breakdown',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF221E22),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No sales data available',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .collection('Inventory')
              .snapshots(),
          builder: (context, inventorySnapshot) {
            if (inventorySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (inventorySnapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading inventory: ${inventorySnapshot.error}',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
                ),
              );
            }

            Map<String, double> productPrices = {};
            if (inventorySnapshot.hasData) {
              for (var doc in inventorySnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final productName = data['productName'] as String? ?? 'Unknown';
                final price = (data['sellingPrice'] as num?)?.toDouble() ?? 0.0;
                productPrices[productName] = price;
              }
            }

            Map<String, double> totalRevenuePerProduct = {};
            Map<String, int> totalQuantityPerProduct = {};

            for (var doc in transactionSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final quantities = data['quantities'] as Map<String, dynamic>? ?? {};
              for (var entry in quantities.entries) {
                final productName = entry.key as String;
                final quantity = (entry.value as num?)?.toInt() ?? 0;
                final price = productPrices[productName] ?? 0.0;
                totalRevenuePerProduct[productName] =
                    (totalRevenuePerProduct[productName] ?? 0.0) + (quantity * price);
                totalQuantityPerProduct[productName] =
                    (totalQuantityPerProduct[productName] ?? 0) + quantity;
              }
            }

            final products = totalRevenuePerProduct.entries
                .where((entry) => (totalQuantityPerProduct[entry.key] ?? 0) > 10)
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Income Breakdown',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF221E22),
                          ),
                        ),
                        if (products.isNotEmpty)
                          Text(
                            '${products.length} products',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (products.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Text(
                          'No products with sales > 10 units',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      )
                    else
                      ...products.map((entry) {
                        final productName = entry.key;
                        final revenue = entry.value;
                        final quantity = totalQuantityPerProduct[productName] ?? 0;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(
                              productName,
                              style: GoogleFonts.inter(
                                fontSize: mediaQuery.size.width * 0.04,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF221E22),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Sold: $quantity units',
                              style: GoogleFonts.inter(
                                fontSize: mediaQuery.size.width * 0.03,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                            trailing: Text(
                              'रु  ${revenue.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: mediaQuery.size.width * 0.04,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBarChart() {
    final mediaQuery = MediaQuery.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('transactions')
          .where('type', isEqualTo: 'sale')
          .snapshots(),
      builder: (context, transactionSnapshot) {
        if (transactionSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (transactionSnapshot.hasError) {
          return Center(
            child: Text(
              'Error loading chart data: ${transactionSnapshot.error}',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
            ),
          );
        }
        if (!transactionSnapshot.hasData || transactionSnapshot.data!.docs.isEmpty) {
          return Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales by Product',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF221E22),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'No sales data available',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .collection('Inventory')
              .snapshots(),
          builder: (context, inventorySnapshot) {
            if (inventorySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (inventorySnapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading inventory: ${inventorySnapshot.error}',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
                ),
              );
            }

            Map<String, double> productPrices = {};
            if (inventorySnapshot.hasData) {
              for (var doc in inventorySnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final productName = data['productName'] as String? ?? 'Unknown';
                final price = (data['sellingPrice'] as num?)?.toDouble() ?? 0.0;
                productPrices[productName] = price;
              }
            }

            Map<String, double> revenuePerProduct = {};
            Map<String, int> quantityPerProduct = {};

            for (var doc in transactionSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final quantities = data['quantities'] as Map<String, dynamic>? ?? {};
              for (var entry in quantities.entries) {
                final productName = entry.key as String;
                final quantity = (entry.value as num?)?.toInt() ?? 0;
                final price = productPrices[productName] ?? 0.0;
                revenuePerProduct[productName] =
                    (revenuePerProduct[productName] ?? 0.0) + (quantity * price);
                quantityPerProduct[productName] =
                    (quantityPerProduct[productName] ?? 0) + quantity;
              }
            }

            final products = revenuePerProduct.entries
                .where((entry) => (quantityPerProduct[entry.key] ?? 0) > 10)
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final productNames = products.map((e) => e.key).toList();

            final barGroups = <BarChartGroupData>[];
            const barColors = [
              Colors.blue,
              Colors.green,
              Colors.red,
              Colors.orange,
              Colors.purple,
              Colors.teal,
              Colors.cyan,
              Colors.amber,
              Colors.indigo,
              Colors.lime,
            ];

            for (var i = 0; i < products.length; i++) {
              barGroups.add(
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: products[i].value,
                      color: barColors[i % barColors.length],
                      width: 12,
                    ),
                  ],
                ),
              );
            }

            return Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales by Product',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF221E22),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: mediaQuery.size.height * 0.25,
                      child: barGroups.isEmpty
                          ? Center(
                        child: Text(
                          'No products with sales > 10 units',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      )
                          : BarChart(
                        BarChartData(
                          barGroups: barGroups,
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 && index < productNames.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Transform.rotate(
                                        angle: -30 * 3.14159 / 180,
                                        child: Text(
                                          productNames[index],
                                          style: GoogleFonts.inter(
                                            color: Colors.black,
                                            fontSize: mediaQuery.size.width * 0.025,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: GoogleFonts.inter(
                                      color: Colors.black,
                                      fontSize: mediaQuery.size.width * 0.025,
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: true),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                if (groupIndex < productNames.length) {
                                  return BarTooltipItem(
                                    'रु  ${rod.toY.toStringAsFixed(2)}',
                                    GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader() {
    final mediaQuery = MediaQuery.of(context);
    final user = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: mediaQuery.size.width * 0.05,
        vertical: mediaQuery.size.height * 0.02,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const DashboardPage(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          Text(
            'Analytics',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: mediaQuery.size.width * 0.06,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              if (user != null)
                GestureDetector(
                  onTap: () async {
                    try {
                      await _generateAndDownloadPDF();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error generating PDF: $e')),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

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
    final mediaQuery = MediaQuery.of(context);
    return Scaffold(
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
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      errorMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF221E22),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _checkUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Retry',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(mediaQuery.size.width * 0.08),
                          topRight: Radius.circular(mediaQuery.size.width * 0.08),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.05),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              _buildStatsRow(),
                              const SizedBox(height: 12),
                              _buildNetProfit(),
                              const SizedBox(height: 12),
                              _buildBarChart(),
                              const SizedBox(height: 12),
                              _buildIncomeBreakdown(),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation, secondaryAnimation) => const Predictionpage(),
                                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                          return SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(1, 0),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF97316),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'AI PREDICTION',
                                    style: GoogleFonts.inter(
                                      fontSize: mediaQuery.size.width * 0.045,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1E3A8A),
        unselectedItemColor: const Color(0xFF6B7280),
        currentIndex: 4,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(context, _createRoute(const DashboardPage()));
              break;
            case 1:
              Navigator.pushReplacement(context, _createRoute(const InventoryPage()));
              break;
            case 2:
              Navigator.pushReplacement(context, _createRoute(const ScanPage()));
              break;
            case 3:
              Navigator.pushReplacement(context, _createRoute(const Transactionpage()));
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
}