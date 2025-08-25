// mobile_products_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

// Enum to manage the current view state
enum ProductView {
  list,
  create,
  edit,
}

class MobileProductsScreen extends StatefulWidget {
  const MobileProductsScreen({super.key});

  @override
  _MobileProductsScreenState createState() => _MobileProductsScreenState();
}

class _MobileProductsScreenState extends State<MobileProductsScreen> {
  late Future<List<Map<String, String>>> _productsFuture;
  ProductView _currentView = ProductView.list; // Default view is the list
  Map<String, String>?
      _editingProduct; // Holds data of the product being edited

  // Controllers for the forms (add/edit)
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

  @override
  void initState() {
    super.initState();
    _fetchProductsData(); // Fetch products when the screen initializes
  }

  @override
  void dispose() {
    // Dispose of the controllers to free up resources
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
      _productsFuture = _fetchProducts();
    });
  }

  // Helper method to show a SnackBar message
  void _showSnackBar(BuildContext context, String message,
      {Color color = Colors.black}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
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

  // Function to handle Delete Product API Call
  Future<void> _deleteProduct(String productId) async {
    if (productId.isEmpty) {
      _showSnackBar(context, 'Product ID is missing for deletion.',
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

    // Show a confirmation dialog
    bool confirmDelete = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content:
                  const Text('Are you sure you want to delete this product?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ) ??
        false; // In case dialog is dismissed by tapping outside

    if (!confirmDelete) {
      return; // User cancelled the deletion
    }

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/products/delete/$productId'); // Fixed: Changed /user/ to /Products/
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Product deleted successfully!',
            color: Colors.green);
        _fetchProductsData(); // Refresh list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to delete product. Server error.',
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
          padding: const EdgeInsets.all(16.0),
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
                  setState(() {
                    _currentView = ProductView.create;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text(
                    'Add New Product'), // Changed "User" to "Product"
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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
            future: _productsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No products available.'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final product = snapshot.data![index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Generator Serial Number: ${product['generator_serial_number']}',
                                style: const TextStyle(fontSize: 16)),
                            Text(
                                'Generator Model Number: ${product['generator_model_number']}',
                                style: const TextStyle(fontSize: 16)),
                            Text(
                                'Engine Serial Number: ${product['engine_serial_number']}',
                                style: const TextStyle(fontSize: 16)),
                            Text(
                                'Engine Model Number: ${product['engine_model_number']}',
                                style: const TextStyle(fontSize: 16)),
                            Text(
                                'Alternator Serial Number: ${product['alt_serial_number']}',
                                style: const TextStyle(fontSize: 16)),
                            Text(
                                'Alternator Model Number: ${product['alt_model_number']}',
                                style: const TextStyle(fontSize: 16)),
                            Text(
                                'Controller Parts: ${product['controller_parts']}',
                                style: const TextStyle(fontSize: 16)),
                            Text(
                                'Controller Serial Number: ${product['controller_serial_number']}',
                                style: const TextStyle(fontSize: 16)),
                            Text('Remarks: ${product['remarks']}',
                                style: const TextStyle(fontSize: 16)),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () {
                                      setState(() {
                                        _editingProduct = product;
                                        _currentView = ProductView.edit;
                                        // Set controllers for editing
                                        _generator_serial_numberController
                                                .text =
                                            product['generator_serial_number']!;
                                        _generator_model_numberController.text =
                                            product['generator_model_number']!;
                                        _engine_serial_numberController.text =
                                            product['engine_serial_number']!;
                                        _engine_model_numberController.text =
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
                                  IconButton(
                                    // Add delete button
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () {
                                      _deleteProduct(product['id']!);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management'), // Changed "User" to "Product"
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _buildBodyContent(),
    );
  }

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
}
