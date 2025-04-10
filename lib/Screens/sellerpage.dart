import 'package:arthikapp/Screens/Scanpage.dart';
import 'package:arthikapp/Screens/analyticspage.dart';
import 'package:arthikapp/Screens/inventorypage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'Sellerinfo.dart';
import 'dashboard.dart';
import 'transaction.dart';

class SellerPage extends StatefulWidget {
  const SellerPage({super.key});

  @override
  State<SellerPage> createState() => _SellerPageState();
}

class _SellerPageState extends State<SellerPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  String _searchQuery = '';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E3A8A),
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showAddSupplierDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(16),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add New Supplier',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E3A8A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _nameController,
                    'Supplier Name',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _mobileController,
                    'Mobile Number',
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final digitsOnly = RegExp(r'^\d+$');
                      if (!digitsOnly.hasMatch(value)) {
                        return 'Only digits allowed';
                      }
                      if (value.length != 10) {
                        return 'Must be 10 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _emailController,
                    'Email (optional)',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return null; // Email is optional
                      }
                      final emailRegex = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                      if (!emailRegex.hasMatch(value)) {
                        return 'Invalid email format';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _addressController,
                    'Address',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length < 5) {
                        return 'Address must be at least 5 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Created At',
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
                      prefixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF6B7280)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    controller: TextEditingController(
                      text: "${_selectedDate.day} ${_selectedDate.month == 1 ? 'Jan' : _selectedDate.month == 2 ? 'Feb' : _selectedDate.month == 3 ? 'Mar' : _selectedDate.month == 4 ? 'Apr' : _selectedDate.month == 5 ? 'May' : _selectedDate.month == 6 ? 'Jun' : _selectedDate.month == 7 ? 'Jul' : _selectedDate.month == 8 ? 'Aug' : _selectedDate.month == 9 ? 'Sep' : _selectedDate.month == 10 ? 'Oct' : _selectedDate.month == 11 ? 'Nov' : 'Dec'} ${_selectedDate.year}",
                    ),
                    onTap: () => _selectDate(context),
                    style: GoogleFonts.inter(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('Users')
                                  .doc(user.uid)
                                  .collection('Suppliers')
                                  .add({
                                'name': _nameController.text,
                                'mobile': _mobileController.text,
                                'email': _emailController.text,
                                'address': _addressController.text,
                                'createdAt': Timestamp.fromDate(_selectedDate),
                              });
                              _nameController.clear();
                              _mobileController.clear();
                              _emailController.clear();
                              _addressController.clear();
                              Navigator.pop(context);
                              _showSnackBar('Supplier added successfully');
                            } catch (e) {
                              _showSnackBar('Error adding supplier: $e');
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Save',
                        style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

  Widget _buildTextField(
      TextEditingController controller,
      String label, {
        TextInputType? keyboardType,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
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
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 16),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
    );
  }

  void _showDeleteConfirmationDialog(String supplierId, String supplierName) {
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
          'Are you sure you want to delete $supplierName?',
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
              _deleteSupplier(supplierId);
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

  void _deleteSupplier(String supplierId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('Suppliers')
          .doc(supplierId)
          .delete();
      _showSnackBar('Supplier deleted successfully');
    }
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return;
    }
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      debugPrint('Could not launch $phoneUri');
    }
  }


  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Color(0xFF10B981),));
  }

  double _parseAmount(dynamic value) {
    if (value is double) {
      return value;
    } else if (value is int) {
      // Handle legacy data stored as cents
      return value / 100.0;
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Stream<Map<String, double>> _calculateTotals() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value({'totalPurchase': 0.0, 'totalPayment': 0.0});
    }

    return FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('Orders')
        .snapshots()
        .map((snapshot) {
      double totalPurchase = 0.0;
      double totalPayment = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final purchaseAmount = _parseAmount(data['purchaseAmount']);
        final paymentAmount = _parseAmount(data['paymentAmount']);
        totalPurchase += purchaseAmount;
        totalPayment += paymentAmount;
      }

      return {
        'totalPurchase': totalPurchase,
        'totalPayment': totalPayment,
      };
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
      case 4:
        Navigator.pushReplacement(context, _createRoute(const AnalyticsPage()));
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
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final mediaQuery = MediaQuery.of(context);

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
                  padding: EdgeInsets.all(mediaQuery.size.width * 0.06),
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
                        'Suppliers',
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
                  child: StreamBuilder<Map<String, double>>(
                    stream: _calculateTotals(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          'Error calculating totals',
                          style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04, color: const Color(0xFFEF4444)),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final totals = snapshot.data!;
                      final totalPurchase = totals['totalPurchase'] ?? 0.0;
                      final totalPayment = totals['totalPayment'] ?? 0.0;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatCard(
                            'Total Purchase',
                            '\रु ${totalPurchase.toStringAsFixed(2)}',
                            const Color(0xFF10B981),
                            mediaQuery,
                          ),
                          _buildStatCard(
                            'Total Payment',
                            '\रु ${totalPayment.toStringAsFixed(2)}',
                            const Color(0xFFEF4444),
                            mediaQuery,
                          ),
                        ],
                      );
                    },
                  ),
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
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: mediaQuery.size.width * 0.05,
                            vertical: mediaQuery.size.height * 0.02,
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search suppliers...',
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            style: GoogleFonts.inter(fontSize: 16),
                          ),
                        ),
                        Expanded(
                          child: user == null
                              ? Center(
                            child: Text(
                              'Please sign in',
                              style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04, color: const Color(0xFF6B7280)),
                            ),
                          )
                              : StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('Users')
                                .doc(user.uid)
                                .collection('Suppliers')
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Error loading suppliers',
                                    style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04, color: const Color(0xFFEF4444)),
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              final suppliers = snapshot.data!.docs.where((doc) {
                                final supplierData = doc.data() as Map<String, dynamic>;
                                final name = supplierData['name']?.toString().toLowerCase() ?? '';
                                return name.contains(_searchQuery);
                              }).toList();

                              if (suppliers.isEmpty) {
                                return Center(
                                  child: Text(
                                    _searchQuery.isEmpty ? 'No suppliers found' : 'No matching suppliers',
                                    style: GoogleFonts.inter(fontSize: mediaQuery.size.width * 0.04, color: const Color(0xFF6B7280)),
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.05),
                                itemCount: suppliers.length,
                                itemBuilder: (context, index) {
                                  final supplier = suppliers[index];
                                  final supplierData = supplier.data() as Map<String, dynamic>;

                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    color: const Color(0xFFFFFFFF),
                                    margin: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.005),
                                    child:
                                    ListTile(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          _createRoute(
                                            SellerDetailPage(
                                              sellerName: supplierData['name'],
                                              totalAmount: '0',
                                              supplierData: {
                                                ...supplierData,
                                                'id': supplier.id,
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: mediaQuery.size.width * 0.04,
                                        vertical: mediaQuery.size.height * 0.002,
                                      ),
                                      title: Text(
                                        supplierData['name'],
                                        style: GoogleFonts.inter(
                                          fontSize: mediaQuery.size.width * 0.035,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF221E22),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        supplierData['mobile'],
                                        style: GoogleFonts.inter(
                                          fontSize: mediaQuery.size.width * 0.03,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.phone_rounded,
                                              color: supplierData['mobile']?.isNotEmpty ?? false
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF10B981).withOpacity(0.4),
                                              size: 20,
                                            ),
                                            onPressed: supplierData['mobile']?.isNotEmpty ?? false
                                                ? () => _makePhoneCall(supplierData['mobile'])
                                                : null,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 20),
                                            onPressed: () => _showDeleteConfirmationDialog(supplier.id, supplierData['name']),
                                          ),
                                        ],
                                      ),
                                    ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSupplierDialog,
        backgroundColor: const Color(0xFFF97316),
        elevation: 6,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
      // bottomNavigationBar: BottomNavigationBar(
      //   type: BottomNavigationBarType.fixed,
      //   selectedItemColor: const Color(0xFF1E3A8A),
      //   unselectedItemColor: const Color(0xFF6B7280),
      //   currentIndex: 0,
      //   onTap: _onItemTapped,
      //   items: const [
      //     BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
      //     BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Inventory'),
      //     BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner_rounded), label: 'Scanner'),
      //     BottomNavigationBarItem(icon: Icon(Icons.receipt_rounded), label: 'Transaction'),
      //     BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Analytics'),
      //   ],
      // ),
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
                fontSize: mediaQuery.size.width * 0.03,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.01),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.035,
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