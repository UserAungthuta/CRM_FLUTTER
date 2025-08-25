// lib/screens/mobile/maintenance_plan/mobile_maintenance_plan_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
//import 'mobile_maintenance_detail_screen.dart'; // Import the detail screen

class MobileMaintenancePlanScreen extends StatefulWidget {
  final String generatorSerialNumber;

  const MobileMaintenancePlanScreen({
    super.key,
    required this.generatorSerialNumber,
  });

  @override
  _MobileMaintenancePlanScreenState createState() =>
      _MobileMaintenancePlanScreenState();
}

class _MobileMaintenancePlanScreenState
    extends State<MobileMaintenancePlanScreen> {
  bool _monthly = false;
  bool _quarterly = false;
  bool _annually = false;

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

  Future<void> _createMaintenancePlan() async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    if (!_monthly && !_quarterly && !_annually) {
      _showSnackBar(context, 'Please select at least one maintenance type.',
          color: Colors.orange);
      return;
    }

    try {
      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/maintenance/createPlan');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'generator_serial_number': widget.generatorSerialNumber,
              'monthly': _monthly,
              'quarterly': _quarterly,
              'annually': _annually,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        _showSnackBar(context, 'Maintenance Plan created successfully!',
            color: Colors.green);

        // Determine the maintenance type to pass to the detail screen
        String maintenanceType = '';
        if (_monthly) maintenanceType = 'monthly';
        if (_quarterly) maintenanceType = 'quarterly';
        if (_annually) maintenanceType = 'annually';

        // Navigate to the maintenance details screen with necessary info
        if (mounted) {
          Navigator.pushNamed(context, '/mobile_superadmin-dashboard');
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to create maintenance plan. Server error.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Plan'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create Maintenance Plan for: ${widget.generatorSerialNumber}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildCheckboxTile(
              title: 'Monthly Maintenance',
              value: _monthly,
              onChanged: (bool? newValue) {
                setState(() {
                  _monthly = newValue ?? false;
                });
              },
            ),
            _buildCheckboxTile(
              title: 'Quarterly Maintenance',
              value: _quarterly,
              onChanged: (bool? newValue) {
                setState(() {
                  _quarterly = newValue ?? false;
                });
              },
            ),
            _buildCheckboxTile(
              title: 'Annually Maintenance',
              value: _annually,
              onChanged: (bool? newValue) {
                setState(() {
                  _annually = newValue ?? false;
                });
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _createMaintenancePlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text('Create Plan', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context); // Go back to the previous screen
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
      ),
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: CheckboxListTile(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        value: value,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: Colors.blue,
      ),
    );
  }
}
