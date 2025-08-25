// lib/screens/products/products.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
import '../../../widgets/sidebar_widget.dart';
import '../../../models/user_model.dart'; // Import the Product model

// Enum to manage the current view state
enum ProductView {
  list,
  create,
  edit,
  view, // Added new view state for single Product display
}

class WebProductScreen extends StatefulWidget {
  const WebProductScreen({super.key});

  @override
  _WebProductScreenState createState() => _WebProductScreenState();
}

class _WebProductScreenState extends State<WebProductScreen> {
  // Constants for layout (adapted from web_settings_country_screen.dart)
  static const double _kSidebarWidth = 256.0; // Width of the persistent sidebar
  static const double _kContentHorizontalPadding =
      20.0; // Padding around main content sections
  static const double _kWrapSpacing = 16.0; // Spacing between cards in Wrap
  static const double _kAppBarHeight = kToolbarHeight; // Standard AppBar height

  late Future<List<Map<String, String>>> _ProductsFuture;
  ProductView _currentView = ProductView.list; // Default view is the list
  Map<String, String>?
      _editingProduct; // Holds data of the Product being edited // Holds data of the Product being viewed

  final TextEditingController _generator_serial_numberController =
      TextEditingController();
  final TextEditingController _generator_model_numberController =
      TextEditingController();
  final TextEditingController _engine_serial_numberController =
      TextEditingController();
  final TextEditingController _engine_model_numberController =
      TextEditingController();
  final TextEditingController _alt_serial_numberController =
      TextEditingController();
  final TextEditingController _alt_model_numberController =
      TextEditingController();
  final TextEditingController _controller_partsController =
      TextEditingController();
  final TextEditingController _controller_serial_numberController =
      TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  User? _currentUser;

  // Key for Scaffold to control the Drawer (only used for small screens)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variable to control the visibility of the persistent sidebar on large screens
  bool _isSidebarOpen = true;

  @override
  void initState() {
    super.initState();
    _fetchProductsData();
  }

  @override
  void dispose() {
    _generator_serial_numberController.dispose();
    _generator_model_numberController.dispose();
    _engine_serial_numberController.dispose();
    _engine_model_numberController.dispose();
    _alt_serial_numberController.dispose();
    _alt_model_numberController.dispose();
    _controller_partsController.dispose();
    _controller_serial_numberController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _fetchProductsData() {
    setState(() {
      _ProductsFuture = _fetchProducts();
    });
  }

  // Helper method to show a SnackBar message
  void _showSnackBar(BuildContext context, String message,
      {Color color = Colors.black}) {
    // Check if the widget is still mounted before showing the SnackBar
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    await SharedPrefs.clearAll(); // Clear Product data and token
    // Navigate back to the login screen, removing all previous routes
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
    _showSnackBar(context, 'Logged out successfully!', color: Colors.green);
  }

  Future<List<Map<String, String>>> _fetchProducts() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        return [];
      }

      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/products/readall'); // Fixed: Changed /user/ to /Products/

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timeout - Server not responding.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['data'] is List) {
          List<Map<String, String>> products = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              products.add({
                'id': item['id']?.toString() ?? '',
                'generator_serial_number':
                    item['generator_serial_number'] as String? ?? '',
                'generator_model_number':
                    item['generator_model_number'] as String? ?? '',
                'engine_serial_number':
                    item['engine_serial_number'] as String? ?? '',
                'engine_model_number':
                    item['engine_model_number'] as String? ?? '',
                'alt_serial_number': item['alt_serial_number'] as String? ?? '',
                'alt_model_number': item['alt_model_number'] as String? ?? '',
                'controller_parts': item['controller_parts'] as String? ?? '',
                'controller_serial_number':
                    item['controller_serial_number'] as String? ?? '',
                'remarks': item['remarks'] as String? ?? '',
              });
            }
          }
          return products;
        } else {
          _showSnackBar(
              context, 'Failed to load products. Invalid data format.',
              color: Colors.red);
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to load Products. Server error.',
            color: Colors.red);
        return [];
      }
    } on SocketException {
      _showSnackBar(context, 'Network error. Check your internet connection.',
          color: Colors.red);
      return [];
    } on TimeoutException {
      _showSnackBar(context, 'Request timed out. Server not responding.',
          color: Colors.red);
      return [];
    } on FormatException {
      _showSnackBar(context, 'Invalid response format from server.',
          color: Colors.red);
      return [];
    } catch (e) {
      _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
          color: Colors.red);
      return [];
    }
  }

  // Function to handle Create Product API Call
  Future<void> _createProduct() async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    final String generatorSerialNumber =
        _generator_serial_numberController.text.trim();
    final String generatorModelNumber =
        _generator_model_numberController.text.trim();
    final String engineSerialNumber =
        _engine_serial_numberController.text.trim();
    final String engineModelNumber = _engine_model_numberController.text.trim();
    final String altSerialNumber = _alt_serial_numberController.text.trim();
    final String altModelNumber = _alt_model_numberController.text.trim();
    final String controllerParts = _controller_partsController.text.trim();
    final String controllerSerialNumber =
        _controller_serial_numberController.text.trim();
    final String remarks = _remarksController.text.trim();

    if (generatorSerialNumber.isEmpty || generatorModelNumber.isEmpty) {
      // Validate country
      _showSnackBar(context, 'Generator Serial and Model fields are required.',
          color: Colors.orange);
      return;
    }

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/products/create'); // Fixed: Changed /user/ to /Products/
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'generator_serial_number': generatorSerialNumber,
              'generator_model_number': generatorModelNumber,
              'engine_serial_number': engineSerialNumber,
              'engine_model_number': engineModelNumber,
              'alt_serial_number': altSerialNumber,
              'alt_model_number': altModelNumber,
              'controller_parts': controllerParts,
              'controller_serial_number': controllerSerialNumber,
              'remarks': remarks,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        _showSnackBar(context, 'Product created successfully!',
            color: Colors.green);
        // Clear controllers after successful creation
        _generator_serial_numberController.clear();
        _generator_model_numberController.clear();
        _engine_serial_numberController.clear();
        _engine_model_numberController.clear();
        _alt_serial_numberController.clear();
        _alt_model_numberController.clear();
        _controller_partsController.clear();
        _controller_serial_numberController.clear();
        _remarksController.clear();
        setState(() {
          _currentView = ProductView.list;
        });
        _fetchProductsData(); // Refresh list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to create product. Server error.',
            color: Colors.red);
      }
    } on SocketException {
      _showSnackBar(context, 'Network error. Check your internet connection.',
          color: Colors.red);
    } on TimeoutException {
      _showSnackBar(context, 'Request timed out. Server not responding.',
          color: Colors.red);
    } on FormatException {
      _showSnackBar(context, 'Invalid response format from server.',
          color: Colors.red);
    } catch (e) {
      _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
          color: Colors.red);
    }
  }

  // Function to handle Update Product API Call
  Future<void> _updateProduct(String productId) async {
    if (productId.isEmpty) {
      _showSnackBar(context, 'Product ID is missing for update.',
          color: Colors.red);
      return;
    }

    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    // These fields will send their current values (which might be empty if they were
    // originally empty from the backend, or if the user cleared them).
    // Backend should handle further validation for empty strings if required.
    final String generatorSerialNumber =
        _generator_serial_numberController.text.trim();
    final String generatorModelNumber =
        _generator_model_numberController.text.trim();
    final String engineSerialNumber =
        _engine_serial_numberController.text.trim();
    final String engineModelNumber = _engine_model_numberController.text.trim();
    final String altSerialNumber = _alt_serial_numberController.text.trim();
    final String altModelNumber = _alt_model_numberController.text.trim();
    final String controllerParts = _controller_partsController.text.trim();
    final String controllerSerialNumber =
        _controller_serial_numberController.text.trim();
    final String remarks = _remarksController.text.trim();

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/products/update/$productId'); // Fixed: Changed /user/ to /Products/
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'generator_serial_number': generatorSerialNumber,
              'generator_model_number': generatorModelNumber,
              'engine_serial_number': engineSerialNumber,
              'engine_model_number': engineModelNumber,
              'alt_serial_number': altSerialNumber,
              'alt_model_number': altModelNumber,
              'controller_parts': controllerParts,
              'controller_serial_number': controllerSerialNumber,
              'remarks': remarks,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Product updated successfully!',
            color: Colors.green);
        // Clear controllers after successful update
        _generator_serial_numberController.clear();
        _generator_model_numberController.clear();
        _engine_serial_numberController.clear();
        _engine_model_numberController.clear();
        _alt_serial_numberController.clear();
        _alt_model_numberController.clear();
        _controller_partsController.clear();
        _controller_serial_numberController.clear();
        _remarksController.clear();
        setState(() {
          _currentView = ProductView.list;
          _editingProduct = null; // Clear editing state
        });
        _fetchProductsData(); // Refresh list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to update product. Server error.',
            color: Colors.red);
      }
    } on SocketException {
      _showSnackBar(context, 'Network error. Check your internet connection.',
          color: Colors.red);
    } on TimeoutException {
      _showSnackBar(context, 'Request timed out. Server not responding.',
          color: Colors.red);
    } on FormatException {
      _showSnackBar(context, 'Invalid response format from server.',
          color: Colors.red);
    } catch (e) {
      _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
          color: Colors.red);
    }
  }

  Widget _buildListContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(_kContentHorizontalPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Products',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Clear controllers for new creation
                  _generator_serial_numberController.clear();
                  _generator_model_numberController.clear();
                  _engine_serial_numberController.clear();
                  _engine_model_numberController.clear();
                  _alt_serial_numberController.clear();
                  _alt_model_numberController.clear();
                  _controller_partsController.clear();
                  _controller_serial_numberController.clear();
                  _remarksController.clear();
                  if (!mounted) return; // Check mounted before setState
                  setState(() {
                    // Clear selected country for new Product
                    _currentView = ProductView.create;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add New Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF336EE5), // Primary color
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, String>>>(
            future: _ProductsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No Products available.'));
              } else {
                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0), // Apply 5px horizontal margin
                    child: Theme(
                      // Use Theme to apply DataTableThemeData
                      data: Theme.of(context).copyWith(
                        dataTableTheme: DataTableThemeData(
                          headingRowColor:
                              WidgetStateProperty.resolveWith<Color?>(
                                  (Set<WidgetState> states) {
                            return const Color(
                                0xFF336EE5); // Primary color for header
                          }),
                          headingTextStyle: const TextStyle(
                            color: Colors.white, // White text for header
                            fontWeight: FontWeight.bold,
                          ),
                          dataTextStyle: const TextStyle(
                            color: Colors.black87, // Dark text for body
                          ),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity, // Take full available width
                        child: DataTable(
                          columnSpacing: 12,
                          horizontalMargin: 12,
                          columns: const [
                            DataColumn(label: Text('Gen. S/N')),
                            DataColumn(label: Text('Gen. Model')),
                            DataColumn(label: Text('Eng. S/N')),
                            DataColumn(label: Text('Eng. Model')),
                            DataColumn(label: Text('Remarks')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: snapshot.data!.asMap().entries.map((entry) {
                            int index = entry.key;
                            Map<String, String> product = entry.value;

                            return DataRow(
                              color: WidgetStateProperty.resolveWith<Color?>(
                                (Set<WidgetState> states) {
                                  if (index % 2 == 0) {
                                    return Colors.white;
                                  }
                                  return Colors
                                      .grey[200]; // Light grey for odd rows
                                },
                              ),
                              cells: [
                                DataCell(
                                    Text(product['generator_serial_number']!)),
                                DataCell(
                                    Text(product['generator_model_number']!)),
                                DataCell(
                                    Text(product['engine_serial_number']!)),
                                DataCell(Text(product['engine_model_number']!)),
                                DataCell(Text(product['remarks']!)),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue),
                                        onPressed: () {
                                          setState(() {
                                            _editingProduct = product;
                                            _currentView = ProductView.edit;
                                            _generator_serial_numberController
                                                    .text =
                                                product[
                                                    'generator_serial_number']!;
                                            _generator_model_numberController
                                                    .text =
                                                product[
                                                    'generator_model_number']!;
                                            _engine_serial_numberController
                                                    .text =
                                                product[
                                                    'engine_serial_number']!;
                                            _engine_model_numberController
                                                    .text =
                                                product['engine_model_number']!;
                                            _alt_serial_numberController.text =
                                                product['alt_serial_number']!;
                                            _alt_model_numberController.text =
                                                product['alt_model_number']!;
                                            _controller_partsController.text =
                                                product['controller_parts']!;
                                            _controller_serial_numberController
                                                    .text =
                                                product[
                                                    'controller_serial_number']!;
                                            _remarksController.text =
                                                product['remarks']!;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreateContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Create New Product', // Changed "User" to "Product"
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _generator_serial_numberController,
            decoration: const InputDecoration(
              labelText: 'Generator Serial Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _generator_model_numberController,
            decoration: const InputDecoration(
              labelText: 'Generator Model Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _engine_serial_numberController,
            decoration: const InputDecoration(
              labelText: 'Engine Serial Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _engine_model_numberController,
            decoration: const InputDecoration(
              labelText: 'Engine Model Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _alt_serial_numberController,
            decoration: const InputDecoration(
              labelText: 'Alternator Serial Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _alt_model_numberController,
            decoration: const InputDecoration(
              labelText: 'Alternator Model Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _controller_partsController,
            decoration: const InputDecoration(
              labelText: 'Controller Parts',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _controller_serial_numberController,
            decoration: const InputDecoration(
              labelText: 'Controller Serial Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _remarksController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Remarks',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _createProduct,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Create Product',
                style: TextStyle(fontSize: 18)), // Changed "User" to "Product"
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              // Clear controllers and return to list view
              _generator_serial_numberController.clear();
              _generator_model_numberController.clear();
              _engine_serial_numberController.clear();
              _engine_model_numberController.clear();
              _alt_serial_numberController.clear();
              _alt_model_numberController.clear();
              _controller_partsController.clear();
              _controller_serial_numberController.clear();
              _remarksController.clear();
              setState(() {
                _currentView = ProductView.list;
              });
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditContent(Map<String, String> product) {
    // print('--- Entering _buildEditContent for Product ID: ${product['id']} ---');
    // print('Initial Product Data: $product');
    // Controllers are already populated when entering this view from onPressed of edit button.
    // No need for initialValue property here.

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit Product: ${product['generator_serial_number']}',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _generator_serial_numberController,
            decoration: const InputDecoration(
              labelText: 'Generator Serial Number',
              border: OutlineInputBorder(),
            ),
            // initialValue removed
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _generator_model_numberController,
            decoration: const InputDecoration(
              labelText: 'Generator Model Number',
              border: OutlineInputBorder(),
            ),
            // initialValue removed
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _engine_serial_numberController,
            decoration: const InputDecoration(
              labelText: 'Engine Serial Number',
              border: OutlineInputBorder(),
            ),
            // initialValue removed
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _engine_model_numberController,
            decoration: const InputDecoration(
              labelText: 'Engine Model Number',
              border: OutlineInputBorder(),
            ),
            // initialValue removed
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _alt_serial_numberController,
            decoration: const InputDecoration(
              labelText: 'Alternator Serial Number',
              border: OutlineInputBorder(),
            ),
            // initialValue removed
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _alt_model_numberController,
            decoration: const InputDecoration(
              labelText: 'Alternator Model Number',
              border: OutlineInputBorder(),
            ),
            // initialValue removed
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _controller_partsController,
            decoration: const InputDecoration(
              labelText: 'Controller Parts',
              border: OutlineInputBorder(),
            ),
            // initialValue removed
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _controller_serial_numberController,
            decoration: const InputDecoration(
              labelText: 'Controller Serial Number',
              border: OutlineInputBorder(),
            ),
            // initialValue removed
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _remarksController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Remarks',
              border: OutlineInputBorder(),
            ),
            // initialValue removed
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => _updateProduct(product['id']!),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Update Product',
                style: TextStyle(fontSize: 18)), // Changed "User" to "Product"
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              // Clear controllers and return to list view
              _generator_serial_numberController.clear();
              _generator_model_numberController.clear();
              _engine_serial_numberController.clear();
              _engine_model_numberController.clear();
              _alt_serial_numberController.clear();
              _alt_model_numberController.clear();
              _controller_partsController.clear();
              _controller_serial_numberController.clear();
              _remarksController.clear();
              setState(() {
                _currentView = ProductView.list;
                _editingProduct = null; // Clear editing state
              });
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader(bool isLargeScreen) {
    return Container(
      height: _kAppBarHeight, // Standard AppBar height
      decoration: const BoxDecoration(
        color: Color(0xFF336EE5), // Equivalent to bg-blue-800
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isSidebarOpen
                      ? CupertinoIcons.arrow_left_to_line
                      : CupertinoIcons.arrow_right_to_line,
                  color: Colors.white,
                  size: 18.0,
                ),
                onPressed: () {
                  if (!mounted) return; // Check mounted before setState
                  setState(() {
                    _isSidebarOpen = !_isSidebarOpen;
                  });
                },
              ),
              const SizedBox(width: 8),
              Image.asset(
                'images/logo.png', // Path to your logo image
                height: 40,
                fit: BoxFit.contain,
              ),
            ],
          ),
          // Navigation Links for large screens in Header
          Row(
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/web_superadmin-dashboard');
                },
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16)),
                child: const Text('Dashboard'),
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 40),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'Products',
                    child: Text('Products'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'support_team',
                    child: Text('Support Team'),
                  ),
                ],
                onSelected: (String value) {
                  if (value == 'Products') {
                    Navigator.of(context).pushNamed('/users');
                  } else if (value == 'support_team') {
                    Navigator.of(context).pushNamed('/support_team');
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        'Products',
                        style: TextStyle(color: Colors.white),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/reports');
                },
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16)),
                child: const Text('Reports'),
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 40),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'products',
                    child: Text('Products'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'assigned_products',
                    child: Text('Assigned Products'),
                  ),
                ],
                onSelected: (String value) {
                  if (value == 'products') {
                    Navigator.of(context).pushNamed('/products/products');
                  } else if (value == 'assigned_products') {
                    Navigator.of(context)
                        .pushNamed('/products/assigned_products');
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        'Products',
                        style: TextStyle(color: Colors.white),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),
              ),
              // Settings Dropdown for large screens
              PopupMenuButton<String>(
                offset: const Offset(0, 40),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'country_settings',
                    child: Text('Country'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'report_warning_settings',
                    child: Text('Report Warning'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'terms_settings',
                    child: Text('Terms'),
                  ),
                ],
                onSelected: (String value) {
                  if (value == 'country_settings') {
                    Navigator.of(context).pushNamed('/web_settings/country');
                  } else if (value == 'report_warning_settings') {
                    Navigator.of(context)
                        .pushNamed('/web_settings/report_warning');
                  } else if (value == 'terms_settings') {
                    Navigator.of(context).pushNamed('/web_settings/terms');
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(color: Colors.white),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),
              ),
              // Product Profile/Dropdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'profile',
                      child: Text('Profile'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child:
                          Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  onSelected: (String value) {
                    if (value == 'logout') {
                      _logout();
                    } else if (value == 'profile') {
                      Navigator.of(context).pushNamed('/profile');
                    } else if (value == 'settings') {
                      Navigator.of(context).pushNamed('/web_settings');
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle,
                          color: Colors.white, size: 32),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          _currentUser?.fullname ?? 'Admin',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Determine if it's a large screen (desktop/tablet) or small (mobile)
    final bool isLargeScreen = screenWidth > 768; // md:breakpoint in Tailwind

    return Scaffold(
      key: _scaffoldKey, // Assign the Scaffold key for drawer control
      // Conditionally show AppBar only for small screens
      appBar: isLargeScreen
          ? null // No AppBar on large screens
          : AppBar(
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF336EE5),
                ),
              ),
              title: Image.asset(
                'images/logo.png',
                height: 40,
                fit: BoxFit.contain,
              ),
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ),
      // Mobile Navigation Drawer (only for small screens)
      drawer: isLargeScreen
          ? null
          : Drawer(
              child: Container(
                color: const Color(0xFF1E293B),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    DrawerHeader(
                      decoration: const BoxDecoration(
                        color: Color(0xFF1D4ED8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.account_circle,
                              color: Colors.white, size: 60),
                          const SizedBox(height: 10),
                          Text(
                            _currentUser?.fullname ?? 'Admin',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18),
                          ),
                          Text(
                            _currentUser?.email ?? 'admin@example.com',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    _buildDrawerItem(Icons.dashboard, 'Dashboard', () {
                      Navigator.pop(context);
                      Navigator.of(context)
                          .pushNamed('/web_superadmin-dashboard');
                    }),
                    ExpansionTile(
                      leading: const Icon(Icons.people, color: Colors.white),
                      title: const Text('Products',
                          style: TextStyle(color: Colors.white)),
                      collapsedIconColor: Colors.white,
                      iconColor: Colors.white,
                      children: <Widget>[
                        _buildDrawerItem(Icons.people, 'Products', () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/Products');
                        }, isSubItem: true),
                        _buildDrawerItem(Icons.support_agent, 'Support Team',
                            () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/support_team');
                        }, isSubItem: true),
                      ],
                    ),
                    ExpansionTile(
                      leading: const Icon(Icons.category, color: Colors.white),
                      title: const Text('Products',
                          style: TextStyle(color: Colors.white)),
                      collapsedIconColor: Colors.white,
                      iconColor: Colors.white,
                      children: <Widget>[
                        _buildDrawerItem(Icons.category, 'Products', () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/products/products');
                        }, isSubItem: true),
                        _buildDrawerItem(
                            Icons.shopping_bag, 'Assigned Products', () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/products/assigned');
                        }, isSubItem: true),
                      ],
                    ),
                    _buildDrawerItem(Icons.bar_chart, 'Reports', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/reports');
                    }),
                    _buildDrawerItem(Icons.build, 'Maintenance', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/maintenance');
                    }),
                    ExpansionTile(
                      leading: const Icon(Icons.settings, color: Colors.white),
                      title: const Text('Settings',
                          style: TextStyle(color: Colors.white)),
                      collapsedIconColor: Colors.white,
                      iconColor: Colors.white,
                      children: <Widget>[
                        _buildDrawerItem(Icons.flag, 'Country', () {
                          Navigator.pop(context);
                          Navigator.of(context)
                              .pushNamed('/web_settings/country');
                        }, isSubItem: true),
                        _buildDrawerItem(Icons.warning, 'Report Warning', () {
                          Navigator.pop(context);
                          Navigator.of(context)
                              .pushNamed('/web_settings/report_warning');
                        }, isSubItem: true),
                        _buildDrawerItem(Icons.description, 'Terms', () {
                          Navigator.pop(context);
                          Navigator.of(context)
                              .pushNamed('/web_settings/terms');
                        }, isSubItem: true),
                      ],
                    ),
                    const Divider(color: Colors.white54),
                    _buildDrawerItem(Icons.logout, 'Logout', () {
                      Navigator.pop(context);
                      _logout();
                    }, textColor: Colors.red),
                  ],
                ),
              ),
            ),
      body: isLargeScreen
          ? Row(
              children: [
                // Persistent Full-Height Sidebar for large screens
                WebSuperAdminSidebar(
                  isOpen: _isSidebarOpen,
                  width: _kSidebarWidth,
                  onDashboardTap: () {
                    Navigator.of(context)
                        .pushNamed('/web_superadmin-dashboard');
                  },
                  onUsersTap: () {
                    Navigator.of(context).pushNamed('/Products');
                  },
                  onSupportTap: () {
                    Navigator.of(context).pushNamed('/support_team');
                  },
                  onProductsManageTap: () {
                    Navigator.of(context).pushNamed('/products/products');
                  },
                  onAssignedProductsTap: () {
                    Navigator.of(context)
                        .pushNamed('/products/assigned_products');
                  },
                  onReportsTap: () {
                    Navigator.of(context).pushNamed('/reports');
                  },
                  onMaintenanceTap: () {
                    Navigator.of(context).pushNamed('/maintenance');
                  },
                  onCountrySettingsTap: () {
                    Navigator.of(context).pushNamed('/web_settings/country');
                  },
                  onReportWarningSettingsTap: () {
                    Navigator.of(context)
                        .pushNamed('/web_settings/report_warning');
                  },
                  onTermsSettingsTap: () {
                    Navigator.of(context).pushNamed('/web_settings/terms');
                  },
                ),
                // Add a SizedBox for spacing only if the sidebar is open
                if (_isSidebarOpen) const SizedBox(width: 0.0),
                // Main Content Area with Custom Header
                Expanded(
                  child: Column(
                    children: [
                      // Custom Header
                      _buildCustomHeader(isLargeScreen),
                      // Main Scrollable Content
                      Expanded(
                        child:
                            _buildBodyContent(), // Delegates to the content builder
                      ),
                    ],
                  ),
                ),
              ],
            )
          : // Small Screen Layout (existing Scaffold with AppBar and Drawer)
          _buildBodyContent(), // Delegates to the content builder
    );
  }

  // A single method to return the appropriate content based on _currentView
  Widget _buildBodyContent() {
    switch (_currentView) {
      case ProductView.list:
        return _buildListContent();
      case ProductView.create:
        return _buildCreateContent();
      case ProductView.edit:
        return _buildEditContent(_editingProduct!);
      default:
        return _buildListContent(); // Fallback to list view
    }
  }

  // Helper method for building drawer items (similar to sidebar but separate for clarity)
  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap,
      {Color textColor = Colors.white, bool isSubItem = false}) {
    return ListTile(
      contentPadding:
          EdgeInsets.only(left: isSubItem ? 32.0 : 8.0), // Indent sub-items
      minLeadingWidth: 0, // Set minimum leading width to 0
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      onTap: onTap,
      tileColor: const Color(0xFF1E293B), // Dark background for drawer items
      selectedTileColor: const Color(0xFF2563EB), // blue-600
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
