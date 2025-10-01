import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
// These imports are placeholders. You must ensure these screens exist.
import 'maintenance_read_screen.dart';

enum MaintenanceView {
  list,
  update,
  detail,
}

class MobileMaintenanceScreen extends StatefulWidget {
  const MobileMaintenanceScreen({super.key});

  @override
  _MobileMaintenanceScreenState createState() =>
      _MobileMaintenanceScreenState();
}

class _MobileMaintenanceScreenState extends State<MobileMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  late Future<List<Map<String, String>>> _maintenanceRecordsFuture;
  late Future<List<Map<String, String>>> _customersFuture;
  MaintenanceView _currentView = MaintenanceView.list;
  Map<String, String>? _editingMaintenanceRecord;
  Map<String, String>? _selectedMaintenanceRecord;

  final TextEditingController _generatorSerialNumberController =
      TextEditingController();
  final TextEditingController _maintenanceTitleController =
      TextEditingController();
  final TextEditingController _maintenanceDescriptionController =
      TextEditingController();
  final TextEditingController _maintenanceTypeController =
      TextEditingController();
  final TextEditingController _maintenanceDateController =
      TextEditingController();

  bool _isLoading = false;
  String? _userRole;
  String? _selectedFilter;
  String? _selectedCustomerId;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _generatorSerialNumberController.dispose();
    _maintenanceTitleController.dispose();
    _maintenanceDescriptionController.dispose();
    _maintenanceTypeController.dispose();
    _maintenanceDateController.dispose();
    super.dispose();
  }

  void _fetchInitialData() {
    _customersFuture = _fetchUsers(roles: ['localcustomer', 'globalcustomer']);
    _fetchMaintenanceRecordsData();
  }

  Future<void> _fetchUserRole() async {
    final user = await SharedPrefs.getUser();
    if (user != null) {
      setState(() {
        _userRole = user.role;
      });
    }
  }

  void _fetchMaintenanceRecordsData() {
    setState(() {
      _maintenanceRecordsFuture = _fetchMaintenanceRecords();
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

  Future<List<Map<String, String>>> _fetchMaintenanceRecords(
      {String? customerId}) async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          _showSnackBar(
              context, 'Authentication token missing. Please log in again.',
              color: Colors.red);
        }
        return [];
      }

      final Map<String, dynamic> queryParameters = {};
      if (_selectedFilter != null) {
        queryParameters['type'] = _selectedFilter;
      }
      if (customerId != null && customerId.isNotEmpty) {
        queryParameters['customer_id'] = customerId;
      }

      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/maintenance/readall')
          .replace(
              queryParameters:
                  queryParameters.isEmpty ? null : queryParameters);

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
      //print(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] is List) {
          List<Map<String, String>> records = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              records.add({
                'id': item['id']?.toString() ?? 'N/A',
                'generator_serial_number':
                    item['generator_serial_number'] as String? ?? 'N/A',
                'monthly': item['monthly']?.toString() ?? 'N/A',
                'quarterly': item['quarterly']?.toString() ?? 'N/A',
                'annually': item['annually']?.toString() ?? 'N/A',
                'maintenance_end_date':
                    item['maintenance_end_date']?.toString() ?? 'N/A',
                'maintenance_check_user':
                    item['maintenance_check_user']?.toString() ?? 'N/A',
                'check_user_name': item['check_user_name'] as String? ?? 'N/A',
                'maintence_date': item['maintence_date'] as String? ?? 'N/A',
                'customer_id': item['customer_id']?.toString() ?? 'N/A',
                'customer_name': item['customer_name'] as String? ?? 'N/A',
              });
            }
          }
          return records;
        } else {
          if (mounted) {
            _showSnackBar(context,
                'Failed to load maintenance records. Invalid data format or success status.',
                color: Colors.red);
          }
          return [];
        }
      } else {
        String errorMessage =
            'Failed to load maintenance records. Server error.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {}
        if (mounted) {
          _showSnackBar(context, errorMessage, color: Colors.red);
        }
        return [];
      }
    } on Exception catch (e) {
      if (mounted) {
        String errorMessage = 'An unexpected error occurred: ${e.toString()}';
        if (e is TimeoutException) {
          errorMessage = 'Request timed out. Server not responding.';
        } else if (e.toString().contains('SocketException')) {
          errorMessage = 'Network error. Check your internet connection.';
        } else if (e.toString().contains('FormatException')) {
          errorMessage = 'Invalid response format from server.';
        }
        _showSnackBar(context, errorMessage, color: Colors.red);
      }
      return [];
    }
  }

  Future<void> _updateMaintenanceRecord(String recordId) async {
    if (!_validateForm()) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        _showSnackBar(context, 'Authentication token missing.',
            color: Colors.red);
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final Uri uri =
        Uri.parse('${ApiConfig.baseUrl}/maintenance/update/$recordId');
    try {
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'generator_serial_number': _generatorSerialNumberController.text,
              'maintenance_title': _maintenanceTitleController.text,
              'maintenance_description': _maintenanceDescriptionController.text,
              'maintenance_type': _maintenanceTypeController.text,
              'maintence_date': _maintenanceDateController.text,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          if (mounted) {
            _showSnackBar(context, 'Maintenance record updated successfully!',
                color: Colors.green);
            _clearForm();
            setState(() {
              _currentView = MaintenanceView.list;
              _editingMaintenanceRecord = null;
              _fetchMaintenanceRecordsData();
            });
          }
        } else {
          if (mounted) {
            _showSnackBar(
                context,
                responseData['message'] ??
                    'Failed to update maintenance record.',
                color: Colors.red);
          }
        }
      } else {
        String errorMessage = 'Server error during update.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Server responded with status ${response.statusCode}.';
        }
        if (mounted) {
          _showSnackBar(context, errorMessage, color: Colors.red);
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        String errorMessage = 'An unexpected error occurred: ${e.toString()}';
        if (e is TimeoutException) {
          errorMessage = 'Request timed out. Server not responding.';
        } else if (e.toString().contains('SocketException')) {
          errorMessage = 'Network error. Check your internet connection.';
        } else if (e.toString().contains('FormatException')) {
          errorMessage = 'Invalid response format from server.';
        }
        _showSnackBar(context, errorMessage, color: Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _validateForm() {
    if (_formKey.currentState!.validate()) {
      if (_maintenanceDateController.text.isEmpty) {
        _showSnackBar(context, 'Please select a maintenance date.',
            color: Colors.red);
        return false;
      }
      return true;
    }
    return false;
  }

  void _clearForm() {
    _generatorSerialNumberController.clear();
    _maintenanceTitleController.clear();
    _maintenanceDescriptionController.clear();
    _maintenanceTypeController.clear();
    _maintenanceDateController.clear();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _maintenanceDateController.text =
            DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Widget _buildListContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [],
          ),
        ),
        FutureBuilder<List<Map<String, String>>>(
          future: _customersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: LinearProgressIndicator(),
              );
            } else if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Error loading customers: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('No customers available for filtering.'),
              );
            } else {
              final customers = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCustomerId,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Customer',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  hint: const Text('Select a Customer'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Customers'),
                    ),
                    ...customers.map((customer) {
                      return DropdownMenuItem<String>(
                        value: customer['id'],
                        child: Text(customer['username']!),
                      );
                    }),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCustomerId = newValue;
                      _maintenanceRecordsFuture = _fetchMaintenanceRecords(
                          customerId: _selectedCustomerId);
                    });
                  },
                ),
              );
            }
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: FutureBuilder<List<Map<String, String>>>(
              future: _maintenanceRecordsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('No maintenance records available.'));
                } else {
                  final records = snapshot.data!;
                  return ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final maintenanceTypes = [];
                      if (record['monthly'] == '1') {
                        maintenanceTypes.add('Monthly');
                      }
                      if (record['quarterly'] == '1') {
                        maintenanceTypes.add('Quarterly');
                      }
                      if (record['annually'] == '1') {
                        maintenanceTypes.add('Annually');
                      }

                      final typeText = maintenanceTypes.isEmpty
                          ? 'N/A'
                          : maintenanceTypes.join(', ');

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Generator S/N: ${record['generator_serial_number'] ?? 'N/A'}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Maintenance Type: $typeText',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Customer Name: ${record['customer_name'] ?? 'N/A'}',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Maintenance End Date: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(record['maintenance_end_date'] ?? ''))}',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              MaintenanceReadScreen(
                                            id: record['id']!,
                                            record: record,
                                          ),
                                        ),
                                      ).then((_) =>
                                          _fetchMaintenanceRecordsData());
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                    ),
                                    child: const Text('View'),
                                  ),
                                ],
                              )
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
        ),
      ],
    );
  }

  Widget _buildCreateUpdateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Update Maintenance Record (ID: ${_editingMaintenanceRecord!['id']})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _generatorSerialNumberController,
              decoration: const InputDecoration(
                labelText: 'Generator Serial Number',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter generator serial number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maintenanceTitleController,
              decoration: const InputDecoration(
                labelText: 'Maintenance Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter maintenance title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maintenanceDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Maintenance Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maintenanceTypeController,
              decoration: const InputDecoration(
                labelText: 'Maintenance Type (e.g., Routine, Repair)',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter maintenance type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maintenanceDateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Maintenance Date',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a maintenance date';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: () => _updateMaintenanceRecord(
                        _editingMaintenanceRecord!['id']!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Update Record',
                        style: TextStyle(fontSize: 18)),
                  ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                _clearForm();
                setState(() {
                  _currentView = MaintenanceView.list;
                  _editingMaintenanceRecord = null;
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cancel',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent() {
    if (_selectedMaintenanceRecord == null) {
      return const Center(
          child: Text('No maintenance record selected to view.'));
    }

    final maintenanceTypes = [];
    if (_selectedMaintenanceRecord!['monthly'] == '1') {
      maintenanceTypes.add('Monthly');
    }
    if (_selectedMaintenanceRecord!['quarterly'] == '1') {
      maintenanceTypes.add('Quarterly');
    }
    if (_selectedMaintenanceRecord!['annually'] == '1') {
      maintenanceTypes.add('Annually');
    }

    final typeText =
        maintenanceTypes.isEmpty ? 'N/A' : maintenanceTypes.join(', ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Maintenance Details (ID: ${_selectedMaintenanceRecord!['id']})',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildDetailRow('Generator S/N:',
              _selectedMaintenanceRecord!['generator_serial_number']),
          _buildDetailRow(
              'Title:', _selectedMaintenanceRecord!['maintenance_title']),
          _buildDetailRow('Description:',
              _selectedMaintenanceRecord!['maintenance_description']),
          _buildDetailRow('Type:', typeText),
          _buildDetailRow(
              'Date:', _selectedMaintenanceRecord!['maintence_date']),
          _buildDetailRow(
              'Checked By:', _selectedMaintenanceRecord!['check_user_name']),
          _buildDetailRow(
              'Customer Name:', _selectedMaintenanceRecord!['customer_name']),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedMaintenanceRecord = null;
                _currentView = MaintenanceView.list;
              });
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to List'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Records'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _buildListContent(),
    );
  }
}
