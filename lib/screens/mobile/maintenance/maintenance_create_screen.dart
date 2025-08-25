// lib/screens/maintenance/maintenance_create_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
// Removed unused intl import as DateFormat is no longer needed
// import 'package:intl/intl.dart';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

class MaintenanceCreateScreen extends StatefulWidget {
  final String generatorSerialNumber;
  final String plan_id;
  final String maintenanceType; // e.g., 'monthly', 'quarterly', 'annually'
  final String? initialTitle; // Optional pre-filled title

  const MaintenanceCreateScreen({
    super.key,
    required this.generatorSerialNumber,
    required this.maintenanceType,
    required this.plan_id,
    this.initialTitle,
  });

  @override
  _MaintenanceCreateScreenState createState() =>
      _MaintenanceCreateScreenState();
}

class _MaintenanceCreateScreenState extends State<MaintenanceCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _generatorSerialNumberController =
      TextEditingController();
  final TextEditingController _planIDController = TextEditingController();
  final TextEditingController _maintenanceTitleController =
      TextEditingController();
  final List<TextEditingController> _reasonControllers = [];
  // Removed _maintenanceDateController as requested
  // final TextEditingController _maintenanceDateController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generatorSerialNumberController.text = widget.generatorSerialNumber;
    _planIDController.text = widget.plan_id;
    _maintenanceTitleController.text = widget.initialTitle ?? '';
    // Removed date initialization
    // _maintenanceDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now()); // Default to today's date
    _reasonControllers
        .add(TextEditingController()); // Add an initial reason field
  }

  @override
  void dispose() {
    _generatorSerialNumberController.dispose();
    _maintenanceTitleController.dispose();
    for (var controller in _reasonControllers) {
      controller.dispose();
    }
    // Removed date controller disposal
    // _maintenanceDateController.dispose();
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

  void _addReasonField() {
    setState(() {
      _reasonControllers.add(TextEditingController());
    });
  }

  void _removeReasonField(int index) {
    setState(() {
      _reasonControllers[index].dispose();
      _reasonControllers.removeAt(index);
    });
  }

  Future<void> _createMaintenanceRecord() async {
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

    final String combinedReasons = _reasonControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n');
    final Map<String, dynamic> requestBody = {
      'generator_serial_number': _generatorSerialNumberController.text,
      'maintenance_title': _maintenanceTitleController.text,
      'plan_id': _planIDController.text,
      'maintenance_description': combinedReasons,
      'maintenance_type': widget.maintenanceType,
    };
    print('Sending request with body: ${json.encode(requestBody)}');
    final Uri uri = Uri.parse('${ApiConfig.baseUrl}/maintenance/create');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          _showSnackBar('Maintenance record created successfully!',
              color: Colors.green);
          Navigator.pop(context, true);
        } else {
          _showSnackBar(
              responseData['message'] ?? 'Failed to create maintenance record.',
              color: Colors.red);
        }
      } else {
        String errorMessage = 'Server error during creation.';
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

  // Removed _selectDate method as requested
  // Future<void> _selectDate(BuildContext context) async {
  //   final DateTime? picked = await showDatePicker(
  //     context: context,
  //     initialDate: DateTime.tryParse(_maintenanceDateController.text) ?? DateTime.now(),
  //     firstDate: DateTime(2000),
  //     lastDate: DateTime(2101),
  //   );
  //   if (picked != null) {
  //     setState(() {
  //       _maintenanceDateController.text = DateFormat('yyyy-MM-dd').format(picked);
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Create ${widget.maintenanceType.toUpperCase()} Maintenance'),
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
                'Creating ${widget.maintenanceType} maintenance for ${widget.generatorSerialNumber}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _generatorSerialNumberController,
                readOnly: true, // Generator S/N is already read-only
                decoration: const InputDecoration(
                  labelText: 'Generator Serial Number',
                  border: OutlineInputBorder(),
                ),
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
              // Dynamically generated reason fields
              ..._reasonControllers.asMap().entries.map((entry) {
                int idx = entry.key;
                TextEditingController controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: 'Maintenance Reason ${idx + 1}',
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: null,
                          minLines: 1,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Reason cannot be empty';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (_reasonControllers.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red),
                          onPressed: () => _removeReasonField(idx),
                        ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addReasonField,
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  label: const Text('Add More Reason',
                      style: TextStyle(color: Colors.blue)),
                ),
              ),
              const SizedBox(height: 16),
              // Removed TextFormField for Maintenance Date as requested
              /*
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
              */
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _createMaintenanceRecord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Create Record',
                          style: TextStyle(fontSize: 18)),
                    ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
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
