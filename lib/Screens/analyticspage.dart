import 'package:arthikapp/Screens/Scanpage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arthikapp/Screens/dashboard.dart';
import 'package:arthikapp/Screens/inventorypage.dart';
import 'package:arthikapp/Screens/transaction.dart';

class Analyticspage extends StatefulWidget {
  const Analyticspage({super.key});

  @override
  State<Analyticspage> createState() => _AnalyticspageState();
}

class _AnalyticspageState extends State<Analyticspage> {
  int _selectedIndex = 4;

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
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
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
                        'Analytics',
                        style: GoogleFonts.inter(
                          fontSize: mediaQuery.size.width * 0.06,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
                          _buildMonthSelector(mediaQuery),
                          _buildStatsRow(mediaQuery),
                          _buildNetProfit(mediaQuery),
                          _buildPieChartPlaceholder(mediaQuery),
                          _buildIncomeBreakdown(mediaQuery),
                          _buildTransactionReport(mediaQuery),
                          _buildAiPredictionButton(mediaQuery),
                          SizedBox(height: mediaQuery.size.height * 0.02),
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

  Widget _buildMonthSelector(MediaQueryData mediaQuery) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: mediaQuery.size.width * 0.05,
        vertical: mediaQuery.size.height * 0.02,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: mediaQuery.size.width * 0.04,
          vertical: mediaQuery.size.height * 0.01,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_rounded, color: const Color(0xFF6B7280), size: mediaQuery.size.width * 0.05),
            SizedBox(width: mediaQuery.size.width * 0.02),
            Text(
              "December 2023",
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.04,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(MediaQueryData mediaQuery) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatCard(
            'Income',
            '\रु 500,000',
            const Color(0xFF10B981),
            mediaQuery,
          ),
          _buildStatCard(
            'Expenses',
            '\रु 800,000',
            const Color(0xFFEF4444),
            mediaQuery,
          ),
        ],
      ),
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

  Widget _buildNetProfit(MediaQueryData mediaQuery) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: mediaQuery.size.width * 0.05,
        vertical: mediaQuery.size.height * 0.02,
      ),
      child: Container(
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
          children: [
            Text(
              "NET PROFIT",
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.035,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.01),
            Text(
              "\रु 10,928,873,700",
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.045,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF10B981),
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.005),
            Text(
              "▲ From Past Month",
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.03,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartPlaceholder(MediaQueryData mediaQuery) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.05),
      child: Container(
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
          children: [
            Text(
              "Expense Breakdown",
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.035,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            Container(
              height: mediaQuery.size.height * 0.2,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  "Pie Chart Placeholder",
                  style: GoogleFonts.inter(
                    fontSize: mediaQuery.size.width * 0.035,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeBreakdown(MediaQueryData mediaQuery) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: mediaQuery.size.width * 0.05,
        vertical: mediaQuery.size.height * 0.02,
      ),
      child: Container(
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
              "Income Breakdown",
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.035,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            _buildIncomeItem("Rice Cooker", "400 Units", "\रु 5000", true, mediaQuery),
            SizedBox(height: mediaQuery.size.height * 0.01),
            _buildIncomeItem("Microwave", "200 Units", "\रु 3000", true, mediaQuery),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeItem(String title, String subtitle, String amount, bool isIncome, MediaQueryData mediaQuery) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      color: const Color(0xFFFFFFFF),
      margin: EdgeInsets.zero,
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
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: mediaQuery.size.width * 0.03,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.035,
                fontWeight: FontWeight.bold,
                color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionReport(MediaQueryData mediaQuery) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.05),
      child: Container(
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
              "Transaction Report",
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.035,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.download_rounded, size: mediaQuery.size.width * 0.05),
                label: Text(
                  "DOWNLOAD REPORT",
                  style: GoogleFonts.inter(
                    fontSize: mediaQuery.size.width * 0.035,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  foregroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.015),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiPredictionButton(MediaQueryData mediaQuery) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: mediaQuery.size.width * 0.05,
        vertical: mediaQuery.size.height * 0.02,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.02),
          ),
          child: Text(
            "AI PREDICTION",
            style: GoogleFonts.inter(
              fontSize: mediaQuery.size.width * 0.04,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}