// lib/screens/maintenance/maintenance_read_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
import '../../../utils/file_saver.dart';
import 'maintenance_details_screen.dart';

class MaintenanceReadScreen extends StatefulWidget {
  final String id;
  final Map<String, dynamic> record;

  const MaintenanceReadScreen(
      {super.key, required this.id, required this.record});

  @override
  _MaintenanceReadScreenState createState() => _MaintenanceReadScreenState();
}

class _MaintenanceReadScreenState extends State<MaintenanceReadScreen> {
  bool _isDownloadingPdf = false;
  late Future<Map<String, List<Map<String, dynamic>>>>
      _maintenanceHistoryFuture;
  late final String _generatorSerialNumber;
  late Map<String, dynamic> _currentRecord;
  String _userRole = ''; // Added to store user role

  @override
  void initState() {
    super.initState();
    _currentRecord = Map<String, dynamic>.from(widget.record);
    _generatorSerialNumber = widget.record['generator_serial_number'] ?? 'N/A';
    _maintenanceHistoryFuture = _fetchGroupedMaintenanceRecords();
    _loadUserRole(); // Call the method to load user role
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

  // Method to load user role from SharedPrefs
  Future<void> _loadUserRole() async {
    final role = await SharedPrefs.getUserRole();
    if (mounted) {
      setState(() {
        _userRole = role ?? '';
      });
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>>
      _fetchGroupedMaintenanceRecords() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar('Authentication token missing. Please log in again.',
            color: Colors.red);
        return {};
      }

      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/maintenance/details-readall/${widget.id}');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] is List) {
          Map<String, List<Map<String, dynamic>>> groupedRecords = {};
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              final title = item['maintenance_title'] as String? ?? 'N/A';
              groupedRecords.putIfAbsent(title, () => []).add(item);
            }
          }
          return groupedRecords;
        } else {
          _showSnackBar(
              'Failed to load maintenance history. Invalid data format or success status.',
              color: Colors.red);
          return {};
        }
      } else {
        final errorMessage = json.decode(response.body)['message'] ??
            'Failed to load maintenance history. Server error.';
        _showSnackBar(errorMessage, color: Colors.red);
        return {};
      }
    } on TimeoutException {
      _showSnackBar('Request timed out. Server not responding.',
          color: Colors.red);
      return {};
    } on SocketException {
      _showSnackBar('Network error. Check your internet connection.',
          color: Colors.red);
      return {};
    } on FormatException {
      _showSnackBar('Invalid response format from server.', color: Colors.red);
      return {};
    } catch (e) {
      _showSnackBar('An unexpected error occurred: ${e.toString()}',
          color: Colors.red);
      return {};
    }
  }

  Future<void> _updateMaintenanceCheckStatus(String recordId) async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar('Authentication token missing.', color: Colors.red);
        return;
      }

      final uri =
          Uri.parse('${ApiConfig.baseUrl}/maintenance/update/$recordId');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'id': recordId, 'is_check': '1'}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Item checked successfully!');
        setState(() {
          _maintenanceHistoryFuture = _fetchGroupedMaintenanceRecords();
        });
      } else {
        final errorMessage =
            json.decode(response.body)['message'] ?? 'Failed to update status.';
        _showSnackBar(errorMessage, color: Colors.red);
      }
    } catch (e) {
      _showSnackBar('An error occurred: ${e.toString()}', color: Colors.red);
    }
  }

  /// Method to download the maintenance PDF.
  Future<void> _downloadMaintenancePdf(String maintenanceType) async {
    if (_isDownloadingPdf || widget.id.isEmpty) {
      return;
    }

    setState(() {
      _isDownloadingPdf = true;
    });

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar('Authentication token missing. Please log in again.',
            color: Colors.red);
        return;
      }

      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/maintenance/download-pdf/${widget.id}?type=$maintenanceType');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final fileName =
            '${maintenanceType}_maintenance_report_$_generatorSerialNumber.pdf';
        final fileSaver = getFileSaver();

        if (!kIsWeb) {
          final directory = await getApplicationDocumentsDirectory();
          final String filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          if (mounted) {
            _showSnackBar('PDF downloaded to: $filePath', color: Colors.green);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewerScreen(pdfPath: filePath),
              ),
            );
          }
        } else {
          await fileSaver.savePdf(response.bodyBytes, fileName);
          _showSnackBar('PDF download initiated.', color: Colors.green);
        }
      } else {
        final errorMessage = json.decode(response.body)['message'] ??
            'Failed to download PDF. Status: ${response.statusCode}';
        _showSnackBar(errorMessage, color: Colors.red);
      }
    } on TimeoutException {
      _showSnackBar('PDF download request timed out.', color: Colors.red);
    } catch (e) {
      _showSnackBar('An error occurred during PDF download: ${e.toString()}',
          color: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingPdf = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _filterRecordsByType(
      Map<String, List<Map<String, dynamic>>> groupedRecords, String type) {
    List<Map<String, dynamic>> filteredList = [];
    for (var records in groupedRecords.values) {
      filteredList.addAll(
          records.where((record) => record['maintenance_type'] == type));
    }
    return filteredList;
  }

  Map<String, List<Map<String, dynamic>>> _groupRecordsByTitle(
      List<Map<String, dynamic>> records) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var record in records) {
      final title = record['maintenance_title'] as String? ?? 'N/A';
      grouped.putIfAbsent(title, () => []).add(record);
    }
    return grouped;
  }

  // Function to show date picker for editing maintenance end date
  Future<void> _editMaintenanceEndDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(_currentRecord['maintenance_end_date'] ?? '') ??
              DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      // You would add API call here to update the date on the server
      setState(() {
        _currentRecord['maintenance_end_date'] =
            DateFormat('yyyy-MM-dd').format(pickedDate);
      });
      _showSnackBar(
          'Maintenance end date updated locally. Remember to implement server-side update.',
          color: Colors.green);
    }
  }

  // Getter to check if the user can edit
  bool get _canEdit =>
      _userRole != 'localcustomer' && _userRole != 'globalcustomer';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... AppBar setup ...
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Details Card (remains full-width)
            _buildDetailsCard(),
            const SizedBox(height: 20),

            // --- START: Maintenance Cards in a ROW ---
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start, // Align cards to the top
              children: [
                // 1. Monthly Maintenance Card
                if (_currentRecord['monthly'] == '1')
                  Expanded(
                    child: _buildMaintenanceTypeCard('monthly',
                        'Monthly Maintenance for ${_currentRecord['generator_serial_number']}'),
                  ),

                // Add spacing only if the Monthly card is present and another card follows
                if (_currentRecord['monthly'] == '1' &&
                    (_currentRecord['quarterly'] == '1' ||
                        _currentRecord['annually'] == '1'))
                  const SizedBox(width: 10),

                // 2. Quarterly Maintenance Card
                if (_currentRecord['quarterly'] == '1')
                  Expanded(
                    child: _buildMaintenanceTypeCard('quarterly',
                        'Quarterly Maintenance for ${_currentRecord['generator_serial_number']}'),
                  ),

                // Add spacing only if the Quarterly card is present and the Annually card follows
                if (_currentRecord['quarterly'] == '1' &&
                    _currentRecord['annually'] == '1')
                  const SizedBox(width: 10),

                // 3. Annually Maintenance Card
                if (_currentRecord['annually'] == '1')
                  Expanded(
                    child: _buildMaintenanceTypeCard('annually',
                        'Annually Maintenance for ${_currentRecord['generator_serial_number']}'),
                  ),
              ],
            ),
            // --- END: Maintenance Cards in a ROW ---

            const SizedBox(height: 20), // Add vertical space after the Row

            // ... Back Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to List'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors
                    .white, // Good practice to explicitly set text/icon color
                padding: const EdgeInsets.symmetric(
                    vertical: 15), // Assuming you want this large padding
                // --- Add the shape with BorderRadius ---
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Details Information',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            _buildDetailRow('Generator S/N',
                _currentRecord['generator_serial_number'] ?? 'N/A'),
            _buildDetailRow(
                'Maintenance Service End Date',
                DateFormat('dd/MM/yyyy').format(DateTime.tryParse(
                        _currentRecord['maintenance_end_date'] ?? '') ??
                    DateTime.now())),
            _buildDetailRow(
                'Customer Name', _currentRecord['customer_name'] ?? 'N/A'),
            if (_canEdit)
              ElevatedButton(
                onPressed: _editMaintenanceEndDate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                // --- The change is here ---
                child: const Row(
                  mainAxisSize:
                      MainAxisSize.min, // Keep the row's width minimal
                  children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 6), // Add some space between icon and text
                    Text('Edit Date',
                        style: TextStyle(fontSize: 14)), // Your label
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceTypeCard(String type, String title) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MaintenancePlanHistoryScreen(
                            id: widget.id,
                            record: widget.record,
                            type: type,
                          ),
                        ),
                      );
                      if (result == true) {
                        setState(() {
                          _maintenanceHistoryFuture =
                              _fetchGroupedMaintenanceRecords();
                        });
                      }
                    },
                    icon: const Icon(Icons.view_array, size: 16),
                    label: const Text('Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

// PdfViewerScreen for mobile/desktop platforms
class PdfViewerScreen extends StatelessWidget {
  final String pdfPath;

  const PdfViewerScreen({super.key, required this.pdfPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance PDF Viewer'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: SfPdfViewer.file(File(pdfPath)),
    );
  }
}
