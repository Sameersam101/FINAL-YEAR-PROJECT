import 'package:arthikapp/Screens/analyticspage.dart';
import 'package:arthikapp/Screens/inventorypage.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:arthikapp/Screens/dashboard.dart';
import 'package:arthikapp/Screens/transaction.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _isBarCodeSelected = false;
  File? _image;
  String _recognizedText = '';
  Map<String, dynamic>? _previewData;
  final ImagePicker _picker = ImagePicker();
  final List<Map<String, dynamic>> _scannedProducts = [];
  int _selectedIndex = 2;
  final List<Map<String, TextEditingController>> _controllers = [];
  bool _isProcessingBarcode = false;


  @override
  void initState() {
    super.initState();
    for (var product in _scannedProducts) {
      _controllers.add({
        'name': TextEditingController(text: product['name']?.toString() ?? ''),
        'price': TextEditingController(text: product['price']?.toString() ?? ''),
        'quantity': TextEditingController(text: product['quantity']?.toString() ?? ''),
        'category': TextEditingController(text: product['category']?.toString() ?? ''),
      });
    }
  }

  @override
  void dispose() {
    for (var controllerMap in _controllers) {
      controllerMap['name']?.dispose();
      controllerMap['price']?.dispose();
      controllerMap['sellingPrice']?.dispose();
      controllerMap['quantity']?.dispose();
      controllerMap['category']?.dispose();
    }
    super.dispose();
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
        break;
      case 3:
        Navigator.pushReplacement(context, _createRoute(const Transactionpage()));
        break;
      case 4:
        Navigator.pushReplacement(context, _createRoute(const AnalyticsPage()));
        break;
    }
  }

  Future<bool> _requestPermissions(ImageSource source) async {
    if (source == ImageSource.camera) {
      var cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission denied. Please enable it in settings.')),
          );
        }
        setState(() => _recognizedText = 'Camera permission denied.');
        return false;
      }
      return true;
    } else {
      var storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        var photosStatus = await Permission.photos.request();
        if (!photosStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gallery permission denied. Please enable it in settings.')),
            );
          }
          setState(() => _recognizedText = 'Gallery permission denied.');
          return false;
        }
      }
      return true;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    bool hasPermission = await _requestPermissions(source);
    if (!hasPermission) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _recognizedText = 'Processing bill...';
          _previewData = null;
        });
        await _processBillImageWithGemini();
      } else {
        setState(() => _recognizedText = 'No image selected.');
      }
    } catch (e) {
      setState(() => _recognizedText = 'Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _processBillImageWithGemini() async {
    if (_image == null) return;

    try {
      const String apiKey = 'AIzaSyCmmdMeGP0MsgmJDnFygeINfCQqcliEL6s';
      const String apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

      final bytes = await _image!.readAsBytes();
      final base64Image = base64Encode(bytes);

      const prompt = '''
Extract product information from this image of a receipt or invoice. Return the result in the following JSON format:
{
  "products": [
    {"name": "Product Name", "quantity": 1, "amount": 10.0},
    ...
  ],
  "total_amount": 100.0
}
- "products" should be a list of objects, each containing "name" (string), "quantity" (integer), and "amount" (float, representing the total price for that product).
- "total_amount" should be a float representing the sum of all product amounts.
- If a product name, quantity, or amount is unclear, use reasonable defaults (e.g., "Unknown Item" for name, 1 for quantity, 0.0 for amount).
- If the total amount is not found, calculate it as the sum of the product amounts.
- Ensure the response is a valid JSON object with no additional text, markdown, or formatting (e.g., do not wrap in ```json ... ```).
''';

      final requestBody = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inlineData': {
                  'mimeType': 'image/jpeg',
                  'data': base64Image,
                },
              },
            ],
          },
        ],
      });

      final response = await http.post(
        Uri.parse('$apiUrl?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final resultText = responseData['candidates']?[0]['content']['parts']?[0]['text'] ?? '';

        String cleanedText = resultText.trim();
        if (cleanedText.startsWith('```json') && cleanedText.endsWith('```')) {
          cleanedText = cleanedText.substring(7, cleanedText.length - 3).trim();
        } else if (cleanedText.startsWith('```') && cleanedText.endsWith('```')) {
          cleanedText = cleanedText.substring(3, cleanedText.length - 3).trim();
        }

        try {
          final result = jsonDecode(cleanedText);

          if (result is! Map<String, dynamic> ||
              !result.containsKey('products') ||
              !result.containsKey('total_amount')) {
            throw FormatException('Invalid JSON structure: Missing required fields');
          }

          double calculatedTotal = 0.0;
          for (var item in result['products']) {
            double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
            calculatedTotal += amount;
          }

          Map<String, int> quantities = {};
          List<Map<String, dynamic>> products = [];
          for (var item in result['products']) {
            String name = item['name']?.toString() ?? 'Unknown Item';
            int quantity = item['quantity']?.toInt() ?? 1;
            double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
            quantities[name] = quantity;
            products.add({
              'name': name,
              'quantity': quantity,
              'amount': amount,
            });
          }

          setState(() {
            _previewData = {
              'date': DateTime.now().toIso8601String(),
              'amount': calculatedTotal,
              'quantities': quantities,
              'products': products,
              'dateTime': DateTime.now(),
              'type': 'expense',
            };
            _recognizedText = 'Bill processed successfully';
          });
        } catch (e) {
          setState(() => _recognizedText = 'Error parsing JSON response: $e\nRaw response: $cleanedText');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error parsing JSON response: $e')),
            );
          }
        }
      } else {
        setState(() => _recognizedText = 'Error processing bill: Server returned ${response.statusCode}\nResponse: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error processing bill: Server returned ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      setState(() => _recognizedText = 'Error processing bill: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing bill: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImageToSupabase(File image) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(image.path).toLowerCase();
      final fileName = '${user.uid}/receipt_$timestamp$extension';

      await Supabase.instance.client.storage
          .from('receipts')
          .upload(fileName, image, fileOptions: FileOptions(
        contentType: 'image/${extension.replaceAll('.', '')}',
      ));

      final imageUrl = Supabase.instance.client.storage
          .from('receipts')
          .getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image upload failed: $e')),
          );
        });
      }
      return null;
    }
  }

  Future<void> _scanBarcode() async {
    try {
      setState(() => _isProcessingBarcode = true);

      var cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        setState(() {
          _recognizedText = 'Camera permission denied.';
          _isProcessingBarcode = false;
        });
        return;
      }

      ScanResult? scanResult;
      for (int i = 0; i < 2; i++) {
        scanResult = await BarcodeScanner.scan(
          options: ScanOptions(
            restrictFormat: [],
            useCamera: -1,
            autoEnableFlash: false,
            android: AndroidOptions(aspectTolerance: 0.00, useAutoFocus: true),
          ),
        );
        if (scanResult != null && scanResult.rawContent.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (scanResult == null || scanResult.rawContent.isEmpty) {
        setState(() {
          _recognizedText = 'Scan canceled or failed';
          _isProcessingBarcode = false;
        });
        return;
      }

      String barcodeContent = scanResult.rawContent;
      setState(() => _recognizedText = 'Processing barcode...');

      Map<String, dynamic> productData = await _fetchProductFromBarcodeMonster(barcodeContent);
      bool noData = productData['name'] == 'Unknown';
      if (noData) {
        productData = await _fetchFromOpenFoodFacts(barcodeContent);
        noData = productData['name'] == 'Unknown';
      }

      setState(() {
        _scannedProducts.add({
          'barcode': barcodeContent,
          'name': noData ? '' : productData['name'],
          'price': noData ? 0.0 : productData['price'],
          'quantity': 1,
          'sellingPrice': noData ? 0.0 : (productData['price']),
          'category': noData ? '' : productData['category'],
        });
        _controllers.add({
          'name': TextEditingController(text: noData ? '' : productData['name']),
          'price': TextEditingController(text: noData ? '' : productData['price'].toString()),
          'quantity': TextEditingController(text: '1'),
          'sellingPrice': TextEditingController(
            text: noData ? '0.0' : (productData['price']).toStringAsFixed(2),
          ),
          'category': TextEditingController(text: noData ? '' : productData['category']),
        });
        _recognizedText = 'Scanned barcode: $barcodeContent';
        _isProcessingBarcode = false;
      });
    } catch (e) {
      setState(() => _recognizedText = 'Error scanning barcode: $e');
      _isProcessingBarcode = false;
    }
  }

  Future<Map<String, dynamic>> _fetchProductFromBarcodeMonster(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('https://barcode-monster.p.rapidapi.com/barcode/$barcode'),
        headers: {
          'X-RapidAPI-Key': 'fbfc9f2f00msh87f9862ae9593f4p1c06b5jsnf0803d0a1925',
          'X-RapidAPI-Host': 'barcode-monster.p.rapidapi.com',
        },
      );
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return {
          'name': data['name'] ?? 'Unknown',
          'price': double.tryParse(data['price']?.toString() ?? '0.0') ?? 0.0,
          'category': data['category'] ?? 'Uncategorized',
        };
      } else {
        return {'name': 'Unknown', 'price': 0.0, 'category': 'Uncategorized'};
      }
    } catch (e) {
      return {'name': 'Unknown', 'price': 0.0, 'category': 'Uncategorized'};
    }
  }

  Future<Map<String, dynamic>> _fetchFromOpenFoodFacts(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json'),
      );
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          var product = data['product'];
          return {
            'name': product['product_name'] ?? 'Unknown',
            'price': 0.0,
            'category': product['categories']?.split(',').first ?? 'Uncategorized',
          };
        }
        return {'name': 'Unknown', 'price': 0.0, 'category': 'Uncategorized'};
      } else {
        return {'name': 'Unknown', 'price': 0.0, 'category': 'Uncategorized'};
      }
    } catch (e) {
      return {'name': 'Unknown', 'price': 0.0, 'category': 'Uncategorized'};
    }
  }

  void _showDeleteConfirmationDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Confirm Deletion',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E3A8A),
          ),
        ),
        content: Text(
          'Are you sure you want to delete this product?',
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
              _deleteProduct(index);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(int index) {
    try {
      if (index < 0 || index >= _scannedProducts.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Invalid product index')),
        );
        return;
      }
      setState(() {
        _controllers[index]['name']?.dispose();
        _controllers[index]['price']?.dispose();
        _controllers[index]['quantity']?.dispose();
        _controllers[index]['category']?.dispose();
        _controllers.removeAt(index);
        _scannedProducts.removeAt(index);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting product: $e')),
      );
    }
  }

  Future<void> _saveTransactionAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User not logged in',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    if (_previewData == null ||
        _previewData!['products'] == null ||
        (_previewData!['products'] as List<dynamic>).isEmpty ||
        _previewData!['amount'] == null ||
        (_previewData!['amount'] as num) <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No products or invalid amount',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFF97316))),
    );

    try {
      String? imageUrl;
      String description = _formatProductsWithQuantities(_previewData!['quantities']);
      if (description == "None") {
        description = "Unknown";
      }

      final transactionRef = FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('transactions')
          .doc();

      await transactionRef.set({
        'amount': _previewData!['amount'],
        'createdAt': Timestamp.fromDate(_previewData!['dateTime']),
        'date': Timestamp.fromDate(_previewData!['dateTime']),
        'quantities': _previewData!['quantities'],
        'products': _previewData!['products'],
        'type': 'expense',
        'userId': user.uid,
        'imageUrl': '',
        'description': description,
      });

      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          _createRoute(const Transactionpage()),
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Bill saved successfully',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: const Color(0xFFF97316),
            ),
          );
        }
      });

      if (_image != null) {
        imageUrl = await _uploadImageToSupabase(_image!);
        if (imageUrl != null) {
          await transactionRef.update({'imageUrl': imageUrl});
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e')),
        );
      }
    }
  }

  Future<void> _saveScannedProducts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _scannedProducts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No products to save or user not logged in')),
        );
      }
      return;
    }

    bool isValid = true;
    for (var i = 0; i < _scannedProducts.length; i++) {
      var controller = _controllers[i];
      String name = controller['name']!.text;
      String priceText = controller['price']!.text;
      String sellingPriceText = controller['sellingPrice']!.text;
      String quantityText = controller['quantity']!.text;
      String category = controller['category']!.text;

      if (name.isEmpty || name.length < 2) {
        isValid = false;
      }
      if (priceText.isEmpty || (double.tryParse(priceText) ?? 0.0) <= 0.0) {
        isValid = false;
      }
      if (sellingPriceText.isEmpty || (double.tryParse(sellingPriceText) ?? 0.0) <= 0.0) {
        isValid = false;
      }
      if (quantityText.isEmpty || (int.tryParse(quantityText) ?? 0) < 1) {
        isValid = false;
      }
      if (category.isEmpty || category.length < 2) {
        isValid = false;
      }
    }

    if (!isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please fill all required fields correctly',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
      return;
    }
    try {
      final batch = FirebaseFirestore.instance.batch();
      int addedCount = 0;

      for (var i = 0; i < _scannedProducts.length; i++) {
        var product = _scannedProducts[i];
        var controller = _controllers[i];

        String name = controller['name']!.text;
        double price = double.tryParse(controller['price']!.text) ?? 0.0;
        double sellingPrice = double.tryParse(controller['sellingPrice']!.text) ?? 0.0;
        int quantity = int.tryParse(controller['quantity']!.text) ?? 1;
        String category = controller['category']!.text;

        _scannedProducts[i]['name'] = name;
        _scannedProducts[i]['price'] = price;
        _scannedProducts[i]['sellingPrice'] = sellingPrice;
        _scannedProducts[i]['quantity'] = quantity;
        _scannedProducts[i]['category'] = category;

        final inventoryRef = FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .collection('Inventory')
            .doc();

        batch.set(inventoryRef, {
          'type': 'in',
          'productName': name,
          'category': category.toLowerCase(),
          'quantity': quantity,
          'price': price,
          'sellingPrice': sellingPrice,
          'date': Timestamp.fromDate(DateTime.now()),
          'createdAt': FieldValue.serverTimestamp(),
          'userId': user.uid,
          'barcode': product['barcode'],
        });
        addedCount++;
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$addedCount product(s) added to inventory'), backgroundColor: const Color(0xFF10B981),),
        );

        Navigator.pushReplacement(
          context,
          _createRoute(const DashboardPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving products: $e')),
        );
      }
    }
  }

  String _formatProductsWithQuantities(Map<String, int> quantities) {
    if (quantities.isEmpty) return "None";
    return quantities.entries
        .map((e) => '${e.key} (${e.value})')
        .join(', ');
  }

  Widget _buildTransactionPreview() {
    final mediaQuery = MediaQuery.of(context);
    final products = _previewData?['products'] as List<dynamic>? ?? [];
    final totalAmount = _previewData?['amount'] ?? 0.0;
    final dateTime = _previewData?['dateTime'] ?? DateTime.now();

    return Column(
      children: [
        SizedBox(height: mediaQuery.size.height * 0.02),
        Text(
          'Transaction Preview',
          style: GoogleFonts.inter(
            fontSize: mediaQuery.size.width * 0.045,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF221E22),
          ),
        ),
        SizedBox(height: mediaQuery.size.height * 0.01),
        Card(
          elevation: 4,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Colors.blueGrey.withOpacity(0.1),
              width: 1,
            ),
          ),
          margin: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.01),
          child: Padding(
            padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...products.map((product) {
                  final name = product['name']?.toString() ?? 'Unknown Item';
                  final quantity = product['quantity']?.toString() ?? '1';
                  final amount = (product['amount'] as num?)?.toDouble() ?? 0.0;

                  return Padding(
                    padding: EdgeInsets.only(bottom: mediaQuery.size.height * 0.015),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: mediaQuery.size.width * 0.04,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF221E22),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$quantity x \रु ${amount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: mediaQuery.size.width * 0.035,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                Divider(color: Colors.grey[300], height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cash Out',
                          style: GoogleFonts.inter(
                            fontSize: mediaQuery.size.width * 0.035,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(height: mediaQuery.size.height * 0.005),
                        Text(
                          DateFormat('dd MMM, HH:mm').format(dateTime),
                          style: GoogleFonts.inter(
                            fontSize: mediaQuery.size.width * 0.03,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '-\रु ${totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: mediaQuery.size.width * 0.045,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: mediaQuery.size.height * 0.03),
        Center(
          child: ElevatedButton(
            onPressed: _saveTransactionAndNavigate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: mediaQuery.size.width * 0.1,
                vertical: mediaQuery.size.height * 0.02,
              ),
            ),
            child: Text(
              'Save & View Transactions',
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.04,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed}) {
    final mediaQuery = MediaQuery.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(mediaQuery.size.width * 0.02),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: mediaQuery.size.width * 0.06,
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, bool isSelected, {required VoidCallback onPressed}) {
    final mediaQuery = MediaQuery.of(context);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFF3F4F6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFD1D5DB),
            width: 1.5,
          ),
        ),
        padding: EdgeInsets.symmetric(
          vertical: mediaQuery.size.height * 0.015,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: mediaQuery.size.width * 0.04,
          color: isSelected ? Colors.white : const Color(0xFF6B7280),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildImageSourceButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    final mediaQuery = MediaQuery.of(context);
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.all(mediaQuery.size.width * 0.03),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1E3A8A),
              size: mediaQuery.size.width * 0.05,
            ),
          ),
        ),
        SizedBox(height: mediaQuery.size.height * 0.01),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: mediaQuery.size.width * 0.030,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF6B7280).withOpacity(0.5)),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildIconButton(
                            icon: Icons.arrow_back_rounded,
                            onPressed: () => Navigator.pushReplacement(
                                context,
                                _createRoute(const DashboardPage())
                            ),
                          ),
                          SizedBox(width: mediaQuery.size.width * 0.03),
                          Text(
                            'Scanner',
                            style: GoogleFonts.inter(
                              fontSize: mediaQuery.size.width * 0.06,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.05),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildModeButton(
                          'BAR CODE',
                          _isBarCodeSelected,
                          onPressed: () {
                            setState(() {
                              _isBarCodeSelected = true;
                              _image = null;
                              _recognizedText = '';
                              _previewData = null;
                              _scannedProducts.clear();
                              _controllers.clear();
                            });
                          },
                        ),
                      ),
                      SizedBox(width: mediaQuery.size.width * 0.03),
                      Expanded(
                        child: _buildModeButton(
                          'BILL SCAN',
                          !_isBarCodeSelected,
                          onPressed: () {
                            setState(() {
                              _isBarCodeSelected = false;
                              _image = null;
                              _recognizedText = '';
                              _previewData = null;
                              _scannedProducts.clear();
                              _controllers.clear();
                            });
                          },
                        ),
                      ),
                    ],
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
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(mediaQuery.size.width * 0.05),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isBarCodeSelected) ...[
                            Container(
                              height: mediaQuery.size.height * 0.25,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code_scanner_rounded,
                                      size: mediaQuery.size.width * 0.15,
                                      color: const Color(0xFF6B7280),
                                    ),
                                    SizedBox(height: mediaQuery.size.height * 0.02),
                                    ElevatedButton(
                                      onPressed: _scanBarcode,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E3A8A),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: mediaQuery.size.width * 0.08,
                                          vertical: mediaQuery.size.height * 0.015,
                                        ),
                                      ),
                                      child: Text(
                                        'Scan Barcode',
                                        style: GoogleFonts.inter(
                                          fontSize: mediaQuery.size.width * 0.04,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: mediaQuery.size.height * 0.02),
                            if (_recognizedText.isNotEmpty)
                              Container(
                                padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Status: $_recognizedText',
                                  style: GoogleFonts.inter(
                                    fontSize: mediaQuery.size.width * 0.035,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            if (_scannedProducts.isNotEmpty) ...[
                              SizedBox(height: mediaQuery.size.height * 0.02),
                              Text(
                                'Scanned Products',
                                style: GoogleFonts.inter(
                                  fontSize: mediaQuery.size.width * 0.045,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF221E22),
                                ),
                              ),
                              SizedBox(height: mediaQuery.size.height * 0.01),
                              ..._scannedProducts.asMap().entries.map((entry) {
                                int index = entry.key;
                                var product = entry.value;
                                var controller = _controllers[index];

                                return Card(
                                  elevation: 2,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  margin: EdgeInsets.symmetric(vertical: mediaQuery.size.height * 0.01),
                                  child: Padding(
                                    padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: _buildTextField(
                                                controller: controller['name']!,
                                                label: 'Name',
                                                hintText: product['name'].isEmpty ? 'Unknown' : null,
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
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444)),
                                              onPressed: () => _showDeleteConfirmationDialog(index),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: mediaQuery.size.height * 0.01),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildTextField(
                                                controller: controller['price']!,
                                                label: 'Price',
                                                hintText: product['price'] == 0.0 ? '0.0' : null,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                validator: (value) {
                                                  if (value == null || value.isEmpty) {
                                                    return 'Required';
                                                  }
                                                  final price = double.tryParse(value);
                                                  if (price == null || price <= 0.0) {
                                                    return 'Price must be greater than 0';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            SizedBox(width: mediaQuery.size.width * 0.01),
                                            Expanded(
                                              child: _buildTextField(
                                                controller: controller['sellingPrice']!,
                                                label: 'Selling Price',
                                                // hintText: product['Selling Price'] == 1 ? '1' : null,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                validator: (value) {
                                                  if (value == null || value.isEmpty) return 'Required';
                                                  final price = double.tryParse(value);
                                                  if (price == null || price <= 0.0) return 'Must be > 0';
                                                  return null;
                                                },
                                              ),
                                            ),
                                            SizedBox(width: mediaQuery.size.width * 0.01),
                                            Expanded(
                                              child: _buildTextField(
                                                controller: controller['quantity']!,
                                                label: 'Quantity',
                                                hintText: product['quantity'] == 1 ? '1' : null,
                                                keyboardType: TextInputType.number,
                                                validator: (value) {
                                                  if (value == null || value.isEmpty) {
                                                    return 'Required';
                                                  }
                                                  final quantity = int.tryParse(value);
                                                  if (quantity == null || quantity < 1) {
                                                    return 'Quantity must be at least 1';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: mediaQuery.size.height * 0.01),
                                        _buildTextField(
                                          controller: controller['category']!,
                                          label: 'Category',
                                          hintText: product['category'].isEmpty ? 'Uncategorized' : null,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Required';
                                            }
                                            if (value.length < 2) {
                                              return 'Category must be at least 2 characters';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              SizedBox(height: mediaQuery.size.height * 0.03),
                              Center(
                                child: ElevatedButton(
                                  onPressed: _saveScannedProducts,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF97316),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: mediaQuery.size.width * 0.1,
                                      vertical: mediaQuery.size.height * 0.02,
                                    ),
                                  ),
                                  child: Text(
                                    'Add to Inventory',
                                    style: GoogleFonts.inter(
                                      fontSize: mediaQuery.size.width * 0.04,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildImageSourceButton(
                                  icon: Icons.camera_alt_rounded,
                                  label: 'Camera',
                                  onPressed: () => _pickImage(ImageSource.camera),
                                ),
                                SizedBox(width: mediaQuery.size.width * 0.01),
                                _buildImageSourceButton(
                                  icon: Icons.photo_library_rounded,
                                  label: 'Gallery',
                                  onPressed: () => _pickImage(ImageSource.gallery),
                                ),
                              ],
                            ),
                            SizedBox(height: mediaQuery.size.height * 0.02),
                            if (_recognizedText.isNotEmpty)
                              Container(
                                padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
                                margin: EdgeInsets.only(top: mediaQuery.size.height * 0.02),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _recognizedText,
                                  style: GoogleFonts.inter(
                                    fontSize: mediaQuery.size.width * 0.035,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            if (_previewData != null) _buildTransactionPreview(),
                          ],
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
}