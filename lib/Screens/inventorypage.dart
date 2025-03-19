import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dashboard.dart'; // Assuming DashboardPage is in dashboard.dart
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
  int _selectedIndex = 1; // Inventory is the second item (index 1)

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DashboardPage()));
        break;
      case 1:
      // Already on Inventory
        break;
      case 2:
      // Scanner page not implemented
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (context) => Transactionpage()));
        break;
      case 4:
        Navigator.push(context, MaterialPageRoute(builder: (context) => Analyticspage()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
      });
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_sharp), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_4x4), label: 'Scanner'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Transaction'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Analytics'),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeaderSection(),
              SizedBox(height: 16),
              StatsSection(),
              SizedBox(height: 16),
              ActionSection(),
              SizedBox(height: 16),
              ProductListSection(),
            ],
          ),
        ),
      ),
    );
  }
}

// Header Section
class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Inventory',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(width: 50), // Spacer for symmetry
        ],
      ),
    );
  }
}

// Stats Section
class StatsSection extends StatelessWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('transactions').where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid).snapshots(),
        builder: (context, transactionSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Inventory').snapshots(),
            builder: (context, inventorySnapshot) {
              if (transactionSnapshot.connectionState == ConnectionState.waiting || inventorySnapshot.connectionState == ConnectionState.waiting) {
                return _buildStatsCards('Loading...', 'Loading...', 'Loading...');
              }
              if (transactionSnapshot.hasError || inventorySnapshot.hasError) {
                return _buildStatsCards('Error', 'Error', 'Error');
              }

              final today = DateTime.now();
              final todaySales = transactionSnapshot.data!.docs.where((doc) {
                final date = (doc['date'] as Timestamp).toDate();
                return doc['type'] == 'sale' && date.year == today.year && date.month == today.month && date.day == today.day;
              }).fold<int>(0, (sum, doc) => sum + (doc['amount'] as int? ?? 0));

              final totalProducts = inventorySnapshot.data!.docs.fold<int>(0, (sum, doc) => sum + (doc['quantity'] as int? ?? 0));
              final outOfStock = inventorySnapshot.data!.docs.where((doc) => (doc['quantity'] as int? ?? 0) == 0).length;

              return _buildStatsCards('\$$todaySales', '$totalProducts', '$outOfStock');
            },
          );
        },
      ),
    );
  }

  Widget _buildStatsCards(String todaySales, String totalProducts, String outOfStock) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatCard(label: "Today's Sale", value: todaySales, color: Colors.green),
        _StatCard(label: 'Total Product', value: totalProducts, color: Colors.green),
        _StatCard(label: 'Out of Stock', value: outOfStock, color: Colors.red),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 3),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, spreadRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

// Action Section
class ActionSection extends StatelessWidget {
  const ActionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            label: '+ Product In',
            color: Colors.green,
            onTap: () => _showDialog(context, 'in'),
          ),
          SizedBox(width: 16),
          _ActionButton(
            label: '- Product Out',
            color: Colors.red,
            onTap: () => _showDialog(context, 'out'),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (_) => ProductTransactionDialog(initialType: type),
    );
  }
}

// Product Transaction Dialog
class ProductTransactionDialog extends StatefulWidget {
  final String initialType;

  const ProductTransactionDialog({super.key, required this.initialType});

  @override
  State<ProductTransactionDialog> createState() => _ProductTransactionDialogState();
}

class _ProductTransactionDialogState extends State<ProductTransactionDialog> {
  late String _type = widget.initialType;
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
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
      final snapshot = await FirebaseFirestore.instance.collection('Inventory').get();
      setState(() {
        _products = snapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc['productName'],
          'category': doc['category'],
          'quantity': doc['quantity'],
          'price': doc['price'],
        }).toList();
      });
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveTransaction() async {
    if (_type == 'in') {
      if (!(_validateFields())) return;
      final quantity = int.parse(_quantityController.text);
      final price = double.parse(_priceController.text);
      try {
        await FirebaseFirestore.instance.collection('Inventory').add({
          'type': _type,
          'productName': _nameController.text,
          'category': _categoryController.text,
          'quantity': quantity,
          'price': price,
          'date': Timestamp.fromDate(_selectedDate),
          'createdAt': FieldValue.serverTimestamp(),
          'userId': FirebaseAuth.instance.currentUser!.uid,
        });
        _showSuccessDialog('Product Added Successfully');
      } catch (e) {
        _showSnackBar('Error saving product: $e');
      }
    } else {
      if (_products.isEmpty) return _showSnackBar('No products available');
      try {
        for (var product in _products) {
          if (_updatedQuantities.containsKey(product['id'])) {
            final newQuantity = _updatedQuantities[product['id']]!;
            if (newQuantity < 0) return _showSnackBar('Insufficient quantity');
            await FirebaseFirestore.instance.collection('Inventory').doc(product['id']).update({'quantity': newQuantity});
          }
        }
        _showSuccessDialog('Product Removed Successfully');
      } catch (e) {
        _showSnackBar('Error saving product: $e');
      }
    }
  }

  bool _validateFields() {
    if (_nameController.text.isEmpty || _categoryController.text.isEmpty || _quantityController.text.isEmpty || _priceController.text.isEmpty) {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Success', style: TextStyle(color: Colors.green)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close success dialog
              Navigator.pop(context); // Close transaction dialog
            },
            child: const Text('OK', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, spreadRadius: 5)],
        ),
        child: SingleChildScrollView(
          child: _type == 'in' ? _buildProductIn() : _buildProductOut(),
        ),
      ),
    );
  }

  Widget _buildProductIn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Add Product',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.grey),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        SizedBox(height: 16),
        _buildTextField(_nameController, 'Product Name'),
        SizedBox(height: 12),
        _buildTextField(_categoryController, 'Category'),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_quantityController, 'Quantity', keyboardType: TextInputType.number)),
            SizedBox(width: 12),
            Expanded(child: _buildTextField(_priceController, 'Price', prefixText: '\$', keyboardType: TextInputType.number)),
          ],
        ),
        SizedBox(height: 16),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
        SizedBox(height: 24),
        ElevatedButton(
          onPressed: _saveTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.symmetric(vertical: 14),
            minimumSize: Size(double.infinity, 0),
          ),
          child: Text('Save', style: TextStyle(fontSize: 16, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {String? prefixText, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixText: prefixText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      keyboardType: keyboardType,
    );
  }

  Widget _buildProductOut() {
    final groupedProducts = _products.fold<Map<String, List<Map<String, dynamic>>>>(
      {},
          (map, product) => map..putIfAbsent(product['category'], () => []).add(product),
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.grey),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        SizedBox(height: 16),
        if (_products.isEmpty)
          Center(child: Text('No products available', style: TextStyle(color: Colors.grey)))
        else
          ...groupedProducts.entries.map((entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
              SizedBox(height: 8),
              ...entry.value.map((product) => Container(
                margin: EdgeInsets.only(bottom: 4),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product['name'], style: TextStyle(fontSize: 16)),
                        Text('Stock: ${product['quantity']}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => setState(() => _updatedQuantities[product['id']] =
                              (_updatedQuantities[product['id']] ?? product['quantity']) - 1),
                        ),
                        Text('${_updatedQuantities[product['id']] ?? product['quantity']}', style: TextStyle(fontSize: 16)),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: Colors.green),
                          onPressed: () => setState(() => _updatedQuantities[product['id']] =
                              (_updatedQuantities[product['id']] ?? product['quantity']) + 1),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteProduct(product['id']),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
              SizedBox(height: 12),
            ],
          )),
        SizedBox(height: 24),
        ElevatedButton(
          onPressed: _saveTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.symmetric(vertical: 14),
            minimumSize: Size(double.infinity, 0),
          ),
          child: Text('Save', style: TextStyle(fontSize: 16, color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await FirebaseFirestore.instance.collection('Inventory').doc(productId).delete();
      setState(() => _products.removeWhere((p) => p['id'] == productId));
      _showSnackBar('Product deleted successfully');
    } catch (e) {
      _showSnackBar('Error deleting product: $e');
    }
  }
}
// Product List Section
class ProductListSection extends StatelessWidget {
  const ProductListSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Product List', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('See All', style: TextStyle(color: Colors.blue, fontSize: 14)),
            ],
          ),
          SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Inventory').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text('No products available', style: TextStyle(color: Colors.grey));
              }

              // Group products by category
              final groupedProducts = snapshot.data!.docs.fold<Map<String, List<Map<String, dynamic>>>>(
                {},
                    (map, doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final category = data['category'] as String? ?? 'Uncategorized';
                  map.putIfAbsent(category, () => []).add({
                    'id': doc.id,
                    'name': data['productName'],
                    'quantity': data['quantity'],
                    'price': data['price'],
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
                        category,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 8),
                      ...products.map((product) => Container(
                        margin: EdgeInsets.only(bottom: 4),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product['name'], style: TextStyle(fontSize: 16)),
                                Text('Stock: ${product['quantity']}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            Text('\$${product['price'].toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      )),
                      SizedBox(height: 12),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProductItem extends StatelessWidget {
  final String productName;
  final int totalProduct, remainingProduct;
  final double price;

  const ProductItem({
    super.key,
    required this.productName,
    required this.totalProduct,
    required this.remainingProduct,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, spreadRadius: 2)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: Colors.blue, size: 30),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(productName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Stock: $remainingProduct', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
          Text('\$${price.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      ),
    );
  }
}

// Reusable Widgets
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}