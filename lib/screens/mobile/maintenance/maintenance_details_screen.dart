// lib/screens/maintenance/maintenance_plan_history_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
import '../../../utils/file_saver.dart';
import 'maintenance_create_screen.dart'; // Assuming this is the 'Create' screen

// The PdfViewerScreen from maintenance_read_screen.dart is duplicated here for simplicity
// or should be moved to a common utility file. Keeping it here for a standalone example.
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

class MaintenancePlanHistoryScreen extends StatefulWidget {
  final String id;
  final Map<String, dynamic> record;
  final String type; // 'Monthly', 'Quarterly', or 'Annually'

  const MaintenancePlanHistoryScreen({
    super.key,
    required this.id,
    required this.record,
    required this.type,
  });

  @override
  _MaintenancePlanHistoryScreenState createState() =>
      _MaintenancePlanHistoryScreenState();
}

class _MaintenancePlanHistoryScreenState
    extends State<MaintenancePlanHistoryScreen> {
  bool _isDownloadingPdf = false;
  late Future<Map<String, List<Map<String, dynamic>>>>
      _maintenanceHistoryFuture;
  late final String _generatorSerialNumber;
  String _userRole = ''; // Added to store user role

  @override
  void initState() {
    super.initState();
    _generatorSerialNumber = widget.record['generator_serial_number'] ?? 'N/A';
    // Initial fetch should filter by the passed 'type'
    _maintenanceHistoryFuture = _fetchGroupedMaintenanceRecords();
    _loadUserRole();
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

  Future<void> _loadUserRole() async {
    final role = await SharedPrefs.getUserRole();
    if (mounted) {
      setState(() {
        _userRole = role ?? '';
      });
    }
  }

  // Getter to check if the user can create/edit
  bool get _canModify =>
      _userRole != 'localcustomer' && _userRole != 'globalcustomer';

  // --- API Functions ---

  // Fetches ALL details and then groups and filters by type
  Future<Map<String, List<Map<String, dynamic>>>>
      _fetchGroupedMaintenanceRecords() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar('Authentication token missing. Please log in again.',
            color: Colors.red);
        return {};
      }

      // Fetch all details for the main maintenance record ID
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/maintenance/details-readall/${widget.id}');
      //print(widget.type);
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
          List<Map<String, dynamic>> filteredList = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic> &&
                item['maintenance_type'] == widget.type) {
              filteredList.add(item);
            }
          }
          // Group the filtered list by maintenance_title
          Map<String, List<Map<String, dynamic>>> groupedRecords = {};
          for (var item in filteredList) {
            final title = item['maintenance_title'] as String? ?? 'N/A';
            groupedRecords.putIfAbsent(title, () => []).add(item);
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
    } catch (e) {
      _showSnackBar('An unexpected error occurred: ${e.toString()}',
          color: Colors.red);
      return {};
    }
  }

  Future<void> _updateMaintenanceCheckStatus(String recordId) async {
    // This function is taken directly from MaintenanceReadScreen
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

      // Use the specific type from the screen's argument
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

  // --- Widget Builders ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.type} Maintenance History'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildActionButtons(),
            const SizedBox(height: 20),
            _buildHistoryList(),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context,
                    true); // Pop back and pass 'true' to signify a change/refresh might be needed
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Maintenance Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (_canModify)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    // Navigate to the creation/update screen (assuming MaintenanceDetailsScreen)
                    builder: (context) => MaintenanceCreateScreen(
                      generatorSerialNumber:
                          widget.record['generator_serial_number'],
                      plan_id: widget.id,
                      maintenanceType: widget.type,

                      // Pass any other necessary arguments for creation
                    ),
                  ),
                );
                // Refresh the list if creation was successful
                if (result == true) {
                  setState(() {
                    _maintenanceHistoryFuture =
                        _fetchGroupedMaintenanceRecords();
                  });
                }
              },
              icon: const Icon(Icons.add, size: 16),
              label: Text('Create ${widget.type}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
        if (_canModify) const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isDownloadingPdf
                ? null
                : () => _downloadMaintenancePdf(widget.type),
            icon: _isDownloadingPdf
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download, size: 16),
            label: Text(_isDownloadingPdf ? 'Downloading...' : 'Download PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _maintenanceHistoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Text('No ${widget.type} maintenance records found.'));
        } else {
          final groupedRecords = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: groupedRecords.entries.map((entry) {
              final title = entry.key;
              final records = entry.value;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  children: records.map((record) {
                    final detailId = record['id'].toString();
                    final isChecked = record['is_check'] == 1;

                    return ListTile(
                      title: Text(record['maintenance_description'] ??
                          'No Description'),
                      subtitle: Text(
                          'Last Date: ${record['maintenance_date'] ?? 'N/A'}'),
                      trailing: _canModify
                          ? Checkbox(
                              value: isChecked,
                              onChanged: isChecked
                                  ? null // Disable if already checked
                                  : (bool? newValue) {
                                      if (newValue == true) {
                                        _updateMaintenanceCheckStatus(detailId);
                                      }
                                    },
                              activeColor: Colors.blueAccent,
                            )
                          : Icon(
                              isChecked
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isChecked ? Colors.green : Colors.red,
                            ),
                      onTap: () {
                        // Optional: Navigate to an edit/view screen for this specific detail
                      },
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          );
        }
      },
    );
  }
}
