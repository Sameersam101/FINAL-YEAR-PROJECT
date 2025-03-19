import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'profile.dart';
import 'transaction.dart';
import 'sellerpage.dart';
import 'inventorypage.dart';
import 'analyticspage.dart';
import 'login_page.dart';

class DashboardPage extends StatefulWidget {
  DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

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
        Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryPage()));
        break;
      case 2:
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      });
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.orange,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dashboard',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.notifications, color: Colors.black),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Notifications clicked')),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.person, color: Colors.black),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ProfileScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('userId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSummaryCard('Total Balance', 'Loading...', Colors.green),
                          _buildSummaryCard('Total Expense', 'Loading...', Colors.red),
                        ],
                      );
                    }
                    if (snapshot.hasError) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSummaryCard('Total Balance', 'Error', Colors.green),
                          _buildSummaryCard('Total Expense', 'Error', Colors.red),
                        ],
                      );
                    }

                    int totalBalance = 0;
                    int totalExpense = 0;

                    for (final doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final amount = data['amount'] as int;
                      if (data['type'] == 'sale') {
                        totalBalance += amount;
                      } else if (data['type'] == 'expense') {
                        totalExpense += amount;
                      }
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSummaryCard('Total Balance', '\$$totalBalance', Colors.green),
                        _buildSummaryCard('Total Expense', '\$$totalExpense', Colors.red),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Links',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildQuickLink(Icons.receipt, 'Transaction', () => Navigator.push(context, MaterialPageRoute(builder: (context) => Transactionpage()))),
                              SizedBox(width: 20),
                              _buildQuickLink(Icons.person, 'Seller', () => Navigator.push(context, MaterialPageRoute(builder: (context) => SellerPage()))),
                              SizedBox(width: 20),
                              _buildQuickLink(Icons.shopping_bag, 'Inventory', () => Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryPage()))),
                              SizedBox(width: 20),
                              _buildQuickLink(Icons.bar_chart, 'Analytics', () => Navigator.push(context, MaterialPageRoute(builder: (context) => Analyticspage()))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recent Transactions',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('transactions')
                                .where('userId', isEqualTo: user.uid)
                                .orderBy('createdAt', descending: true)
                                .limit(6)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}');
                              }
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return Text('No transactions available');
                              }

                              final transactionsByDate = <String, List<QueryDocumentSnapshot>>{};
                              for (final doc in snapshot.data!.docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                final date = (data['date'] as Timestamp).toDate();
                                final dateStr = DateFormat('MMM d - yyyy').format(date).toUpperCase(); // Uppercase to match screenshot
                                transactionsByDate.putIfAbsent(dateStr, () => []).add(doc);
                              }

                              return Column(
                                children: transactionsByDate.entries.map((dateEntry) {
                                  final date = dateEntry.key;
                                  final transactions = dateEntry.value;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _transactionDateHeader(date),
                                      ...transactions.map((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final isIncome = data['type'] == 'sale';
                                        final amount = data['amount'] as int;
                                        final title = _buildTransactionTitle(data);
                                        final timestamp = (data['createdAt'] as Timestamp).toDate();
                                        final timeStr = DateFormat('dd MMM, HH:mm').format(timestamp);
                                        return _transactionItem(title, amount, isIncome, timeStr);
                                      }).toList(),
                                    ],
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSaleDialog(context),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
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
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color) {
    return Container(
      width: 160,
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          SizedBox(height: 3),
          Text(amount, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildQuickLink(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(radius: 25, backgroundColor: Colors.orange.shade100, child: Icon(icon, color: Colors.blue)),
          SizedBox(height: 5),
          Text(label, style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _transactionDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5), // Adjusted to match screenshot spacing
      child: Text(
        date,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _transactionItem(String title, int amount, bool isIncome, String timestamp) {
    return Card(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.blue),
        borderRadius: BorderRadius.circular(14), // Match screenshot
      ),
      margin: const EdgeInsets.only(bottom: 8), // Match screenshot
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0), // Match screenshot
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left side: Empty space to push content slightly to the right
            const SizedBox(width: 5), // Match screenshot

            // Middle: Product title and transaction type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    isIncome ? 'Cash In' : 'Cash Out',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

            // Right side: Amount and timestamp
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (isIncome ? '+\$' : '-\$') + amount.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  timestamp,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(width: 5),
          ],
        ),
      ),
    );
  }

  String _buildTransactionTitle(Map<String, dynamic> data) {
    final type = data['type'] as String;
    if (type == 'sale') {
      final quantities = data['quantities'] as Map<String, dynamic>? ?? {};
      final items = quantities.entries.map((e) => '${e.key} (${e.value})').join(', ');
      return quantities.isNotEmpty ? items : 'Unknown Product';
    } else if (type == 'expense') {
      final description = data['description'] as String? ?? 'Unknown';
      final quantity = data['quantity'] as int? ?? 0;
      return '$description (${quantity > 0 ? quantity : ''})';
    }
    return 'Unknown Transaction';
  }

  void _showAddSaleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddSaleDialog(
        onSwitchToExpense: () => _showAddExpenseDialog(context),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddExpenseDialog(
        onSwitchToSale: () => _showAddSaleDialog(context),
      ),
    );
  }
}

class AddSaleDialog extends StatefulWidget {
  final VoidCallback onSwitchToExpense;

  AddSaleDialog({super.key, required this.onSwitchToExpense});

  @override
  State<AddSaleDialog> createState() => _AddSaleDialogState();
}

class _AddSaleDialogState extends State<AddSaleDialog> {
  String? _selectedCategory;
  final Map<String, int> _quantities = {};
  final _manualEntryController = TextEditingController();
  final _manualQuantityController = TextEditingController();
  final _amountController = TextEditingController(text: '3000');

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('Inventory').get();
      final products = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'category': data['category'] as String? ?? 'Uncategorized',
          'name': data['productName'] as String? ?? 'Unnamed Product',
        };
      }).toList();

      final groupedProducts = <String, List<String>>{};
      for (var product in products) {
        groupedProducts.putIfAbsent(product['category'] as String, () => []).add(product['name'] as String);
      }
      return groupedProducts.entries.map((entry) => {'name': entry.key, 'items': entry.value}).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching products: $e')));
      return [
        {'name': 'Food', 'items': ['Noodles', 'Noodles', 'Noodles']},
        {'name': 'Fruits', 'items': ['Noodles', 'Noodles', 'Noodles']},
      ];
    }
  }

  void _updateQuantity(String item, int delta) {
    setState(() {
      _quantities[item] = (_quantities[item] ?? 0) + delta;
      if (_quantities[item]! < 0) _quantities[item] = 0;
    });
  }

  Future<void> _saveSale() async {
    if (_selectedCategory == null && _manualEntryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a category or manual entry')));
      return;
    }

    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a valid amount')));
      return;
    }

    final manualQuantity = int.tryParse(_manualQuantityController.text) ?? 0;
    if (_manualEntryController.text.isNotEmpty && manualQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a valid quantity for manual entry')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User not authenticated. Please log in.')));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
      return;
    }

    try {
      final date = DateTime.now();
      final quantities = {..._quantities};
      if (_manualEntryController.text.isNotEmpty) {
        quantities[_manualEntryController.text] = manualQuantity;
      }

      await FirebaseFirestore.instance.collection('transactions').add({
        'type': 'sale',
        'amount': amount,
        'category': _selectedCategory ?? _manualEntryController.text,
        'quantities': quantities,
        'date': Timestamp.fromDate(date),
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale saved successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving sale: $e')));
      }
    }
  }

  @override
  void dispose() {
    _manualEntryController.dispose();
    _manualQuantityController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text('SALES', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
              SizedBox(height: 5),
              Text(DateFormat('dd MMM').format(DateTime.now()), style: TextStyle(fontSize: 16, color: Colors.grey)),
              SizedBox(height: 5),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(labelText: 'Sales amount', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: StadiumBorder()),
                    child: Text('Sale'),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSwitchToExpense();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: StadiumBorder()),
                    child: Text('Expense'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  final categories = snapshot.data ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        hint: Text('Category'),
                        items: categories.map((category) => DropdownMenuItem<String>(value: category['name'] as String, child: Text(category['name'] as String))).toList(),
                        onChanged: (value) => setState(() => _selectedCategory = value),
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))),
                      ),
                      SizedBox(height: 10),
                      ...categories.expand((category) {
                        if (_selectedCategory != category['name']) return [];
                        return (category['items'] as List<String>).map((item) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item),
                              Row(
                                children: [
                                  IconButton(icon: Icon(Icons.remove_circle_outline), onPressed: () => _updateQuantity(item, -1)),
                                  Text(_quantities[item]?.toString() ?? '0'),
                                  IconButton(icon: Icon(Icons.add_circle_outline), onPressed: () => _updateQuantity(item, 1)),
                                ],
                              ),
                            ],
                          ),
                        ));
                      }),
                    ],
                  );
                },
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualEntryController,
                      decoration: InputDecoration(labelText: 'Manual Entry', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _manualQuantityController,
                      decoration: InputDecoration(labelText: 'Quantity', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _saveSale,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                  child: Text('Save', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddExpenseDialog extends StatefulWidget {
  final VoidCallback onSwitchToSale;

  AddExpenseDialog({super.key, required this.onSwitchToSale});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _amountController = TextEditingController(text: '3000');

  Future<void> _saveExpense() async {
    if (_descriptionController.text.isEmpty || _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final amount = int.tryParse(_amountController.text) ?? 0;
    final quantity = int.tryParse(_quantityController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a valid amount')));
      return;
    }
    if (quantity == null || quantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a valid quantity')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User not authenticated. Please log in.')));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
      return;
    }

    try {
      final date = DateTime.now();

      await FirebaseFirestore.instance.collection('transactions').add({
        'type': 'expense',
        'amount': amount,
        'description': _descriptionController.text,
        'quantity': quantity,
        'date': Timestamp.fromDate(date),
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expense saved successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving expense: $e')));
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text('EXPENSE', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
              SizedBox(height: 10),
              Text(DateFormat('dd MMM').format(DateTime.now()), style: TextStyle(fontSize: 16, color: Colors.grey)),
              SizedBox(height: 20),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(labelText: 'Debit amount', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSwitchToSale();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: StadiumBorder()),
                    child: Text('Sale'),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: StadiumBorder()),
                    child: Text('Expense'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Write Expenses you did.', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))),
                maxLines: 3,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _quantityController,
                decoration: InputDecoration(labelText: 'Quantity', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _saveExpense,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                  child: Text('Save', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}