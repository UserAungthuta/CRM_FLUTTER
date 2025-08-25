// lib/screens/maintenance/maintenance_read_screen.dart
import 'package:flutter/material.dart';

class MaintenanceReadScreen extends StatelessWidget {
  final String id;
  final Map<String, String> record;

  const MaintenanceReadScreen(
      {super.key, required this.id, required this.record});

  @override
  Widget build(BuildContext context) {
    // Determine the maintenance types to display
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

    final typeText =
        maintenanceTypes.isEmpty ? 'N/A' : maintenanceTypes.join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Details'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Maintenance Details (ID: $id)',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildDetailRow(
                'Generator S/N:', record['generator_serial_number']),
            _buildDetailRow('Title:', record['maintenance_title']),
            _buildDetailRow('Description:', record['maintenance_description']),
            _buildDetailRow('Type:', typeText),
            _buildDetailRow('Date:', record['maintence_date']),
            _buildDetailRow('Checked By:', record['check_user_name']),
            _buildDetailRow('Customer Name:', record['customer_name']),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
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
}
