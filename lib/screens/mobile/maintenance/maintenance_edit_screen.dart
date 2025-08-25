// lib/screens/maintenance/maintenance_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

class MaintenanceEditScreen extends StatefulWidget {
  final String id;
  final Map<String, String> record;

  const MaintenanceEditScreen(
      {super.key, required this.id, required this.record});

  @override
  _MaintenanceEditScreenState createState() => _MaintenanceEditScreenState();
}

class _MaintenanceEditScreenState extends State<MaintenanceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _generatorSerialNumberController =
      TextEditingController();
  final TextEditingController _maintenanceTitleController =
      TextEditingController();
  final TextEditingController _maintenanceDescriptionController =
      TextEditingController();
  final TextEditingController _maintenanceDateController =
      TextEditingController();

  // State variables for monthly, quarterly, annually flags
  bool _isMonthly = false;
  bool _isQuarterly = false;
  bool _isAnnually = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate the form with the existing record data
    _generatorSerialNumberController.text =
        widget.record['generator_serial_number'] ?? '';
    _maintenanceTitleController.text = widget.record['maintenance_title'] ?? '';
    _maintenanceDescriptionController.text =
        widget.record['maintenance_description'] ?? '';
    _maintenanceDateController.text = widget.record['maintence_date'] ?? '';

    // Initialize the boolean flags from the string '0' or '1' values
    _isMonthly = widget.record['monthly'] == '1';
    _isQuarterly = widget.record['quarterly'] == '1';
    _isAnnually = widget.record['annually'] == '1';
  }

  @override
  void dispose() {
    _generatorSerialNumberController.dispose();
    _maintenanceTitleController.dispose();
    _maintenanceDescriptionController.dispose();
    _maintenanceDateController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {Color color = Colors.black}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updateMaintenanceRecord() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar('Authentication token missing.', color: Colors.red);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Determine the maintenance type string based on the flags for sending to API
    // This assumes your API update still expects a single 'maintenance_type' string
    String maintenanceTypeString = '';
    final List<String> typesSelected = [];
    if (_isMonthly) typesSelected.add('monthly');
    if (_isQuarterly) typesSelected.add('quarterly');
    if (_isAnnually) typesSelected.add('annually');

    if (typesSelected.isNotEmpty) {
      maintenanceTypeString =
          typesSelected.join(','); // Join with comma if multiple
    }

    final Uri uri =
        Uri.parse('${ApiConfig.baseUrl}/maintenance/update/${widget.id}');
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
              'maintenance_type':
                  maintenanceTypeString, // Send the derived string
              'maintence_date': _maintenanceDateController.text,
              'monthly': _isMonthly ? '1' : '0', // Send '1' or '0' string
              'quarterly': _isQuarterly ? '1' : '0', // Send '1' or '0' string
              'annually': _isAnnually ? '1' : '0', // Send '1' or '0' string
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          _showSnackBar('Maintenance record updated successfully!',
              color: Colors.green);
          Navigator.pop(
              context, true); // Pop and return a value to indicate success
        } else {
          _showSnackBar(
              responseData['message'] ?? 'Failed to update maintenance record.',
              color: Colors.red);
        }
      } else {
        String errorMessage = 'Server error during update.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Server responded with status ${response.statusCode}.';
        }
        _showSnackBar(errorMessage, color: Colors.red);
      }
    } on Exception catch (e) {
      String errorMessage = 'An unexpected error occurred: ${e.toString()}';
      if (e is TimeoutException) {
        errorMessage = 'Request timed out. Server not responding.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Network error. Check your internet connection.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid response format from server.';
      }
      _showSnackBar(errorMessage, color: Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(_maintenanceDateController.text) ?? DateTime.now(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Maintenance Record'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Update Record (ID: ${widget.id})',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
              // Replaced TextFormField for Maintenance Type with Switches
              SwitchListTile(
                title: const Text('Monthly Maintenance'),
                value: _isMonthly,
                onChanged: (bool value) {
                  setState(() {
                    _isMonthly = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Quarterly Maintenance'),
                value: _isQuarterly,
                onChanged: (bool value) {
                  setState(() {
                    _isQuarterly = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Annually Maintenance'),
                value: _isAnnually,
                onChanged: (bool value) {
                  setState(() {
                    _isAnnually = value;
                  });
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
                      onPressed: _updateMaintenanceRecord,
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
                onPressed: () => Navigator.pop(context),
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
      ),
    );
  }
}
