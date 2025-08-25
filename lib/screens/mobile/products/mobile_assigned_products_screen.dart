// lib/screens/assigned_products/mobile_assigned_products_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
// Import the new screen for navigation
import '../maintenance_plan/mobile_maintenance_plan_screen.dart'; // Assuming path

// Enum to manage the current view state
enum AssignedProductView {
  list,
  create,
  edit,
}

class MobileAssignedProductsScreen extends StatefulWidget {
  const MobileAssignedProductsScreen({super.key});

  @override
  _MobileAssignedProductsScreenState createState() =>
      _MobileAssignedProductsScreenState();
}

class _MobileAssignedProductsScreenState
    extends State<MobileAssignedProductsScreen> {
  late Future<List<Map<String, String>>> _assignedProductsFuture;
  late Future<List<Map<String, String>>> _productsFuture;
  late Future<List<Map<String, String>>> _customersFuture;

  AssignedProductView _currentView = AssignedProductView.list;
  Map<String, String>? _editingAssignedProduct;

  // Controllers for the forms
  String? _selectedGeneratorSerialNumber;
  String? _selectedCustomerId;
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _gantryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _levelController.dispose();
    _gantryController.dispose();
    super.dispose();
  }

  void _fetchInitialData() {
    setState(() {
      _assignedProductsFuture = _fetchAssignedProducts();
      _productsFuture = _fetchProducts();
      _customersFuture =
          _fetchUsers(roles: ['localcustomer', 'globalcustomer']);
    });
  }

  void _showSnackBar(BuildContext context, String message,
      {Color color = Colors.black}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<List<Map<String, String>>> _fetchAssignedProducts() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        return [];
      }

      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/customer-products/readall');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['data'] is List) {
          List<Map<String, String>> assignedProducts = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              assignedProducts.add({
                'id': item['id']?.toString() ?? '',
                'generator_serial_number':
                    item['generator_serial_number'] as String? ?? '',
                'customer_id': item['customer_id']?.toString() ?? '',
                'customer_username': item['customer_username'] as String? ??
                    'N/A', // Assuming backend provides this
                'level': item['level'] as String? ?? '',
                'gantry': item['gantry'] as String? ?? '',
              });
            }
          }
          return assignedProducts;
        } else {
          _showSnackBar(
              context, 'Failed to load assigned products. Invalid data format.',
              color: Colors.red);
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to load assigned products. Server error.',
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

  Future<List<Map<String, String>>> _fetchProducts() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        return [];
      }

      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/products/unassign-readall');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

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
              });
            }
          }
          return products;
        } else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, String>>> _fetchUsers({List<String>? roles}) async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        return [];
      }

      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/users/readall');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['data'] is List) {
          List<Map<String, String>> users = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              final userRole = item['role'] as String? ?? '';
              if (roles == null || roles.contains(userRole)) {
                users.add({
                  'id': item['id']?.toString() ?? '',
                  'username': item['username'] as String? ?? '',
                  'role': userRole,
                });
              }
            }
          }
          return users;
        } else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<void> _createAssignedProduct() async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    if (_selectedGeneratorSerialNumber == null ||
        _selectedCustomerId == null ||
        _levelController.text.isEmpty ||
        _gantryController.text.isEmpty) {
      _showSnackBar(context, 'All fields are required.', color: Colors.orange);
      return;
    }

    try {
      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/customer-products/assign');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'generator_serial_number': _selectedGeneratorSerialNumber,
              'customer_id': _selectedCustomerId,
              'level': _levelController.text.trim(),
              'gantry': _gantryController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        _showSnackBar(context, 'Assigned Product created successfully!',
            color: Colors.green);
        _clearControllers();
        setState(() {
          _currentView = AssignedProductView.list;
        });
        _fetchInitialData();
        final serialnumberdata = json.decode(response.body);
        // Check for null before navigating
        if (serialnumberdata['generator_serial_number'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MobileMaintenancePlanScreen(
                  generatorSerialNumber:
                      serialnumberdata['generator_serial_number']!),
            ),
          );
        } else {
          // Handle the null case, e.g., show an error or log it
          _showSnackBar(context, 'Error: Generator serial number is missing.',
              color: Colors.red);
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to create assigned product. Server error.',
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

  Future<void> _updateAssignedProduct(String assignedProductId) async {
    if (assignedProductId.isEmpty) {
      _showSnackBar(context, 'Assigned Product ID is missing for update.',
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

    if (_selectedGeneratorSerialNumber == null ||
        _selectedCustomerId == null ||
        _levelController.text.isEmpty ||
        _gantryController.text.isEmpty) {
      _showSnackBar(context, 'All fields are required.', color: Colors.orange);
      return;
    }

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/assigned_products/update/$assignedProductId');
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'generator_serial_number': _selectedGeneratorSerialNumber,
              'customer_id': _selectedCustomerId,
              'level': _levelController.text.trim(),
              'gantry': _gantryController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Assigned Product updated successfully!',
            color: Colors.green);
        _clearControllers();
        setState(() {
          _currentView = AssignedProductView.list;
          _editingAssignedProduct = null;
        });
        _fetchInitialData();
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to update assigned product. Server error.',
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

  Future<void> _deleteAssignedProduct(String assignedProductId) async {
    if (assignedProductId.isEmpty) {
      _showSnackBar(context, 'Assigned Product ID is missing for deletion.',
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

    bool confirmDelete = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: const Text(
                  'Are you sure you want to delete this assigned product?'),
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
        false;

    if (!confirmDelete) {
      return;
    }

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/customer-products/delete/$assignedProductId');
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Assigned Product deleted successfully!',
            color: Colors.green);
        _fetchInitialData();
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to delete assigned product. Server error.',
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

  void _clearControllers() {
    _selectedGeneratorSerialNumber = null;
    _selectedCustomerId = null;
    _levelController.clear();
    _gantryController.clear();
  }

  Widget _buildListContent() {
    // 1. Mark the method as async
    return FutureBuilder<String?>(
      // Use FutureBuilder to handle async UserRole fetching
      future: SharedPrefs.getUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final String? userRole =
            snapshot.data; // Get the user role from the snapshot

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Assigned Products',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  // 2. Use collection if and correct list comparison
                  if (userRole != null &&
                      ['superadmin', 'admin', 'supervisor'].contains(userRole))
                    ElevatedButton.icon(
                      onPressed: () {
                        _clearControllers();
                        setState(() {
                          _currentView = AssignedProductView.create;
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Assign New Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF336EE5),
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
                future: _assignedProductsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red)));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text('No Assigned Products available.'));
                  } else {
                    final assignedProducts = snapshot.data!;
                    return ListView.builder(
                      itemCount: assignedProducts.length,
                      itemBuilder: (context, index) {
                        final ap = assignedProducts[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Customer: ${ap['customer_username']!}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    'Generator S/N: ${ap['generator_serial_number']!}'),
                                Text('Level: ${ap['level']!}'),
                                Text('Gantry: ${ap['gantry']!}'),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (userRole != null &&
                                          ['superadmin', 'admin', 'supervisor']
                                              .contains(userRole))
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          onPressed: () {
                                            setState(() {
                                              _editingAssignedProduct = ap;
                                              _currentView =
                                                  AssignedProductView.edit;
                                              _selectedGeneratorSerialNumber =
                                                  ap['generator_serial_number'];
                                              _selectedCustomerId =
                                                  ap['customer_id'];
                                              _levelController.text =
                                                  ap['level']!;
                                              _gantryController.text =
                                                  ap['gantry']!;
                                            });
                                          },
                                        ),
                                      if (userRole != null &&
                                          ['superadmin', 'admin', 'supervisor']
                                              .contains(userRole))
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _deleteAssignedProduct(ap['id']!),
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
      },
    );
  }

  Widget _buildCreateContent() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_productsFuture, _customersFuture]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text('Error loading data: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)));
        } else if (!snapshot.hasData ||
            snapshot.data![0].isEmpty ||
            snapshot.data![1].isEmpty) {
          return Center(
              child: Text(
                  'Cannot create assigned product. No available products or customers.',
                  style: TextStyle(color: Colors.orange[700])));
        } else {
          final List<Map<String, String>> products =
              snapshot.data![0].cast<Map<String, String>>();
          final List<Map<String, String>> customers =
              snapshot.data![1].cast<Map<String, String>>();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Assign New Product',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGeneratorSerialNumber,
                  decoration: const InputDecoration(
                    labelText: 'Generator Serial Number',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select Generator S/N'),
                  items: products.map((product) {
                    return DropdownMenuItem(
                      value: product['generator_serial_number'],
                      child: Text(product['generator_serial_number']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGeneratorSerialNumber = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCustomerId,
                  decoration: const InputDecoration(
                    labelText: 'Customer',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select Customer'),
                  items: customers.map((user) {
                    return DropdownMenuItem(
                      value: user['id'],
                      child: Text('${user['username']} (${user['role']})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCustomerId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _levelController,
                  decoration: const InputDecoration(
                    labelText: 'Level',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _gantryController,
                  decoration: const InputDecoration(
                    labelText: 'Gantry',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _createAssignedProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF336EE5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('Assign Product',
                      style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    _clearControllers();
                    setState(() {
                      _currentView = AssignedProductView.list;
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
      },
    );
  }

  Widget _buildEditContent(Map<String, String> assignedProduct) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_productsFuture, _customersFuture]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text('Error loading data: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)));
        } else if (!snapshot.hasData ||
            snapshot.data![0].isEmpty ||
            snapshot.data![1].isEmpty) {
          return Center(
              child: Text(
                  'Cannot edit assigned product. No available products or customers to select from.',
                  style: TextStyle(color: Colors.orange[700])));
        } else {
          final List<Map<String, String>> products =
              snapshot.data![0].cast<Map<String, String>>();
          final List<Map<String, String>> customers =
              snapshot.data![1].cast<Map<String, String>>();

          // Ensure selected values are initialized if they haven't been from setState
          _selectedGeneratorSerialNumber ??=
              assignedProduct['generator_serial_number'];
          _selectedCustomerId ??= assignedProduct['customer_id'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Edit Assigned Product: ${assignedProduct['id']}',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGeneratorSerialNumber,
                  decoration: const InputDecoration(
                    labelText: 'Generator Serial Number',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select Generator S/N'),
                  items: products.map((product) {
                    return DropdownMenuItem(
                      value: product['generator_serial_number'],
                      child: Text(product['generator_serial_number']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGeneratorSerialNumber = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCustomerId,
                  decoration: const InputDecoration(
                    labelText: 'Customer',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select Customer'),
                  items: customers.map((user) {
                    return DropdownMenuItem(
                      value: user['id'],
                      child: Text('${user['username']} (${user['role']})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCustomerId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _levelController,
                  decoration: const InputDecoration(
                    labelText: 'Level',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _gantryController,
                  decoration: const InputDecoration(
                    labelText: 'Gantry',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () =>
                      _updateAssignedProduct(assignedProduct['id']!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF336EE5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('Update Assigned Product',
                      style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    _clearControllers();
                    setState(() {
                      _currentView = AssignedProductView.list;
                      _editingAssignedProduct = null;
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
      },
    );
  }

  Widget _buildBodyContent() {
    switch (_currentView) {
      case AssignedProductView.list:
        return _buildListContent();
      case AssignedProductView.create:
        return _buildCreateContent();
      case AssignedProductView.edit:
        // Check if _editingAssignedProduct is null before using it.
        if (_editingAssignedProduct != null) {
          return _buildEditContent(_editingAssignedProduct!);
        } else {
          // Return a fallback widget to prevent the crash.
          return const Center(
            child: Text('Error: Product not selected for editing.'),
          );
        }
      default:
        return _buildListContent(); // Fallback to list view
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Product Management'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _buildBodyContent(),
    );
  }
}
