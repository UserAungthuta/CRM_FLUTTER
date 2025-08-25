// lib/screens/assigned_products/web_assigned_products_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
import '../../../widgets/sidebar_widget.dart';
import '../../../models/user_model.dart'; // Assuming User model is needed for _fetchUsers

// Enum to manage the current view state
enum AssignedProductView {
  list,
  create,
  edit,
}

class WebAssignedProductsScreen extends StatefulWidget {
  const WebAssignedProductsScreen({super.key});

  @override
  _WebAssignedProductsScreenState createState() =>
      _WebAssignedProductsScreenState();
}

class _WebAssignedProductsScreenState extends State<WebAssignedProductsScreen> {
  static const double _kSidebarWidth = 256.0;
  static const double _kContentHorizontalPadding = 20.0;
  static const double _kAppBarHeight = kToolbarHeight;

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

  User? _currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSidebarOpen = true;

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

  Future<void> _logout() async {
    await SharedPrefs.clearAll();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
    _showSnackBar(context, 'Logged out successfully!', color: Colors.green);
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

      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/products/readall');
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
          '${ApiConfig.baseUrl}/customer-products/update/$assignedProductId');
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(_kContentHorizontalPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Assigned Products',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
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
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width -
                            _kSidebarWidth -
                            (_kContentHorizontalPadding * 2)),
                    child: DataTable(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Gen. S/N')),
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Level')),
                        DataColumn(label: Text('Gantry')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: assignedProducts.map((ap) {
                        return DataRow(cells: [
                          DataCell(Text(ap['id']!)),
                          DataCell(Text(ap['generator_serial_number']!)),
                          DataCell(Text(ap[
                              'customer_username']!)), // Display customer username
                          DataCell(Text(ap['level']!)),
                          DataCell(Text(ap['gantry']!)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () {
                                    setState(() {
                                      _editingAssignedProduct = ap;
                                      _currentView = AssignedProductView.edit;
                                      _selectedGeneratorSerialNumber =
                                          ap['generator_serial_number'];
                                      _selectedCustomerId = ap['customer_id'];
                                      _levelController.text = ap['level']!;
                                      _gantryController.text = ap['gantry']!;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _deleteAssignedProduct(ap['id']!),
                                ),
                              ],
                            ),
                          ),
                        ]);
                      }).toList(),
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
            padding: const EdgeInsets.all(_kContentHorizontalPadding),
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
            padding: const EdgeInsets.all(_kContentHorizontalPadding),
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
        return _buildEditContent(_editingAssignedProduct!);
      default:
        return _buildListContent();
    }
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap,
      {Color textColor = Colors.white, bool isSubItem = false}) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: isSubItem ? 32.0 : 8.0),
      minLeadingWidth: 0,
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      onTap: onTap,
      tileColor: const Color(0xFF1E293B),
      selectedTileColor: const Color(0xFF2563EB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    Navigator.of(context).pushNamed('/Products');
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
}
