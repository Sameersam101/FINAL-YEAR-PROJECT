import 'package:arthikapp/Screens/Scanpage.dart';
import 'package:arthikapp/Screens/receivenotification.dart';
import 'package:arthikapp/notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';
import 'profile.dart';
import 'transaction.dart';
import 'sellerpage.dart';
import 'inventorypage.dart';
import 'analyticspage.dart';
import 'login_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

StreamSubscription<QuerySnapshot>? _inventorySubscription;

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(context, _createRoute(const InventoryPage()));
        break;
      case 2:
        Navigator.push(context, _createRoute(const ScanPage()));
        break;
      case 3:
        Navigator.push(context, _createRoute(Transactionpage()));
        break;
      case 4:
        Navigator.push(context, _createRoute(AnalyticsPage()));
        break;
    }
  }

  Widget _buildNotificationIconButton(String userId, MediaQueryData mediaQuery) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Stack(
          children: [
            GestureDetector(
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) => const ReceiveNotificationDialog(),
                );
              },
              child: Container(
                padding: EdgeInsets.all(mediaQuery.size.width * 0.02),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications_rounded,
                  color: Colors.white,
                  size: mediaQuery.size.width * 0.06,
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF97316),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: mediaQuery.size.width * 0.03,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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

  @override
  void initState() {
    super.initState();
    final notificationsServices = Provider.of<NotificationsServices>(context, listen: false);
    notificationsServices.requestNotificationPermission();
    // Set the context for NotificationsServices to start the timer
    notificationsServices.setContext(context);
    _setupInventoryListener();
  }

  void _setupInventoryListener() {
    print('Setting up inventory listener in Dashboard');
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      print('Auth state changed, user: ${user?.uid}');
      _inventorySubscription?.cancel();

      if (user != null) {
        print('Listening to inventory changes for user: ${user.uid}');
        _inventorySubscription = FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .collection('Inventory')
            .snapshots()
            .listen((snapshot) {
          print('Inventory snapshot received, changes: ${snapshot.docChanges.length}');
          if (!mounted) return; // Prevent setState if widget is disposed
          final notificationsServices = Provider.of<NotificationsServices>(context, listen: false);
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
              final productName = data['productName'] as String? ?? 'Unknown Product';
              print('Document changed: ${change.doc.id}, quantity: $quantity, productName: $productName');
              notificationsServices.checkAndSendLowStockNotification(
                context,
                change.doc.id,
                productName,
                quantity,
                user.uid,
              );
            }
          }
        }, onError: (error) {
          print('Error in inventory stream: $error');
        });
      } else {
        print('No user logged in, inventory listener not started');
      }
    });
  }

  @override
  void dispose() {
    print('Disposing inventory listener in Dashboard');
    _inventorySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final mediaQuery = MediaQuery.of(context);

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, _createRoute(const LoginPage()));
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                  padding: EdgeInsets.all(mediaQuery.size.width * 0.05),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dashboard',
                            style: GoogleFonts.inter(
                              fontSize: mediaQuery.size.width * 0.06,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Row(
                            children: [
                              _buildNotificationIconButton(user.uid, mediaQuery),
                              SizedBox(width: mediaQuery.size.width * 0.02),
                              _buildIconButton(
                                icon: Icons.person_rounded,
                                onPressed: () {
                                  Navigator.push(context, _createRoute(ProfileScreen()));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: mediaQuery.size.height * 0.02),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('Users')
                            .doc(user.uid)
                            .collection('transactions')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildSummaryCard('Total Balance', 'Loading...', const Color(0xFF10B981), mediaQuery),
                                ),
                                Expanded(
                                  child: _buildSummaryCard('Total Expense', 'Loading...', const Color(0xFFEF4444), mediaQuery),
                                ),
                              ],
                            );
                          }
                          if (snapshot.hasError) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildSummaryCard('Total Balance', 'Error', const Color(0xFF10B981), mediaQuery),
                                ),
                                Expanded(
                                  child: _buildSummaryCard('Total Expense', 'Error', const Color(0xFFEF4444), mediaQuery),
                                ),
                              ],
                            );
                          }

                          double totalBalance = 0.0;
                          double totalExpense = 0.0;

                          for (final doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final amountRaw = data['amount'];
                            final amount = (amountRaw is num
                                ? amountRaw.toDouble()
                                : (amountRaw is String ? double.tryParse(amountRaw) ?? 0.0 : 0.0));
                            if (data['type'] == 'sale') {
                              totalBalance += amount;
                            } else if (data['type'] == 'expense') {
                              totalExpense += amount;
                            }
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildSummaryCard('Total Balance', '\रु ${totalBalance.toStringAsFixed(2)}', const Color(0xFF10B981), mediaQuery),
                              ),
                              Expanded(
                                child: _buildSummaryCard('Total Expense', '\रु ${totalExpense.toStringAsFixed(2)}', const Color(0xFFEF4444), mediaQuery),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
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
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(mediaQuery.size.width * 0.05),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quick Links',
                                  style: GoogleFonts.inter(
                                    fontSize: mediaQuery.size.width * 0.045,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF221E22),
                                  ),
                                ),
                                SizedBox(height: mediaQuery.size.height * 0.015),
                                GridView.count(
                                  crossAxisCount: 4,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 1,
                                  children: [
                                    _buildQuickLink(Icons.qr_code_scanner, 'Scanner', () => Navigator.push(context, _createRoute(ScanPage()))),
                                    _buildQuickLink(Icons.person_rounded, 'Seller', () => Navigator.push(context, _createRoute(const SellerPage()))),
                                    _buildQuickLink(Icons.inventory_2_rounded, 'Inventory', () => Navigator.push(context, _createRoute(const InventoryPage()))),
                                    _buildQuickLink(Icons.bar_chart_rounded, 'Analytics', () => Navigator.push(context, _createRoute(AnalyticsPage()))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.05),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recent Transactions',
                                  style: GoogleFonts.inter(
                                    fontSize: mediaQuery.size.width * 0.045,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF221E22),
                                  ),
                                ),
                                SizedBox(height: mediaQuery.size.height * 0.01),
                                StreamBuilder<List<Map<String, dynamic>>>(
                                  stream: _transactionStream(user.uid),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    if (snapshot.hasError) {
                                      return Text('Error: ${snapshot.error}');
                                    }
                                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                      return Text(
                                        'No transactions available',
                                        style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04),
                                      );
                                    }

                                    final transactionsByDate = <String, List<Map<String, dynamic>>>{};
                                    for (final txn in snapshot.data!) {
                                      final date = (txn['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                                      final dateStr = DateFormat('MMM d - yyyy').format(date).toUpperCase();
                                      transactionsByDate.putIfAbsent(dateStr, () => []).add(txn);
                                    }

                                    return Column(
                                      children: transactionsByDate.entries.map((entry) {
                                        final date = entry.key;
                                        final transactions = entry.value;
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
                                              return _transactionItem(title, amount, isIncome, timeStr);
                                            }),
                                          ],
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                                SizedBox(height: mediaQuery.size.height * 0.02),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSaleDialog(context),
        backgroundColor: const Color(0xFFF97316),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1E3A8A),
        unselectedItemColor: const Color(0xFF6B7280),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
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

  Widget _buildSummaryCard(String title, String amount, Color color, MediaQueryData mediaQuery) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.01),
      padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: mediaQuery.size.width * 0.03,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: mediaQuery.size.height * 0.01),
          Text(
            amount,
            style: GoogleFonts.inter(
              fontSize: mediaQuery.size.width * 0.035,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLink(IconData icon, String label, VoidCallback onTap) {
    final mediaQuery = MediaQuery.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: EdgeInsets.all(mediaQuery.size.width * 0.03),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: const Color(0xFF1E3A8A),
                size: mediaQuery.size.width * 0.07,
              ),
              SizedBox(height: mediaQuery.size.height * 0.005),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: mediaQuery.size.width * 0.03,
                  color: const Color(0xFF221E22),
                ),
                textAlign: TextAlign.center,
              ),
            ],
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

  Widget _transactionItem(String title, num amount, bool isIncome, String timestamp) {
    final mediaQuery = MediaQuery.of(context);
    final isSeller = title.contains('(') && title.contains(' - ');
    final displayAmount = isSeller ? amount.toDouble() : (amount.toDouble());

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
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
                  Text(
                    isIncome ? 'Cash In' : 'Cash Out',
                    style: GoogleFonts.inter(
                      fontSize: mediaQuery.size.width * 0.03,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (isIncome ? '+ ' : '- ') + 'रु ${displayAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: mediaQuery.size.width * 0.035,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
                Text(
                  timestamp,
                  style: GoogleFonts.inter(
                    fontSize: mediaQuery.size.width * 0.023,
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
      if (quantities.isNotEmpty) {
        return quantities.entries.map((e) => '${e.key} (${e.value})').join(', ');
      }
      return 'Unknown Product';
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
        .limit(6)
        .snapshots();

    final ordersStream = FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('Orders')
        .orderBy('createdAt', descending: true)
        .limit(6)
        .snapshots();

    return CombineLatestStream.combine2(
      transactionsStream,
      ordersStream,
          (QuerySnapshot transactions, QuerySnapshot orders) async {
        final suppliersMap = await _fetchSuppliersMap(userId);
        List<Map<String, dynamic>> combined = [];

        for (var doc in transactions.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amountRaw = data['amount'];
          final amount = amountRaw is num
              ? amountRaw
              : (amountRaw is String ? int.tryParse(amountRaw) ?? 0 : 0);
          combined.add({
            ...data,
            'source': 'transaction',
            'amount': amount,
            'date': data['date'] as Timestamp? ?? Timestamp.now(),
            'createdAt': data['createdAt'] as Timestamp? ?? Timestamp.now(),
          });
        }

        for (var doc in orders.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final supplierId = data['supplierId'] as String? ?? '';
          final supplierName = suppliersMap[supplierId] ?? 'Unknown Supplier';
          final amountRaw = data['purchaseAmount'];
          final amount = amountRaw is num
              ? amountRaw
              : (amountRaw is String ? int.tryParse(amountRaw) ?? 0 : 0);
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

        combined.sort((a, b) {
          final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

        return combined.take(6).toList();
      },
    ).asyncMap((combined) => combined);
  }

  void _showAddSaleDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => AddSaleDialog(
        onSwitchToExpense: () => _showAddExpenseDialog(context),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: child,
        );
      },
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => AddExpenseDialog(
        onSwitchToSale: () => _showAddSaleDialog(context),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: child,
        );
      },
    );
  }
}

class AddSaleDialog extends StatefulWidget {
  final VoidCallback onSwitchToExpense;

  const AddSaleDialog({super.key, required this.onSwitchToExpense});

  @override
  State<AddSaleDialog> createState() => _AddSaleDialogState();
}

class _AddSaleDialogState extends State<AddSaleDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _customProductController = TextEditingController();
  final TextEditingController _customQuantityController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _quantities = {};
  final Map<String, TextEditingController> _quantityControllers = {};
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  String? _errorMessage;
  bool _isChecklistExpanded = false;
  bool _showCustomFields = false;
  bool _isManualAmount = false;

  @override
  void initState() {
    super.initState();
    _fetchAllProducts();
    _searchController.addListener(() {
      _filterProducts(_searchController.text);
    });
    _amountController.addListener(() {
      final amountText = _amountController.text;
      if (amountText.isNotEmpty && double.tryParse(amountText) == null) {
        setState(() {
          _errorMessage = 'Please enter a valid sales amount';
        });
      } else {
        setState(() {
          _errorMessage = null;
          _isManualAmount = true;
        });
      }
    });
  }

  Future<void> _fetchAllProducts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('Inventory')
          .get();
      if (!mounted) return;
      setState(() {
        _allProducts = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'category': data['category'] as String? ?? 'Uncategorized',
            'name': data['productName'] as String? ?? 'Unnamed Product',
            'quantity': (data['quantity'] as num?)?.toInt() ?? 0,
            'price': (data['price'] as num?)?.toDouble() ?? 0.0,
            'sellingPrice': (data['sellingPrice'] as num?)?.toDouble() ?? 0.0,
          };
        }).toList();
        _filteredProducts = _allProducts;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error fetching products: $e')));
      }
    }
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((product) {
          final name = (product['name'] as String).toLowerCase();
          final category = (product['category'] as String).toLowerCase();
          final queryLower = query.toLowerCase();
          return name.contains(queryLower) || category.contains(queryLower);
        }).toList();
      }
    });
  }

  void _updateQuantities() {
    setState(() {
      _errorMessage = null;
      _quantityControllers.forEach((itemName, controller) {
        final value = controller.text;
        final newQuantity = int.tryParse(value) ?? 0;
        if (value.isNotEmpty && (newQuantity < 0 || int.tryParse(value) == null)) {
          _errorMessage = 'Please enter a valid non-negative quantity for $itemName';
          return;
        }
        if (newQuantity > 0) {
          _quantities[itemName] = newQuantity;
        } else {
          _quantities.remove(itemName);
        }
      });

      if (!_isManualAmount) {
        double totalAmount = 0.0;
        for (var entry in _quantities.entries) {
          final productName = entry.key;
          final quantity = entry.value;
          final product = _allProducts.firstWhere(
                (p) => p['name'] == productName,
            orElse: () => <String, Object>{'sellingPrice': 0.0},
          );
          final sellingPrice = (product['sellingPrice'] as num?)?.toDouble() ?? 0.0;
          totalAmount += quantity * sellingPrice;
        }
        _amountController.text = totalAmount.toStringAsFixed(2);
      }
    });
  }

  void _addCustomProduct() {
    final customProduct = _customProductController.text;
    final customQtyText = _customQuantityController.text;
    final customQty = int.tryParse(customQtyText) ?? 0;

    if (customProduct.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a product name for custom entry';
      });
      return;
    }
    if (customQtyText.isNotEmpty && (customQty <= 0 || int.tryParse(customQtyText) == null)) {
      setState(() {
        _errorMessage = 'Please enter a valid positive quantity for custom entry';
      });
      return;
    }
    if (customProduct.isNotEmpty && customQty > 0) {
      setState(() {
        _quantities[customProduct] = (_quantities[customProduct] ?? 0) + customQty;
        _customProductController.clear();
        _customQuantityController.clear();
        _errorMessage = null;
        _isManualAmount = false;
        _updateQuantities();
      });
    }
  }

  Future<void> _saveSale() async {
    if (_quantities.isEmpty || _quantities.values.every((qty) => qty == 0)) {
      setState(() {
        _errorMessage = 'Please select products and enter quantities';
      });
      return;
    }

    final amountText = _amountController.text;
    if (amountText.isEmpty || double.tryParse(amountText) == null) {
      setState(() {
        _errorMessage = 'Please enter a valid amount';
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('User not authenticated. Please log in.')));
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const LoginPage()));
      }
      return;
    }

    try {
      final date = DateTime.now();
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('Inventory')
          .get();

      final inventoryMap = <String, Map<String, dynamic>>{};
      for (var doc in inventorySnapshot.docs) {
        final data = doc.data();
        final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
        inventoryMap[data['productName']] = {
          'id': doc.id,
          'quantity': quantity,
          'category': data['category'],
        };
      }

      final batch = FirebaseFirestore.instance.batch();

      for (var entry in _quantities.entries) {
        final productName = entry.key;
        final quantitySold = entry.value;

        if (inventoryMap.containsKey(productName) && quantitySold > 0) {
          final inventoryItem = inventoryMap[productName]!;
          final newQuantity = inventoryItem['quantity'] - quantitySold;
          if (newQuantity < 0) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Insufficient stock for $productName'), backgroundColor: const Color(0xFFEF4444),),
              );
            }
            return;
          }
          final inventoryRef = FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .collection('Inventory')
              .doc(inventoryItem['id']);
          batch.update(inventoryRef, {'quantity': newQuantity});
        }
      }

      await batch.commit();

      final amountInCents = (double.parse(amountText)).toInt();

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('transactions')
          .add({
        'type': 'sale',
        'amount': amountInCents,
        'category': 'Sale',
        'quantities': _quantities,
        'date': Timestamp.fromDate(date),
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sale saved successfully'), backgroundColor: const Color(0xFF10B981),));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error processing sale: $e')));
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _customProductController.dispose();
    _customQuantityController.dispose();
    _searchController.dispose();
    _quantityControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final groupedProducts = _filteredProducts.fold<Map<String, List<Map<String, dynamic>>>>(
      {},
          (map, product) {
        final category = (product['category'] as String).trim().toLowerCase();
        map.putIfAbsent(category, () => []).add(product);
        return map;
      },
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 560),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Sale',
                  style: GoogleFonts.inter(
                    fontSize: mediaQuery.size.width * 0.045,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('dd MMM yyyy').format(DateTime.now()),
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.03,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.03, color: const Color(0xFF6B7280)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF6B7280)),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                isDense: true,
              ),
              style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.035),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Selected (${_quantities.length})',
                    style: GoogleFonts.inter(
                      fontSize: mediaQuery.size.width * 0.035,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF221E22),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isChecklistExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: const Color(0xFF6B7280),
                  ),
                  onPressed: () {
                    setState(() {
                      _isChecklistExpanded = !_isChecklistExpanded;
                    });
                  },
                ),
              ],
            ),
            if (_isChecklistExpanded) ...[
              Container(
                constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.15),
                child: SingleChildScrollView(
                  child: Column(
                    children: _quantities.entries.map((entry) {
                      return Card(
                        elevation: 2,
                        color: const Color(0xFFFFFFFF),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: GoogleFonts.inter(
                                      fontSize: mediaQuery.size.width * 0.035,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF221E22),
                                    ),
                                  ),
                                  Text(
                                    'Qty: ${entry.value}',
                                    style: GoogleFonts.inter(
                                      fontSize: mediaQuery.size.width * 0.03,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: Color(0xFFEF4444)),
                                onPressed: () {
                                  setState(() {
                                    _quantities.remove(entry.key);
                                    _quantityControllers[entry.key]?.text = '0';
                                    _updateQuantities();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showCustomFields = !_showCustomFields;
                });
              },
              child: Text(
                '+ Add Custom Product',
                style: GoogleFonts.inter(
                  fontSize: mediaQuery.size.width * 0.03,
                  color: const Color(0xFF1E3A8A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_showCustomFields) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customProductController,
                      decoration: InputDecoration(
                        labelText: 'Product',
                        labelStyle: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.03, color: const Color(0xFF6B7280)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        isDense: true,
                      ),
                      style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.035),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _customQuantityController,
                      decoration: InputDecoration(
                        labelText: 'Qty',
                        labelStyle: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.03, color: const Color(0xFF6B7280)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        isDense: true,
                      ),
                      style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.035),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, size: 20, color: Color(0xFF10B981)),
                    onPressed: _addCustomProduct,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: groupedProducts.isEmpty
                  ? Center(
                child: Text(
                  'No products found',
                  style: GoogleFonts.inter(
                    fontSize: mediaQuery.size.width * 0.04,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              )
                  : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: groupedProducts.entries.map((entry) {
                    final category = entry.key;
                    final products = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category[0].toUpperCase() + category.substring(1),
                          style: GoogleFonts.inter(
                            fontSize: mediaQuery.size.width * 0.04,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(height: mediaQuery.size.height * 0.01),
                        ...products.map((product) {
                          final itemName = product['name'] as String;
                          _quantityControllers.putIfAbsent(
                              itemName,
                                  () => TextEditingController(
                                  text: (_quantities[itemName] ?? 0).toString()));
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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
                                          itemName,
                                          style: GoogleFonts.inter(
                                            fontSize: mediaQuery.size.width * 0.035,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF221E22),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Stock: ${product['quantity']}',
                                          style: GoogleFonts.inter(
                                            fontSize: mediaQuery.size.width * 0.03,
                                            color: const Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded,
                                            color: Color(0xFFEF4444), size: 20),
                                        onPressed: () {
                                          final current = int.tryParse(_quantityControllers[itemName]!.text) ?? 0;
                                          if (current > 0) {
                                            _quantityControllers[itemName]!.text = (current - 1).toString();
                                            _isManualAmount = false;
                                            _updateQuantities();
                                          }
                                        },
                                      ),
                                      SizedBox(
                                        width: 36,
                                        child: TextField(
                                          controller: _quantityControllers[itemName],
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.035),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) {
                                            _isManualAmount = false;
                                            _updateQuantities();
                                          },
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline_rounded,
                                            color: Color(0xFF10B981), size: 20),
                                        onPressed: () {
                                          final current = int.tryParse(_quantityControllers[itemName]!.text) ?? 0;
                                          _quantityControllers[itemName]!.text = (current + 1).toString();
                                          _isManualAmount = false;
                                          _updateQuantities();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        SizedBox(height: mediaQuery.size.height * 0.02),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                labelStyle: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.03, color: const Color(0xFF6B7280)),
                prefixText: '\रु ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                isDense: true,
              ),
              style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.035),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: GoogleFonts.inter(
                  fontSize: mediaQuery.size.width * 0.03,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSwitchToExpense();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Expense',
                      style: GoogleFonts.inter(
                        fontSize: mediaQuery.size.width * 0.035,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Save',
                      style: GoogleFonts.inter(
                        fontSize: mediaQuery.size.width * 0.035,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
}
class AddExpenseDialog extends StatefulWidget {
  final VoidCallback onSwitchToSale;

  const AddExpenseDialog({super.key, required this.onSwitchToSale});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _amountController = TextEditingController(text: '0');
  final List<Map<String, TextEditingController>> _expenseFields = [
    {
      'description': TextEditingController(),
      'quantity': TextEditingController(),
    },
  ];
  bool _showAddMoreFields = false;
  String? _errorMessage; // For error message display

  void _addExpenseField() {
    setState(() {
      _expenseFields.add({
        'description': TextEditingController(),
        'quantity': TextEditingController(),
      });
    });
  }

  Future<void> _saveExpense() async {
    setState(() {
      _errorMessage = null; // Reset error message
    });

    final expenses = <String, int>{};
    for (var field in _expenseFields) {
      final description = field['description']!.text.trim();
      final quantityText = field['quantity']!.text.trim();
      if (description.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter a description for all expense fields';
        });
        return;
      }
      if (quantityText.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter a quantity for all expense fields';
        });
        return;
      }
      final quantity = int.tryParse(quantityText);
      if (quantity == null || quantity <= 0) {
        setState(() {
          _errorMessage = 'Please enter a valid positive quantity';
        });
        return;
      }
      expenses[description] = quantity;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an amount';
      });
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid positive amount';
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'User not authenticated. Please log in.';
      });
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
      }
      return;
    }

    try {
      final date = DateTime.now();
      final description = expenses.entries.map((e) => '${e.key} (${e.value})').join(', ');
      final amountInCents = (double.parse(amountText)).toInt();

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('transactions')
          .add({
        'type': 'expense',
        'amount': amountInCents,
        'description': description,
        'date': Timestamp.fromDate(date),
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense saved successfully'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving expense: $e';
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    for (var field in _expenseFields) {
      field['description']!.dispose();
      field['quantity']!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 560),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Expense',
                    style: GoogleFonts.inter(
                      fontSize: mediaQuery.size.width * 0.045,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd MMM yyyy').format(DateTime.now()),
                style: GoogleFonts.inter(
                  fontSize: mediaQuery.size.width * 0.03,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 12),
              ..._expenseFields.asMap().entries.map((entry) {
                final index = entry.key;
                final field = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: mediaQuery.size.height * 0.01),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: field['description'],
                          decoration: InputDecoration(
                            labelText: 'Description',
                            labelStyle: GoogleFonts.inter(
                                fontSize: mediaQuery.size.width * 0.03, color: const Color(0xFF6B7280)),
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
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            isDense: true,
                          ),
                          style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.035),
                        ),
                      ),
                      SizedBox(width: mediaQuery.size.width * 0.02),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: field['quantity'],
                          decoration: InputDecoration(
                            labelText: 'Qty',
                            labelStyle: GoogleFonts.inter(
                                fontSize: mediaQuery.size.width * 0.03, color: const Color(0xFF6B7280)),
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
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            isDense: true,
                          ),
                          style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.035),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      if (index > 0)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_rounded, color: Color(0xFFEF4444), size: 18),
                          onPressed: () {
                            setState(() {
                              _expenseFields.removeAt(index);
                            });
                          },
                        ),
                    ],
                  ),
                );
              }),
              SizedBox(height: mediaQuery.size.height * 0.01),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showAddMoreFields = !_showAddMoreFields;
                    if (_showAddMoreFields) {
                      _addExpenseField();
                    }
                  });
                },
                child: Text(
                  '+ Add More',
                  style: GoogleFonts.inter(
                    fontSize: mediaQuery.size.width * 0.03,
                    color: const Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: mediaQuery.size.height * 0.01),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Debit amount',
                  labelStyle: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.03, color: const Color(0xFF6B7280)),
                  prefixText: '\रु ',
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  isDense: true,
                ),
                style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.035),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onTap: () {
                  if (_amountController.text == '1.00') {
                    _amountController.clear();
                  }
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(
                    fontSize: mediaQuery.size.width * 0.03,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ],
              SizedBox(height: mediaQuery.size.height * 0.01),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onSwitchToSale();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Sale',
                        style: GoogleFonts.inter(
                          fontSize: mediaQuery.size.width * 0.035,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Save',
                        style: GoogleFonts.inter(
                          fontSize: mediaQuery.size.width * 0.035,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}