import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

// Enum to manage the current view state for Warning Config
enum WarningConfigView {
  list,
  // Removed 'create' as per user request
  edit,
}

class MobileSettingsWarningScreen extends StatefulWidget {
  const MobileSettingsWarningScreen({super.key});

  @override
  _MobileSettingsWarningScreenState createState() =>
      _MobileSettingsWarningScreenState();
}

class _MobileSettingsWarningScreenState
    extends State<MobileSettingsWarningScreen> {
  // Changed Future type to hold Warning Config data
  late Future<List<Map<String, String>>> _warningConfigsFuture;
  WarningConfigView _currentView =
      WarningConfigView.list; // Default view is the list
  Map<String, String>?
      _editingWarningConfig; // Holds data of the warning config being edited

  // Controllers for the forms (add/edit) for Warning Config
  final TextEditingController _customerTypeController = TextEditingController();
  final TextEditingController _firstWarningHoursController =
      TextEditingController();
  final TextEditingController _lastWarningHoursController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchWarningConfigsData(); // Fetch warning configurations on init
  }

  @override
  void dispose() {
    _customerTypeController.dispose();
    _firstWarningHoursController.dispose();
    _lastWarningHoursController.dispose();
    super.dispose();
  }

  // Refreshes the warning config list data
  void _fetchWarningConfigsData() {
    setState(() {
      _warningConfigsFuture = _fetchWarningConfigs();
    });
  }

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

  /// Fetches the list of warning configurations from the API.
  Future<List<Map<String, String>>> _fetchWarningConfigs() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        return [];
      }

      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/warning-config/readall');

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
          List<Map<String, String>> configs = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              configs.add({
                'id': item['id']?.toString() ?? 'N/A',
                'customer_type': item['customer_type'] as String,
                'first_warning_hours':
                    item['first_warning_hours']?.toString() ?? 'N/A',
                'last_warning_hours':
                    item['last_warning_hours']?.toString() ?? 'N/A',
                // You can add 'created_at' and 'updated_at' if you want to display them
              });
            }
          }
          return configs;
        } else {
          _showSnackBar(context,
              'Failed to load warning configurations. Invalid data format.',
              color: Colors.red);
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to load warning configurations. Server error.',
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

  // Removed _createWarningConfig as per user request
  // Future<void> _createWarningConfig() async { ... }

  // --- Implement Update Warning Config API Call ---
  Future<void> _updateWarningConfig(String configId) async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    final String customerType = _customerTypeController.text.trim();
    final int? firstWarningHours =
        int.tryParse(_firstWarningHoursController.text.trim());
    final int? lastWarningHours =
        int.tryParse(_lastWarningHoursController.text.trim());

    if (customerType.isEmpty ||
        firstWarningHours == null ||
        lastWarningHours == null) {
      _showSnackBar(
          context, 'All fields are required and must be valid numbers.',
          color: Colors.orange);
      return;
    }

    try {
      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/warning-config/update/$configId');
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'customer_type': customerType,
              'first_warning_hours': firstWarningHours,
              'last_warning_hours': lastWarningHours,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Warning configuration updated successfully!',
            color: Colors.green);
        _customerTypeController.clear();
        _firstWarningHoursController.clear();
        _lastWarningHoursController.clear();
        setState(() {
          _currentView = WarningConfigView.list;
          _editingWarningConfig = null;
        });
        _fetchWarningConfigsData(); // Refresh list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to update warning configuration. Server error.',
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

  // Removed _buildCreateContent() as per user request
  // Widget _buildCreateContent() { ... }

  // Method to build the "Edit Warning Config" form content
  Widget _buildEditContent(Map<String, String> config) {
    _customerTypeController.text = config['customer_type'] ?? '';
    _firstWarningHoursController.text = config['first_warning_hours'] ?? '';
    _lastWarningHoursController.text = config['last_warning_hours'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit Config: ${config['customer_type']}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _customerTypeController,
            decoration: const InputDecoration(
              labelText: 'Customer Type (e.g., local, global)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstWarningHoursController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'First Warning Hours',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastWarningHoursController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Last Warning Hours',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => _updateWarningConfig(config['id']!),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Update Config', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              _customerTypeController.clear();
              _firstWarningHoursController.clear();
              _lastWarningHoursController.clear();
              setState(() {
                _currentView = WarningConfigView.list;
                _editingWarningConfig = null;
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentView == WarningConfigView.list
              ? 'Warning Time Settings'
              : 'Edit Warning Config', // Adjusted title
        ),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
        leading: _currentView != WarningConfigView.list
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _customerTypeController.clear();
                  _firstWarningHoursController.clear();
                  _lastWarningHoursController.clear();
                  setState(() {
                    _currentView = WarningConfigView.list;
                    _editingWarningConfig = null;
                  });
                },
              )
            : null,
      ),
      body: _currentView == WarningConfigView.list
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Removed Add New Config button as per user request
                // Padding(
                //   padding: const EdgeInsets.all(8.0),
                //   child: Align(
                //     alignment: Alignment.centerRight,
                //     child: ElevatedButton.icon(
                //       onPressed: () {
                //         _customerTypeController.clear();
                //         _firstWarningHoursController.clear();
                //         _lastWarningHoursController.clear();
                //         setState(() {
                //           _currentView = WarningConfigView.create;
                //         });
                //       },
                //       icon: const Icon(Icons.add, color: Colors.white),
                //       label: const Text('Add New Config',
                //           style: TextStyle(color: Colors.white)),
                //       style: ElevatedButton.styleFrom(
                //         backgroundColor: const Color(0xFF336EE5),
                //         padding: const EdgeInsets.symmetric(
                //             horizontal: 16, vertical: 10),
                //         shape: RoundedRectangleBorder(
                //             borderRadius: BorderRadius.circular(8)),
                //       ),
                //     ),
                //   ),
                // ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Warning Configurations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[700],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: FutureBuilder<List<Map<String, String>>>(
                      future: _warningConfigsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(
                              child:
                                  Text('No warning configurations available.'));
                        } else {
                          final configs = snapshot.data!;
                          return ListView.builder(
                            itemCount: configs.length,
                            itemBuilder: (context, index) {
                              final config = configs[index];
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    // You can choose to pop and return data or navigate to a detail screen
                                    Navigator.of(context).pop(config);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Customer Type: ${config['customer_type'] ?? 'N/A'}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'First Warning: ${config['first_warning_hours'] ?? 'N/A'} hours',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey),
                                              ),
                                              Text(
                                                'Last Warning: ${config['last_warning_hours'] ?? 'N/A'} hours',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          onPressed: () {
                                            setState(() {
                                              _editingWarningConfig = config;
                                              _currentView =
                                                  WarningConfigView.edit;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
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
            )
          : _buildEditContent(_editingWarningConfig!), // Only edit view remains
    );
  }
}
