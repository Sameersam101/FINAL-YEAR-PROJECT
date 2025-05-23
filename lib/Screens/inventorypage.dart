import 'package:arthikapp/Screens/Scanpage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard.dart';
import 'transaction.dart';
import 'sellerpage.dart';
import 'analyticspage.dart';
import 'login_page.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  int _selectedIndex = 1;
  Timestamp? _lastOrderChecked;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, _createRoute(const DashboardPage()));
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacement(context, _createRoute(const ScanPage()));
        break;
      case 3:
        Navigator.push(context, _createRoute(const Transactionpage()));
        break;
      case 4:
        Navigator.push(context, _createRoute(const Analyticspage()));
        break;
    }
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
  void initState() {
    super.initState();
    _loadLastOrderChecked();
  }

  Future<void> _loadLastOrderChecked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      return;
    }
    try {
      print('Fetching inventory_settings for user: ${user.uid}');
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('Metadata')
          .doc('inventory_settings')
          .get();
      print('Document exists: ${doc.exists}, Data: ${doc.data()}');
      if (doc.exists && doc.data() != null && mounted) {
        setState(() {
          _lastOrderChecked = doc.data()!['lastOrderChecked'] as Timestamp?;
        });
      }
      await _checkForNewOrders();
    } catch (e) {
      print('Error in _loadLastOrderChecked: $e');
      _showSnackBar('Error loading inventory settings: $e');
    }
  }

  Future<void> _checkForNewOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      return;
    }
    try {
      QuerySnapshot ordersSnapshot;
      if (_lastOrderChecked != null) {
        ordersSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .collection('Orders')
            .where('createdAt', isGreaterThan: _lastOrderChecked)
            .orderBy('createdAt')
            .get();
      } else {
        ordersSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .collection('Orders')
            .orderBy('createdAt')
            .get();
      }

      print('New orders found: ${ordersSnapshot.docs.length}');
      if (ordersSnapshot.docs.isNotEmpty && mounted) {
        _showAddToInventoryPopup(ordersSnapshot.docs);
        final latestOrder = ordersSnapshot.docs.last.data() as Map<
            String,
            dynamic>;
        final latestTimestamp = latestOrder['createdAt'] as Timestamp;
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .collection('Metadata')
            .doc('inventory_settings')
            .set(
            {'lastOrderChecked': latestTimestamp}, SetOptions(merge: true));
        if (mounted) {
          setState(() {
            _lastOrderChecked = latestTimestamp;
          });
        }
      }
    } catch (e) {
      print('Error in _checkForNewOrders: $e');
      _showSnackBar('Error checking for new orders: $e');
    }
  }

  @override
  void dispose(){
    super.dispose();
  }

  void _showAddToInventoryPopup(List<QueryDocumentSnapshot> orders) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Add Products to Inventory',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A)),
        ),
        content: Text(
          'Do you want to add products you bought from sellers to your inventory?',
          style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFFEF4444)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _addAllToInventory(orders);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Add All',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
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

  Future<void> _addAllToInventory(List<QueryDocumentSnapshot> orders) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('User not logged in');
      return;
    }

    try {
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('Inventory')
          .get();

      final existingProducts = inventorySnapshot.docs.map((doc) {
        final data = doc.data();
        return '${data['productName']}-${data['category']}';
      }).toSet();

      final batch = FirebaseFirestore.instance.batch();
      int addedCount = 0;

      for (var order in orders) {
        final orderData = order.data() as Map<String, dynamic>;
        final productKey = '${orderData['itemName']}-${orderData['category']}';

        if (!existingProducts.contains(productKey)) {
          final productAmount = orderData['productAmount'] is String
              ? double.tryParse(orderData['productAmount']) ?? 0.0
              : (orderData['productAmount'] as num?)?.toDouble() ?? 0.0;
          final sellingPrice = orderData['sellingPrice'] is String
              ? double.tryParse(orderData['sellingPrice']) ?? 0.0
              : (orderData['sellingPrice'] as num?)?.toDouble() ?? 0.0;
          final quantity = (orderData['quantity'] as num?)?.toInt() ?? 0;
          final date = orderData['date'] != null
              ? Timestamp.fromDate(DateTime.parse(orderData['date']))
              : Timestamp.now();

          final inventoryRef = FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .collection('Inventory')
              .doc();
          batch.set(inventoryRef, {
            'type': 'in',
            'productName': orderData['itemName']?.toString() ?? 'Unnamed Product',
            'category': orderData['category']?.toString().toLowerCase() ?? 'uncategorized',
            'quantity': quantity,
            'price': productAmount,
            'sellingPrice': sellingPrice,
            'date': date,
            'createdAt': FieldValue.serverTimestamp(),
            'userId': user.uid,
          });
          addedCount++;
          existingProducts.add(productKey);
        }
      }

      if (addedCount > 0) {
        await batch.commit();
        if (mounted) {
          _showSnackBar('$addedCount product(s) added to inventory');
        }
      } else {
        if (mounted) {
          _showSnackBar('No new products to add');
        }
      }
    } catch (e) {
      print('Error in _addAllToInventory: $e');
      _showSnackBar('Error adding products to inventory: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          _createRoute(const DashboardPage()),
                        ),
                        child: Container(
                          padding: EdgeInsets.all(mediaQuery.size.width * 0.02),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: mediaQuery.size.width * 0.06,
                          ),
                        ),
                      ),
                      SizedBox(width: mediaQuery.size.width * 0.03),
                      Text(
                        'Inventory',
                        style: GoogleFonts.inter(
                          fontSize: mediaQuery.size.width * 0.06,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.05),
                  child: const StatsSection(),
                ),
                SizedBox(height: mediaQuery.size.height * 0.02),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(mediaQuery.size.width * 0.08),
                        topRight: Radius.circular(mediaQuery.size.width * 0.08),
                      ),
                    ),
                    child: CustomScrollView(
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _ActionSectionHeaderDelegate(
                            onProductIn: () => _showDialog(context, 'in'),
                            onProductOut: () => _showDialog(context, 'out'),
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: ProductListSection(),
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

  void _showDialog(BuildContext context, String type) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => ProductTransactionDialog(initialType: type),
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

class _ActionSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onProductIn;
  final VoidCallback onProductOut;

  _ActionSectionHeaderDelegate({required this.onProductIn, required this.onProductOut});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final mediaQuery = MediaQuery.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mediaQuery.size.width * 0.08),
          topRight: Radius.circular(mediaQuery.size.width * 0.08),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: mediaQuery.size.width * 0.05,
        vertical: mediaQuery.size.height * 0.02,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            label: '+ Product In',
            color: const Color(0xFF10B981),
            onTap: onProductIn,
          ),
          SizedBox(width: mediaQuery.size.width * 0.04),
          _ActionButton(
            label: '- Product Out',
            color: const Color(0xFFEF4444),
            onTap: onProductOut,
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 80.0;

  @override
  double get minExtent => 80.0;

  @override
  bool shouldRebuild(covariant _ActionSectionHeaderDelegate oldDelegate) {
    return onProductIn != oldDelegate.onProductIn || onProductOut != oldDelegate.onProductOut;
  }
}

class StatsSection extends StatelessWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final mediaQuery = MediaQuery.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUserId)
          .collection('transactions')
          .snapshots(),
      builder: (context, transactionSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(currentUserId)
              .collection('Inventory')
              .snapshots(),
          builder: (context, inventorySnapshot) {
            if (transactionSnapshot.connectionState == ConnectionState.waiting ||
                inventorySnapshot.connectionState == ConnectionState.waiting) {
              return _buildStatsCards('Loading...', 'Loading...', 'Loading...', mediaQuery);
            }
            if (transactionSnapshot.hasError || inventorySnapshot.hasError) {
              return _buildStatsCards('Error', 'Error', 'Error', mediaQuery);
            }

            final today = DateTime.now();
            final todaySales = transactionSnapshot.data!.docs
                .where((doc) {
              final date = (doc['date'] as Timestamp).toDate();
              return doc['type'] == 'sale' &&
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
            })
                .fold<double>(0, (sum, doc) => sum + ((doc['amount'] as int? ?? 0)));

            final totalProducts =
            inventorySnapshot.data!.docs.fold<int>(0, (sum, doc) => sum + (doc['quantity'] as int? ?? 0));
            final outOfStock = inventorySnapshot.data!.docs.where((doc) => (doc['quantity'] as int? ?? 0) == 0).length;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard('Today\'s Sale', '\रु ${todaySales.toStringAsFixed(2)}', const Color(0xFF10B981), mediaQuery),
                _buildStatCard('Total Stock', '$totalProducts', const Color(0xFF10B981), mediaQuery),
                _buildStatCard('Out of Stock', '$outOfStock', const Color(0xFFEF4444), mediaQuery),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatsCards(String saleValue, String productValue, String stockValue, MediaQueryData mediaQuery) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatCard('Today\'s Sale', saleValue, const Color(0xFF10B981), mediaQuery),
        _buildStatCard('Total Stock', productValue, const Color(0xFF10B981), mediaQuery),
        _buildStatCard('Out of Stock', stockValue, const Color(0xFFEF4444), mediaQuery),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, MediaQueryData mediaQuery) {
    return Expanded(
      child: Container(
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
              label,
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.030,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.01),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.03,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductTransactionDialog extends StatefulWidget {
  final String initialType;

  const ProductTransactionDialog({super.key, required this.initialType});

  @override
  State<ProductTransactionDialog> createState() => _ProductTransactionDialogState();
}

class _ProductTransactionDialogState extends State<ProductTransactionDialog> {
  late final String _type = widget.initialType;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _products = [];
  final Map<String, int> _updatedQuantities = {};

  @override
  void initState() {
    super.initState();
    if (_type == 'out') _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        _showSnackBar('User not logged in');
        return;
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUserId)
          .collection('Inventory')
          .get();
      if (mounted) {
        setState(() {
          _products = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['productName'] as String? ?? 'Unnamed Product',
              'category': data['category'] as String? ?? 'Uncategorized',
              'quantity': data['quantity'] is int ? data['quantity'] as int : 0,
              'price': data['price'] is double ? data['price'] as double : 0.0,
            };
          }).toList();
          for (var product in _products) {
            _updatedQuantities[product['id']] = product['quantity'];
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error fetching products: $e');
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2025),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _saveTransaction() async {
    if (_type == 'out') {
      if (_products.isEmpty) {
        _showSnackBar('No products available to remove');
        return;
      }
      try {
        final batch = FirebaseFirestore.instance.batch();
        final userId = FirebaseAuth.instance.currentUser!.uid;
        bool hasChanges = false;

        for (var product in _products) {
          final currentQty = _updatedQuantities[product['id']] ?? product['quantity'];
          if (currentQty != product['quantity']) {
            if (currentQty < 0) {
              _showSnackBar('Insufficient quantity for ${product['name']}');
              return;
            }
            final ref = FirebaseFirestore.instance
                .collection('Users')
                .doc(userId)
                .collection('Inventory')
                .doc(product['id']);
            batch.update(ref, {'quantity': currentQty});
            hasChanges = true;
          }
        }

        if (hasChanges) {
          await batch.commit();
          _showSuccessDialog('Products Stock Update Successfully');
        } else {
          _showSnackBar('No changes to save');
        }
      } catch (e) {
        _showSnackBar('Error saving transaction: $e');
      }
    } else {
      final quantity = int.parse(_quantityController.text);
      final price = double.parse(_priceController.text);
      final sellingPrice = double.parse(_sellingPriceController.text);
      try {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('Inventory')
            .add({
          'type': _type,
          'productName': _nameController.text.trim(),
          'category': _categoryController.text.trim().toLowerCase(),
          'quantity': quantity,
          'price': price,
          'sellingPrice': sellingPrice,
          'date': Timestamp.fromDate(_selectedDate),
          'createdAt': FieldValue.serverTimestamp(),
          'userId': FirebaseAuth.instance.currentUser!.uid,
        });
        _showSuccessDialog('Product Added Successfully');
      } catch (e) {
        _showSnackBar('Error saving product: $e');
      }
    }
  }

  bool _validateFields() {
    if (_nameController.text.isEmpty ||
        _categoryController.text.isEmpty ||
        _quantityController.text.isEmpty ||
        _priceController.text.isEmpty) {
      _showSnackBar('Please fill all fields');
      return false;
    }
    if (int.tryParse(_quantityController.text) == null || double.tryParse(_priceController.text) == null) {
      _showSnackBar('Invalid quantity or price');
      return false;
    }
    return true;
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showSuccessDialog(String message) {
    if (mounted) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Success',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
          ),
          content: Text(message, style: GoogleFonts.inter(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(
                'OK',
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E3A8A)),
              ),
            ),
          ],
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

  void _showDeleteConfirmationDialog(String productId, String productName) {
    if (mounted) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Confirm Deletion',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A)),
          ),
          content: Text(
            'Are you sure you want to delete $productName?',
            style: GoogleFonts.inter(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteProduct(productId);
              },
              child: Text(
                'Delete',
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFFEF4444)),
              ),
            ),
          ],
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

  Future<void> _deleteProduct(String productId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('Inventory')
          .doc(productId)
          .delete();
      if (mounted) {
        setState(() {
          _products.removeWhere((p) => p['id'] == productId);
          _updatedQuantities.remove(productId);
        });
        _showSnackBar('Product deleted successfully');
      }
    } catch (e) {
      String errorMessage = 'Error deleting product: $e';
      if (e is FirebaseException) {
        switch (e.code) {
          case 'permission-denied':
            errorMessage = 'You do not have permission to delete this product.';
            break;
          case 'not-found':
            errorMessage = 'Product not found. It may have been deleted already.';
            break;
          default:
            errorMessage = 'Failed to delete product. Please try again.';
        }
      }
      _showSnackBar(errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(mediaQuery.size.width * 0.05),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, spreadRadius: 5),
          ],
        ),
        child: _type == 'in' ? _buildProductIn() : _buildProductOut(),
      ),
    );
  }

  // In the _ProductTransactionDialogState class, replace the _buildProductIn() method with this:

  Widget _buildProductIn() {
    return Form(
      key: _formKey, // Add this line (you'll need to declare _formKey in the state class)
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Product',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A8A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Product Name',
              labelStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              errorStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Product name is required';
              }
              return null;
            },
            style: GoogleFonts.inter(fontSize: 16),
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _categoryController,
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              errorStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Category is required';
              }
              return null;
            },
            style: GoogleFonts.inter(fontSize: 16),
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    labelStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    errorStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Quantity is required';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                  style: GoogleFonts.inter(fontSize: 16),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: 'Price',
                    prefixText: '\रु ',
                    labelStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    errorStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Price is required';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                  style: GoogleFonts.inter(fontSize: 16),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _sellingPriceController,
            decoration: InputDecoration(
              labelText: 'Selling Price',
              prefixText: '\रु ',
              labelStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              errorStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Selling price is required';
              }
              final numValue = double.tryParse(value);
              if (numValue == null || numValue <= 0) {
                return 'Enter a valid number';
              }
              return null;
            },
            style: GoogleFonts.inter(fontSize: 16),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: (value) {
              if (value.isNotEmpty && !value.contains('.')) {
                _sellingPriceController.text = '$value.00';
                _sellingPriceController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _sellingPriceController.text.length - 3),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFF1E3A8A), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: GoogleFonts.inter(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _saveTransaction();
              } else {
                _showSnackBar('Please fill all required fields correctly');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 0),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductOut() {
    final mediaQuery = MediaQuery.of(context);
    if (_products.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remove Product',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A8A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No products available',
              style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF6B7280)),
            ),
          ),
        ],
      );
    }

    final groupedProducts = _products.fold<Map<String, List<Map<String, dynamic>>>>(
      {},
          (map, product) {
        final category = (product['category'] as String).trim().toLowerCase();
        map.putIfAbsent(category, () => []).add(product);
        return map;
      },
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Remove Product',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A8A),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 1),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.4),
          child: SingleChildScrollView(
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
                        fontSize: mediaQuery.size.width * 0.03,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(height: mediaQuery.size.height * 0.01),
                    ...products.map((product) => Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      color: const Color(0xFFFFFFFF),
                      margin: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.005),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: mediaQuery.size.height * 0.01,
                          horizontal: mediaQuery.size.width * 0.02,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name'],
                                    style: GoogleFonts.inter(
                                      fontSize: mediaQuery.size.width * 0.030,
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
                              children: [
                                SizedBox(width: mediaQuery.size.width * 0.001),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded,
                                      color: Color(0xFFEF4444), size: 20),
                                  onPressed: () {
                                    setState(() {
                                      final currentQty = _updatedQuantities[product['id']] ?? product['quantity'];
                                      if (currentQty > 0) {
                                        _updatedQuantities[product['id']] = currentQty - 1;
                                      }
                                    });
                                  },
                                ),
                                Text(
                                  '${_updatedQuantities[product['id']] ?? product['quantity']}',
                                  style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.030),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline_rounded,
                                      color: Color(0xFF10B981), size: 20),
                                  onPressed: () {
                                    setState(() {
                                      final currentQty = _updatedQuantities[product['id']] ?? product['quantity'];
                                      _updatedQuantities[product['id']] = currentQty + 1;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 20),
                                  onPressed: () => _showDeleteConfirmationDialog(product['id'], product['name']),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
                    SizedBox(height: mediaQuery.size.height * 0.02),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _saveTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 0),
          ),
          child: Text(
            'Save',
            style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class ProductListSection extends StatelessWidget {
  const ProductListSection({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Product List',
                style: GoogleFonts.inter(
                  fontSize: mediaQuery.size.width * 0.045,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF221E22),
                ),
              ),
            ],
          ),
          SizedBox(height: mediaQuery.size.height * 0.015),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Users')
                .doc(currentUserId)
                .collection('Inventory')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  'Error: ${snapshot.error}',
                  style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text(
                  'No products available',
                  style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04, color: const Color(0xFF6B7280)),
                );
              }

              final groupedProducts = snapshot.data!.docs.fold<Map<String, List<Map<String, dynamic>>>>(
                {},
                    (map, doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final category = (data['category'] as String? ?? 'Uncategorized').trim().toLowerCase();
                  map.putIfAbsent(category, () => []).add({
                    'id': doc.id,
                    'name': data['productName'] as String? ?? 'Unnamed Product',
                    'quantity': data['quantity'] is int ? data['quantity'] as int : 0,
                    'price': data['price'] is double ? data['price'] as double : 0.0,
                    'sellingPrice': data['sellingPrice'] is double ? data['sellingPrice'] as double : 0.0,
                  });
                  return map;
                },
              );

              return Column(
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
                      ...products.map((product) => Card(
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
                                      product['name'],
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\रु ${product['sellingPrice'].toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                      fontSize: mediaQuery.size.width * 0.035,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
                      SizedBox(height: mediaQuery.size.height * 0.02),
                    ],
                  );
                }).toList(),
              );
            },
          ),
          SizedBox(height: mediaQuery.size.height * 0.02),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.015),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: mediaQuery.size.width * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}