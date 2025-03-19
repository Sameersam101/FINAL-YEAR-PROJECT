import 'package:flutter/material.dart';

class Analyticspage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNavigationBarWidget(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildNetProfit(),
            _buildPieChart(),
            _buildIncomeBreakdown(),
            _buildTransactionReport(),
            _buildAiPredictionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Text("Analytics", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text("Dec"),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoCard("INCOME", "\$500,000", Colors.green.shade700, Colors.grey.shade200),
              _buildInfoCard("EXPECES", "\$800,000", Colors.red.shade700, Colors.blue.shade100),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String amount, Color textColor, Color bgColor) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          Text(amount, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildNetProfit() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Text("NET PROFIT", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("\$10,928,873,700", style: TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold)),
          Text("▲ From Past Month", style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Text("Pie Chart Placeholder"), // Replace with an actual pie chart widget
        ],
      ),
    );
  }

  Widget _buildIncomeBreakdown() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Income Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          _buildIncomeItem("Rice Cooker", "400 Units", "\$5000"),
          _buildIncomeItem("Rice Cooker", "400 Units", "\$5000"),
        ],
      ),
    );
  }

  Widget _buildIncomeItem(String title, String subtitle, String amount) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(Icons.store),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(amount, style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTransactionReport() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Transaction Report", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.download),
            label: Text("DOWNLOAD"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300),
          )
        ],
      ),
    );
  }

  Widget _buildAiPredictionButton() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: ElevatedButton(
        onPressed: () {},
        child: Text("AI PREDICTION", style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class BottomNavigationBarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: Icon(Icons.home, color: Colors.blue), onPressed: () {}),
          IconButton(icon: Icon(Icons.shopping_bag, color: Colors.blue), onPressed: () {}),
          FloatingActionButton(
            onPressed: () {},
            backgroundColor: Colors.orange,
            child: Icon(Icons.grid_view, color: Colors.white),
          ),
          IconButton(icon: Icon(Icons.image, color: Colors.blue), onPressed: () {}),
          IconButton(icon: Icon(Icons.analytics, color: Colors.blue), onPressed: () {}),
        ],
      ),
    );
  }
}