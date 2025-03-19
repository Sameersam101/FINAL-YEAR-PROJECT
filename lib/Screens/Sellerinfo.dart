import 'package:flutter/material.dart';

class SellerInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header Section
          Container(
            padding: EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 20),
            color: Colors.orange,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.arrow_back, color: Colors.black),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hari Bahadur',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          'You Will Give',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '\$100,000',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          // Table Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Entries', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Purchase', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Divider(),
          // Transaction List
          Expanded(
            child: ListView(
              children: [
                TransactionItem(
                  entry: 'Mango',
                  date: '09-Dec-12:20',
                  purchase: '\$4980',
                  payment: '\$4980',
                  status: 'Done',
                  statusColor: Colors.green,
                ),
                TransactionItem(
                  entry: 'Mango',
                  date: '09-Dec-12:20',
                  purchase: '\$4980',
                  payment: '\$4000',
                  status: 'Pending',
                  statusColor: Colors.red,
                ),
                TransactionItem(
                  entry: 'Mango',
                  date: '09-Dec-12:20',
                  purchase: '\$4980',
                  payment: '\$4980',
                  status: 'Done',
                  statusColor: Colors.green,
                ),
                TransactionItem(
                  entry: 'Mango',
                  date: '09-Dec-12:20',
                  purchase: '\$4980',
                  payment: '\$4000',
                  status: 'Pending',
                  statusColor: Colors.red,
                ),
              ],
            ),
          ),
          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  child: Text('PURCHASE', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  child: Text('PAYMENT', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: Icon(Icons.home), onPressed: () {}),
            IconButton(icon: Icon(Icons.shopping_bag), onPressed: () {}),
            SizedBox(width: 40), // Space for the FAB
            IconButton(icon: Icon(Icons.message), onPressed: () {}),
            IconButton(icon: Icon(Icons.bar_chart), onPressed: () {}),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.apps),
        backgroundColor: Colors.blue,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class TransactionItem extends StatelessWidget {
  final String entry;
  final String date;
  final String purchase;
  final String payment;
  final String status;
  final Color statusColor;

  TransactionItem({
    required this.entry,
    required this.date,
    required this.purchase,
    required this.payment,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry),
              Text(date, style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          Text(purchase),
          Text(payment),
          Text(
            status,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}