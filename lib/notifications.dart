import 'package:arthikapp/Screens/Sellerinfo.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:arthikapp/Screens/sellerpage.dart'; // Import for navigation

class NotificationsServices {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  bool _isDialogShowing = false;
  List<Map<String, dynamic>> _pendingLowStockProducts = [];
  Map<String, int> _previousStockLevels = {};
  List<Map<String, dynamic>> _pendingPayments = []; // For pending payments
  Timer? _timer; // Timer for periodic scanning

  NotificationsServices() {
    // Do not start the timer here; wait for context to be set
  }

  // Start periodic scanning for pending payments
  void _startPeriodicScanning() {
    // Prevent starting multiple timers
    if (_timer != null) return;

    _timer = Timer.periodic(Duration(minutes: 60), (timer) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await checkAndSendPendingPaymentNotification(userId);
      } else {
        print('User ID is null, skipping pending payment check');
      }
    });
  }

  // Dispose of the timer when the service is no longer needed
  void dispose() {
    _timer?.cancel();
    context = null;
    _isDialogShowing = false;
    _pendingLowStockProducts.clear();
    _previousStockLevels.clear();
    _pendingPayments.clear();
    print('NotificationsServices disposed');
  }

  // Request notification permissions
  Future<void> requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User denied permission');
    }
  }

  // Check if notification permissions are granted
  Future<bool> areNotificationsEnabled() async {
    NotificationSettings settings = await messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // Show a custom dialog for pending payment notifications
  void _showPendingPaymentNotificationDialog(BuildContext dialogContext) {
    if (_pendingPayments.isEmpty || _isDialogShowing) return;

    _isDialogShowing = true;
    print('Showing pending payment notification dialog');

    final message = _pendingPayments
        .map((payment) => 'Your due amount is ${payment['remainingAmount']} for ${payment['sellerName']}')
        .join('\n');

    showDialog(
      context: dialogContext,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Color(0xFFF97316), size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Pending Payment Alert',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              _markNotificationsAsRead(context, 'pending_payment');
              Navigator.pop(context);
            },
            child: const Text('Okay', style: TextStyle(color: Color(0xFF1E3A8A))),
          ),
          TextButton(
            onPressed: () {
              _markNotificationsAsRead(context, 'pending_payment');
              Navigator.pop(context);
              _redirectToSellerPage(context);
            },
            child: const Text('Pay Now', style: TextStyle(color: Color(0xFF1E3A8A))),
          ),
        ],
      ),
    ).then((_) {
      _isDialogShowing = false;
      _pendingPayments.clear();
    });
  }

  // Redirect to SellerPage or SellerDetailPage based on the number of sellers
  void _redirectToSellerPage(BuildContext context) {
    if (_pendingPayments.length == 1) {
      // Navigate to SellerDetailPage for the specific supplier
      final supplierData = _pendingPayments[0]['supplierData'];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SellerDetailPage(
            sellerName: supplierData['name'],
            totalAmount: '0', // Adjust if needed
            supplierData: supplierData,
          ),
        ),
      );
    } else {
      // Navigate to SellerPage to show the list of suppliers
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SellerPage()),
      );
    }
  }

  // Mark notifications as read
  Future<void> _markNotificationsAsRead(BuildContext context, String type) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final notifications = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .where('type', isEqualTo: type)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
      print('Marked $type notifications as read');
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  // Check and send pending payment notifications
  Future<void> checkAndSendPendingPaymentNotification(String userId) async {
    print('Checking for pending payments');

    // Check if duePaymentAlerts is enabled
    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .get();
    final duePaymentAlerts = userDoc.data()?['duePaymentAlerts'] as bool? ?? false;
    print('Due payment alerts enabled: $duePaymentAlerts');
    if (!duePaymentAlerts) {
      print('Due payment alerts are disabled, skipping notification');
      return;
    }

    // Get all pending orders older than 1 minute
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('Orders')
        .where('status', isEqualTo: 'Pending')
        .get();

    if (ordersSnapshot.docs.isEmpty) {
      print('No pending orders found');
      return;
    }

    // Group orders by supplier
    Map<String, Map<String, dynamic>> pendingBySupplier = {};
    for (var orderDoc in ordersSnapshot.docs) {
      final orderData = orderDoc.data();
      final createdAt = orderData['createdAt'] as Timestamp?;
      if (createdAt == null) continue;

      // Check if the order is older than 1 minute
      final orderAge = DateTime.now().difference(createdAt.toDate());
      if (orderAge.inMinutes < 60) {
        print('Order ${orderDoc.id} is less than 1 minute old, skipping');
        continue;
      }

      final supplierId = orderData['supplierId'] as String?;
      if (supplierId == null) continue;

      // Fetch supplier details
      final supplierDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('Suppliers')
          .doc(supplierId)
          .get();
      if (!supplierDoc.exists) continue;

      final supplierData = supplierDoc.data()!;
      final supplierName = supplierData['name'] as String? ?? 'Unknown Seller';

      final purchaseAmount = (orderData['purchaseAmount'] as num?)?.toDouble() ?? 0.0;
      final paymentAmount = (orderData['paymentAmount'] as num?)?.toDouble() ?? 0.0;
      final remainingAmount = purchaseAmount - paymentAmount;

      if (pendingBySupplier.containsKey(supplierId)) {
        pendingBySupplier[supplierId]!['remainingAmount'] += remainingAmount;
        pendingBySupplier[supplierId]!['orderIds'].add(orderDoc.id);
      } else {
        pendingBySupplier[supplierId] = {
          'sellerName': supplierName,
          'remainingAmount': remainingAmount,
          'orderIds': [orderDoc.id],
          'supplierData': {...supplierData, 'id': supplierId},
        };
      }
    }

    if (pendingBySupplier.isEmpty) {
      print('No pending payments after filtering');
      return;
    }

    // Prepare pending payments list
    _pendingPayments.clear();
    pendingBySupplier.forEach((supplierId, data) {
      _pendingPayments.add({
        'sellerName': data['sellerName'],
        'remainingAmount': data['remainingAmount'].toStringAsFixed(2),
        'orderIds': data['orderIds'],
        'supplierData': data['supplierData'],
      });
    });

    // Send the notification for each group
    for (var payment in _pendingPayments) {
      final supplierId = payment['supplierData']['id'];
      final remainingAmount = double.parse(payment['remainingAmount']);

      // Check for existing unread notification to prevent duplicates
      final existingNotification = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'pending_payment')
          .where('read', isEqualTo: false)
          .where('supplierIds', arrayContains: supplierId)
          .where('message', isEqualTo: 'Your due amount is ${payment['remainingAmount']} for ${payment['sellerName']}')
          .get();

      if (existingNotification.docs.isNotEmpty) {
        print('Notification already exists for supplier ${payment['sellerName']} with due amount ${payment['remainingAmount']}');
        continue; // Skip if an unread notification already exists
      }

      await _sendPendingPaymentNotification(
        userId,
        payment['sellerName'],
        payment['remainingAmount'],
        payment['orderIds'],
        supplierId,
      );
    }

    // Show the dialog if not already showing and context is available
    if (!_isDialogShowing && context != null) {
      _showPendingPaymentNotificationDialog(context!);
    } else {
      print('Context is null or dialog is already showing, skipping dialog');
    }
  }

  // Send pending payment notification and store it in Firestore
  Future<void> _sendPendingPaymentNotification(
      String userId,
      String sellerName,
      String remainingAmount,
      List<String> orderIds,
      String supplierId,
      ) async {
    final message = 'Your due amount is $remainingAmount for $sellerName';
    print('Storing pending payment notification in Firestore: $message');

    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Pending Payment Alert',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'pending_payment',
        'orderIds': orderIds,
        'supplierIds': [supplierId],
      });
      print('Pending payment notification stored in Firestore');
    } catch (e) {
      print('Error storing notification in Firestore: $e');
    }
  }

  // Existing low stock methods (unchanged)
  void _showLowStockNotificationDialog(BuildContext context) {
    if (_pendingLowStockProducts.isEmpty || _isDialogShowing) return;

    _isDialogShowing = true;
    print('Showing low stock notification dialog');

    final message = _pendingLowStockProducts
        .map((product) => '${product['name']} has ${product['quantity']} units left')
        .join('\n');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Color(0xFFF97316), size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Low Stock Alert',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              _markNotificationsAsRead(context, 'low_stock');
              Navigator.pop(context);
            },
            child: const Text('Okay', style: TextStyle(color: Color(0xFF1E3A8A))),
          ),
        ],
      ),
    ).then((_) {
      _isDialogShowing = false;
      _pendingLowStockProducts.clear();
    });
  }

  Future<void> checkAndSendLowStockNotification(
      BuildContext context,
      String productId,
      String productName,
      int quantity,
      String userId,
      ) async {
    print('Checking low stock for product: $productId, quantity: $quantity (previous: ${_previousStockLevels[productId]})');

    final previousQuantity = _previousStockLevels[productId] ?? quantity;
    _previousStockLevels[productId] = quantity;

    if (!(previousQuantity == 6 && quantity == 5)) {
      print('Not a 6→5 transition, skipping notification');
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .get();
    final lowStockAlerts = userDoc.data()?['lowStockAlerts'] as bool? ?? false;
    print('Low stock alerts enabled: $lowStockAlerts');
    if (!lowStockAlerts) {
      print('Low stock alerts are disabled, skipping notification');
      return;
    }

    _pendingLowStockProducts.add({
      'id': productId,
      'name': productName,
      'quantity': quantity,
    });

    print('Sending low stock notification for $productName');
    await _sendLowStockNotification(context, productId, productName, userId, quantity);

    if (!_isDialogShowing) {
      _showLowStockNotificationDialog(context);
    }
  }

  Future<void> _sendLowStockNotification(
      BuildContext context,
      String productId,
      String productName,
      String userId,
      int quantity,
      ) async {
    final message = 'Low Stock Alert: $productName has $quantity units left';
    print('Storing notification in Firestore: $message');

    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Low Stock Alert',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'low_stock',
        'productId': productId,
        'quantity': quantity,
      });
      print('Notification stored in Firestore');
    } catch (e) {
      print('Error storing notification in Firestore: $e');
    }
  }

  // Temporary context holder (to be set by dashboard.dart)
  static BuildContext? context;

  // Method to set context from dashboard.dart
  void setContext(BuildContext ctx) {
    context = ctx;
    // Start the timer only after context is set
    _startPeriodicScanning();
  }
}