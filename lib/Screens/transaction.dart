import 'package:arthikapp/Screens/analyticspage.dart';
import 'package:arthikapp/Screens/dashboard.dart';
import 'package:arthikapp/Screens/inventorypage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'login_page.dart';

class Transactionpage extends StatefulWidget {
  @override
  _TransactionpageState createState() => _TransactionpageState();
}

class _TransactionpageState extends State<Transactionpage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // Default filter
  final Map<String, int> _filterDays = {'7 Days': 7, '15 Days': 15, '30 Days': 30, 'All': 0};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      backgroundColor: Colors.orange, // Orange background for the top section
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text(
          'Transaction',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Orange section with search and filters
            Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _filterButton('Filter', icon: Icons.filter_list),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _filterButton('7 Days'),
                  _filterButton('15 Days'),
                  _filterButton('30 Days'),
                  _filterButton('All'),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // White curved container for date headers and transaction list
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('userId', isEqualTo: user.uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      final error = snapshot.error.toString();
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Error: $error',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => Transactionpage()),
                                  );
                                },
                                child: const Text('Retry'),
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please create the index using the link in the error message.')),
                                  );
                                },
                                child: const Text(
                                  'Create Index Here',
                                  style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No transactions available'));
                    }

                    final now = DateTime.now();
                    final filteredDocs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final date = (data['date'] as Timestamp).toDate();
                      final daysDiff = now.difference(date).inDays;
                      return _filterDays[_selectedFilter] == 0 || daysDiff <= _filterDays[_selectedFilter]!;
                    }).toList();

                    final searchQuery = _searchController.text.toLowerCase();
                    final filteredTransactions = filteredDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title = _buildTransactionTitle(data).toLowerCase();
                      return searchQuery.isEmpty || title.contains(searchQuery);
                    }).toList();

                    if (filteredTransactions.isEmpty) {
                      return const Center(child: Text('No matching transactions'));
                    }

                    final transactionsByDate = <String, List<QueryDocumentSnapshot>>{};
                    for (final doc in filteredTransactions) {
                      final data = doc.data() as Map<String, dynamic>;
                      final date = (data['date'] as Timestamp).toDate();
                      final dateStr = DateFormat('MMM d - yyyy').format(date);
                      transactionsByDate.putIfAbsent(dateStr, () => []).add(doc);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: transactionsByDate.length,
                      itemBuilder: (context, index) {
                        final dateEntry = transactionsByDate.entries.elementAt(index);
                        final date = dateEntry.key;
                        final transactions = dateEntry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date header inside white container
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                              child: Text(
                                date,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            // Transaction items
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
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: 3,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DashboardPage()));
              break;
            case 1:
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => InventoryPage()));
              break;
            case 2:
            // Scanner page not implemented
              break;
            case 3:
            // Already on Transaction
              break;
            case 4:
              Navigator.push(context, MaterialPageRoute(builder: (context) => Analyticspage()));
              break;
          }
        },
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

  Widget _filterButton(String text, {IconData? icon}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = text;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 5),
        decoration: BoxDecoration(
          color: _selectedFilter == text ? Colors.blueAccent.withOpacity(0.4) : Colors.white,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 18, color: Colors.black),
            if (icon != null) const SizedBox(width: 2),
            Text(
              text,
              style: TextStyle(
                color: Colors.black,
                fontWeight: _selectedFilter == text ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _transactionItem(String title, int amount, bool isIncome, String timestamp) {
    return Card(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.blue),
        borderRadius: BorderRadius.circular(14), // Slightly smaller radius for compactness
      ),
      margin: const EdgeInsets.only(bottom: 8), // Reduced margin for tighter spacing
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0), // Adjusted padding
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left side: Empty space to push content slightly to the right
            const SizedBox(width: 10), // Adds a little space to move the product title right

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

            // Right side: Amount and timestamp, moved slightly to the left
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
                const SizedBox(height: 5),
                Text(
                  timestamp,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(width: 5), // Adds a little space to move the amount left
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
}