import 'package:arthikapp/Screens/Scanpage.dart';
import 'package:arthikapp/Screens/analyticspage.dart';
import 'package:arthikapp/Screens/inventorypage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:arthikapp/Screens/dashboard.dart';
import 'package:arthikapp/Screens/transaction.dart';

class SellerDetailPage extends StatefulWidget {
  final String sellerName;
  final String totalAmount;
  final Map<String, dynamic> supplierData;

  const SellerDetailPage({
    super.key,
    required this.sellerName,
    required this.totalAmount,
    required this.supplierData,
  });

  @override
  State<SellerDetailPage> createState() => _SellerDetailPageState();
}

class _SellerDetailPageState extends State<SellerDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _productAmountController = TextEditingController();
  final TextEditingController _paymentAmountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  late DateTime _selectedDate;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _productAmountController.dispose();
    _paymentAmountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DashboardPage()));
        break;
      case 1:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => InventoryPage()));
        break;
      case 2:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ScanPage()));
        break;
      case 3:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Transactionpage()));
        break;
      case 4:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AnalyticsPage()));
        break;
    }
  }

  double _parseAmount(dynamic value) {
    if (value is double) {
      return value;
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    } else if (value is int) {
      // Handle legacy data stored as cents
      return value / 100.0;
    }
    return 0.0;
  }

  Future<void> _downloadAsPDF(BuildContext context, List<QueryDocumentSnapshot> transactions) async {
    try {
      final pdf = pw.Document();

      double totalDue = 0.0;
      for (var order in transactions) {
        final orderData = order.data() as Map<String, dynamic>;
        final purchaseAmount = _parseAmount(orderData['purchaseAmount']);
        final paymentAmount = _parseAmount(orderData['paymentAmount']);
        totalDue += (purchaseAmount - paymentAmount);
      }

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Seller Details',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Name: ${widget.supplierData['name']}',
                style: const pw.TextStyle(fontSize: 18),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Mobile: ${widget.supplierData['mobile']}',
                style: const pw.TextStyle(fontSize: 18),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Email: ${widget.supplierData['email'] ?? 'Not provided'}',
                style: const pw.TextStyle(fontSize: 18),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Address: ${widget.supplierData['address']}',
                style: const pw.TextStyle(fontSize: 18),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Total Amount: \Rs ${totalDue.toStringAsFixed(2)}',
                style: const pw.TextStyle(fontSize: 18),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Product List for ${widget.sellerName}',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              transactions.isNotEmpty
                  ? pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FixedColumnWidth(100),
                  1: const pw.FixedColumnWidth(80),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(80),
                  4: const pw.FixedColumnWidth(80),
                  5: const pw.FixedColumnWidth(80),
                  6: const pw.FixedColumnWidth(80),
                  7: const pw.FixedColumnWidth(80),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Quantity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Product Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Selling Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Purchase', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Payment', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  ...transactions.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final purchaseAmount = _parseAmount(data['purchaseAmount']);
                    final paymentAmount = _parseAmount(data['paymentAmount']);
                    final productAmount = _parseAmount(data['productAmount']);
                    final sellingPrice = _parseAmount(data['sellingPrice']);
                    return pw.TableRow(
                      children: [
                        pw.Text(data['itemName'] ?? ''),
                        pw.Text(data['date'] ?? ''),
                        pw.Text(data['quantity']?.toString() ?? '0'),
                        pw.Text('\Rs ${productAmount.toStringAsFixed(2)}'),
                        pw.Text('\Rs ${sellingPrice.toStringAsFixed(2)}'),
                        pw.Text('\Rs ${purchaseAmount.toStringAsFixed(2)}'),
                        pw.Text('\Rs ${paymentAmount.toStringAsFixed(2)}'),
                        pw.Text(data['status'] ?? ''),
                      ],
                    );
                  }),
                ],
              )
                  : pw.Text('No transactions available.'),
            ],
          ),
        ),
      );

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${widget.sellerName}_details.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareFiles([file.path], text: 'Seller Details and Product List for ${widget.sellerName}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
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

  void _showPurchaseDialog() {
    final TextEditingController totalPurchaseController = TextEditingController();
    final TextEditingController sellingPriceController = TextEditingController();
    void updateTotalPurchase() {
      final quantity = double.tryParse(_quantityController.text) ?? 0.0;
      final productAmount = double.tryParse(_productAmountController.text) ?? 0.0;
      totalPurchaseController.text = (quantity * productAmount).toStringAsFixed(2);
    }

    _quantityController.addListener(updateTotalPurchase);
    _productAmountController.addListener(updateTotalPurchase);

    final parentContext = context;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.99,
            maxHeight: MediaQuery.of(context).size.width * 9,
          ),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            child: Container(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
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
                            'Purchase Product',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E3A8A),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                            onPressed: () {
                              _quantityController.removeListener(updateTotalPurchase);
                              _productAmountController.removeListener(updateTotalPurchase);
                              totalPurchaseController.dispose();
                              sellingPriceController.dispose();
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _itemNameController,
                              decoration: InputDecoration(
                                labelText: 'Item Name',
                                labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
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
                                errorStyle: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFEF4444)),
                              ),
                              style: GoogleFonts.inter(fontSize: 14),
                              validator: (value) =>
                              value == null || value.isEmpty ? 'Item name is required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _quantityController,
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
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
                                errorStyle: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFEF4444)),
                              ),
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.inter(fontSize: 14),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Quantity is required';
                                }
                                final numValue = double.tryParse(value);
                                if (numValue == null || numValue <= 0) {
                                  return 'Must be a positive number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _productAmountController,
                        decoration: InputDecoration(
                          labelText: 'Product Amount',
                          labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          errorStyle: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFEF4444)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.inter(fontSize: 14),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Amount is required';
                          }
                          final numValue = double.tryParse(value);
                          if (numValue == null || numValue <= 0) {
                            return 'Must be a valid number';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (value.isNotEmpty && !value.contains('.')) {
                            _productAmountController.text = '$value.00';
                            _productAmountController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _productAmountController.text.length - 3),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: sellingPriceController,
                        decoration: InputDecoration(
                          labelText: 'Selling Price',
                          labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          errorStyle: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFEF4444)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.inter(fontSize: 14),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Selling price is required';
                          }
                          final numValue = double.tryParse(value);
                          if (numValue == null || numValue <= 0) {
                            return 'Must be a valid number';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (value.isNotEmpty && !value.contains('.')) {
                            sellingPriceController.text = '$value.00';
                            sellingPriceController.selection = TextSelection.fromPosition(
                              TextPosition(offset: sellingPriceController.text.length - 3),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: totalPurchaseController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Total Purchase Amount',
                          labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          errorStyle: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFEF4444)),
                        ),
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _categoryController,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
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
                          errorStyle: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFEF4444)),
                        ),
                        style: GoogleFonts.inter(fontSize: 14),
                        validator: (value) =>
                        value == null || value.isEmpty ? 'Category is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _paymentAmountController,
                        decoration: InputDecoration(
                          labelText: 'Payment Amount',
                          labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          errorStyle: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFEF4444)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.inter(fontSize: 14),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Payment amount is required';
                          }
                          final numValue = double.tryParse(value);
                          if (numValue == null || numValue < 0) {
                            return 'Must be a valid number';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (value.isNotEmpty && !value.contains('.')) {
                            _paymentAmountController.text = '$value.00';
                            _paymentAmountController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _paymentAmountController.text.length - 3),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Date',
                          labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
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
                          errorStyle: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFEF4444)),
                        ),
                        controller: TextEditingController(
                          text:
                          "${_selectedDate.day} ${_selectedDate.month == 1 ? 'Jan' : _selectedDate.month == 2 ? 'Feb' : _selectedDate.month == 3 ? 'Mar' : _selectedDate.month == 4 ? 'Apr' : _selectedDate.month == 5 ? 'May' : _selectedDate.month == 6 ? 'Jun' : _selectedDate.month == 7 ? 'Jul' : _selectedDate.month == 8 ? 'Aug' : _selectedDate.month == 9 ? 'Sep' : _selectedDate.month == 10 ? 'Oct' : _selectedDate.month == 11 ? 'Nov' : 'Dec'} ${_selectedDate.year}",
                        ),
                        onTap: () => _selectDate(context),
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                print('User UID: ${user.uid}');
                                print('Attempting to write to /Users/${user.uid}/Orders');
                                try {
                                  final quantity = int.parse(_quantityController.text);
                                  final productAmount = double.parse(_productAmountController.text);
                                  final purchaseAmount = quantity * productAmount;
                                  final paymentAmount = double.parse(_paymentAmountController.text);
                                  final sellingPrice = double.parse(sellingPriceController.text);
                                  final status = (purchaseAmount == paymentAmount) ? 'Done' : 'Pending';

                                  await FirebaseFirestore.instance
                                      .collection('Users')
                                      .doc(user.uid)
                                      .collection('Orders')
                                      .add({
                                    'supplierId': widget.supplierData['id'],
                                    'itemName': _itemNameController.text,
                                    'quantity': quantity,
                                    'category': _categoryController.text,
                                    'purchaseAmount': purchaseAmount,
                                    'paymentAmount': paymentAmount,
                                    'sellingPrice': sellingPrice,
                                    'date': _selectedDate.toString().split(' ')[0],
                                    'status': status,
                                    'productAmount': productAmount,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });

                                  _quantityController.removeListener(updateTotalPurchase);
                                  _productAmountController.removeListener(updateTotalPurchase);
                                  _clearControllers();
                                  sellingPriceController.clear();

                                  // Show the success dialog and wait for it to close
                                  await _showSuccessDialog(parentContext, 'Product Purchased Successfully');

                                  // Now it's safe to dispose of the controller and close the purchase dialog
                                  totalPurchaseController.dispose();
                                  sellingPriceController.dispose();
                                  Navigator.of(context).pop();
                                } catch (e) {
                                  print('Firestore error: $e');
                                  ScaffoldMessenger.of(parentContext).showSnackBar(
                                    SnackBar(
                                      content: Text('Error saving purchase: $e'),
                                      backgroundColor: const Color(0xFFEF4444),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                  _quantityController.removeListener(updateTotalPurchase);
                                  _productAmountController.removeListener(updateTotalPurchase);
                                  totalPurchaseController.dispose();
                                  sellingPriceController.dispose();
                                  Navigator.of(context).pop();
                                }
                              } else {
                                print('No user authenticated');
                                ScaffoldMessenger.of(parentContext).showSnackBar(
                                  SnackBar(
                                    content: Text('User not authenticated. Please sign in.'),
                                    backgroundColor: const Color(0xFFEF4444),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                                _quantityController.removeListener(updateTotalPurchase);
                                _productAmountController.removeListener(updateTotalPurchase);
                                totalPurchaseController.dispose();
                                sellingPriceController.dispose();
                                Navigator.of(context).pop();
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
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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

  Future<void> _showSuccessDialog(BuildContext parentContext, String message) async {
  await showGeneralDialog(
    context: parentContext,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(parentContext).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 50,
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
              Text(
                'SUCCESS',
                style: GoogleFonts.inter(
                  fontSize: MediaQuery.of(context).size.width * 0.05,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A8A),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: MediaQuery.of(context).size.width * 0.035,
                  color: const Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.03),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close the success dialog
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text('$message'),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.08,
                      vertical: MediaQuery.of(context).size.height * 0.015,
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.inter(
                      fontSize: MediaQuery.of(context).size.width * 0.035,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
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

  void _showPendingPaymentsDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.99,
          ),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pending Payments',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.maxFinite,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('Users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .collection('Orders')
                          .where('supplierId', isEqualTo: widget.supplierData['id'])
                          .where('status', isEqualTo: 'Pending')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();
                        if (snapshot.hasError) return const Text('Error loading pending payments');
                        if (snapshot.data!.docs.isEmpty)
                          return Text(
                            'No pending payments',
                            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280)),
                          );

                        final mediaQuery = MediaQuery.of(context);
                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: mediaQuery.size.height * 0.35,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              final order = snapshot.data!.docs[index];
                              final orderData = order.data() as Map<String, dynamic>;
                              final purchaseAmount = _parseAmount(orderData['purchaseAmount']);
                              final paymentAmount = _parseAmount(orderData['paymentAmount']);
                              final remainingAmount = purchaseAmount - paymentAmount;
                              final controller = TextEditingController();

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                color: const Color(0xFFFFFFFF),
                                margin: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.009),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: mediaQuery.size.height * 0.001,
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
                                              orderData['itemName'],
                                              style: GoogleFonts.inter(
                                                fontSize: mediaQuery.size.width * 0.035,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF221E22),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              orderData['status'],
                                              style: GoogleFonts.inter(
                                                fontSize: mediaQuery.size.width * 0.03,
                                                color: const Color(0xFFEF4444),
                                              ),
                                            ),
                                            Text(
                                              'Paid: \रु ${paymentAmount.toStringAsFixed(2)}',
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
                                            '\रु ${purchaseAmount.toStringAsFixed(2)}',
                                            style: GoogleFonts.inter(
                                              fontSize: mediaQuery.size.width * 0.030,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF10B981),
                                            ),
                                          ),
                                          SizedBox(height: mediaQuery.size.height * 0.002),
                                          SizedBox(
                                            width: mediaQuery.size.width * 0.20,
                                            child: TextField(
                                              controller: controller,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: InputDecoration(
                                                hintText: 'Add Amount',
                                                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                                filled: true,
                                                fillColor: Colors.white,
                                              ),
                                              style: GoogleFonts.inter(fontSize: 14),
                                              onSubmitted: (value) async {
                                                if (value.isNotEmpty) {
                                                  final additionalAmount = double.tryParse(value) ?? 0.0;
                                                  if (additionalAmount <= 0) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Please enter a valid amount'), backgroundColor: const Color(0xFFEF4444),),
                                                    );
                                                    return;
                                                  }
                                                  if (additionalAmount > remainingAmount) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Error: Payment amount exceeds remaining balance of \रु ${remainingAmount.toStringAsFixed(2)}',
                                                        ),
                                                        backgroundColor: const Color(0xFFEF4444),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  final currentPayment = _parseAmount(orderData['paymentAmount']);
                                                  final newPaymentAmount = currentPayment + additionalAmount;
                                                  final purchaseAmountValue = _parseAmount(orderData['purchaseAmount']);
                                                  await order.reference.update({
                                                    'paymentAmount': newPaymentAmount,
                                                    'status': newPaymentAmount >= purchaseAmountValue ? 'Done' : 'Pending',
                                                  });
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Payment updated to \रु ${newPaymentAmount.toStringAsFixed(2)}'), backgroundColor: const Color(0xFF10B981),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          final pendingOrders = await FirebaseFirestore.instance
                              .collection('Users')
                              .doc(user.uid)
                              .collection('Orders')
                              .where('supplierId', isEqualTo: widget.supplierData['id'])
                              .where('status', isEqualTo: 'Pending')
                              .get();

                          for (var order in pendingOrders.docs) {
                            final orderData = order.data();
                            await order.reference.update({
                              'paymentAmount': orderData['purchaseAmount'],
                              'status': 'Done',
                            });
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('All pending payments cleared!'),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 2),
                            ),
                          );

                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        'Clear All',
                        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFFEF4444)),
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

  void _clearControllers() {
    _itemNameController.clear();
    _quantityController.clear();
    _productAmountController.clear();
    _paymentAmountController.clear();
    _categoryController.clear();
  }

  void _editPaymentAmount(String orderId, dynamic currentPaymentAmount) {
    final TextEditingController editPaymentController = TextEditingController();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add Payment Amount',
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
                  const SizedBox(height: 12),
                  Text(
                    'Current Payment: \रु ${(_parseAmount(currentPaymentAmount)).toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: editPaymentController,
                    decoration: InputDecoration(
                      labelText: 'Additional Payment Amount',
                      labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      errorStyle: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFEF4444)),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.inter(fontSize: 14),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                    onChanged: (value) {
                      if (value.isNotEmpty && !value.contains('.')) {
                        editPaymentController.text = '$value.00';
                        editPaymentController.selection = TextSelection.fromPosition(
                          TextPosition(offset: editPaymentController.text.length - 3),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (editPaymentController.text.isNotEmpty) {
                          final additionalAmount = double.tryParse(editPaymentController.text) ?? 0.0;
                          if (additionalAmount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please enter a valid amount'), backgroundColor: const Color(0xFFEF4444),),
                            );
                            return;
                          }

                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            final orderDoc = await FirebaseFirestore.instance
                                .collection('Users')
                                .doc(user.uid)
                                .collection('Orders')
                                .doc(orderId)
                                .get();

                            final orderData = orderDoc.data() as Map<String, dynamic>;
                            final currentPayment = _parseAmount(orderData['paymentAmount']);
                            final purchaseAmount = _parseAmount(orderData['purchaseAmount']);
                            final remainingAmount = purchaseAmount - currentPayment;

                            if (additionalAmount > remainingAmount) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error: Payment amount exceeds remaining balance of \$${remainingAmount.toStringAsFixed(2)}',
                                  ),
                                  backgroundColor: const Color(0xFFEF4444),
                                ),
                              );
                              return;
                            }

                            final newPaymentAmount = currentPayment + additionalAmount;
                            final status = purchaseAmount <= newPaymentAmount ? 'Done' : 'Pending';

                            await FirebaseFirestore.instance
                                .collection('Users')
                                .doc(user.uid)
                                .collection('Orders')
                                .doc(orderId)
                                .update({
                              'paymentAmount': newPaymentAmount,
                              'status': status,
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Payment updated to \$${newPaymentAmount.toStringAsFixed(2)}'), backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                            Navigator.pop(context);
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
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
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

  double _calculateTotalDue(List<QueryDocumentSnapshot> orders) {
    double totalDue = 0.0;
    for (var order in orders) {
      final orderData = order.data() as Map<String, dynamic>;
      final purchaseAmount = _parseAmount(orderData['purchaseAmount']);
      final paymentAmount = _parseAmount(orderData['paymentAmount']);
      totalDue += (purchaseAmount - paymentAmount);
    }
    return totalDue;
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
              height: mediaQuery.size.height * 0.22,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
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
                            widget.sellerName,
                            style: GoogleFonts.inter(
                              fontSize: mediaQuery.size.width * 0.06,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () async {
                          final snapshot = await FirebaseFirestore.instance
                              .collection('Users')
                              .doc(user!.uid)
                              .collection('Orders')
                              .where('supplierId', isEqualTo: widget.supplierData['id'])
                              .get();
                          _downloadAsPDF(context, snapshot.docs);
                        },
                        child: Container(
                          padding: EdgeInsets.all(mediaQuery.size.width * 0.02),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.white,
                            size: mediaQuery.size.width * 0.06,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.05),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Users')
                        .doc(user!.uid)
                        .collection('Orders')
                        .where('supplierId', isEqualTo: widget.supplierData['id'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          'Error calculating total',
                          style: GoogleFonts.inter(
                            fontSize: mediaQuery.size.width * 0.04,
                            color: const Color(0xFFEF4444),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final totalDue = _calculateTotalDue(snapshot.data!.docs);

                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You Will Give',
                              style: GoogleFonts.inter(
                                fontSize: mediaQuery.size.width * 0.045,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: mediaQuery.size.height * 0.01),
                            Text(
                              '\रु ${totalDue.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: mediaQuery.size.width * 0.06,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                          padding: EdgeInsets.symmetric(
                            horizontal: mediaQuery.size.width * 0.05,
                            vertical: mediaQuery.size.height * 0.02,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _showPurchaseDialog,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.015),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF10B981)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '+ PURCHASE',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF10B981),
                                          fontSize: mediaQuery.size.width * 0.04,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: mediaQuery.size.width * 0.04),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _showPendingPaymentsDialog,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.015),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFEF4444)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '- PENDING',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFEF4444),
                                          fontSize: mediaQuery.size.width * 0.04,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: mediaQuery.size.width * 0.01,
                          ),
                          child: Text(
                            'Product List',
                            style: GoogleFonts.inter(
                              fontSize: mediaQuery.size.width * 0.045,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF221E22),
                            ),
                          ),
                        ),
                        Expanded(
                          child: user == null
                              ? Center(
                            child: Text(
                              'Please sign in',
                              style: GoogleFonts.inter(
                                fontSize: mediaQuery.size.width * 0.04,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          )
                              : StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('Users')
                                .doc(user.uid)
                                .collection('Orders')
                                .where('supplierId', isEqualTo: widget.supplierData['id'])
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                print('Firestore error: ${snapshot.error}');
                                return Center(
                                  child: Text(
                                    'Error loading orders',
                                    style: GoogleFonts.inter(
                                      fontSize: mediaQuery.size.width * 0.04,
                                      color: const Color(0xFFEF4444),
                                    ),
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              final orders = snapshot.data!.docs;

                              return ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.05),
                                itemCount: orders.length,
                                itemBuilder: (context, index) {
                                  final order = orders[index];
                                  final orderData = order.data() as Map<String, dynamic>;
                                  final purchaseAmount = _parseAmount(orderData['purchaseAmount']);
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
                                                  orderData['itemName'] ?? '',
                                                  style: GoogleFonts.inter(
                                                    fontSize: mediaQuery.size.width * 0.035,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF221E22),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  orderData['status'] ?? '',
                                                  style: GoogleFonts.inter(
                                                    fontSize: mediaQuery.size.width * 0.03,
                                                    color: orderData['status'] == 'Pending'
                                                        ? const Color(0xFFEF4444)
                                                        : const Color(0xFF10B981),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '\रु ${purchaseAmount.toStringAsFixed(2)}',
                                            style: GoogleFonts.inter(
                                              fontSize: mediaQuery.size.width * 0.035,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF10B981),
                                            ),
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
                        SizedBox(height: mediaQuery.size.height * 0.02),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      // bottomNavigationBar: BottomNavigationBar(
      //   type: BottomNavigationBarType.fixed,
      //   selectedItemColor: const Color(0xFF1E3A8A),
      //   unselectedItemColor: const Color(0xFF6B7280),
      //   currentIndex: _selectedIndex,
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
}