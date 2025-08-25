import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
// Import the new maintenance creation screen
import 'maintenance_create_screen.dart';

class MaintenancePlanHistoryScreen extends StatefulWidget {
  final String id;
  final Map<String, String> record;

  const MaintenancePlanHistoryScreen(
      {super.key, required this.id, required this.record});

  @override
  _MaintenancePlanHistoryScreenState createState() =>
      _MaintenancePlanHistoryScreenState();
}

class _MaintenancePlanHistoryScreenState
    extends State<MaintenancePlanHistoryScreen> {
  // Change the future to hold a grouped map
  late Future<Map<String, List<Map<String, String>>>> _maintenanceHistoryFuture;

  @override
  void initState() {
    super.initState();
    _maintenanceHistoryFuture = _fetchGroupedMaintenanceRecords();
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

  /// Fetches maintenance records and groups them by `maintenance_title`.
  Future<Map<String, List<Map<String, String>>>>
      _fetchGroupedMaintenanceRecords() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          _showSnackBar('Authentication token missing. Please log in again.',
              color: Colors.red);
        }
        return {};
      }

      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/maintenance/details-readall/${widget.id}');

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
        if (responseData['success'] == true && responseData['data'] is List) {
          Map<String, List<Map<String, String>>> groupedRecords = {};
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              final title = item['maintenance_title'] as String? ?? 'N/A';
              final record = {
                'id': item['id']?.toString() ?? 'N/A',
                'generator_serial_number':
                    item['generator_serial_number'] as String? ?? 'N/A',
                'maintenance_title':
                    item['maintenance_title'] as String? ?? 'N/A',
                'maintenance_description':
                    item['maintenance_description'] as String? ?? 'N/A',
                'maintenance_type':
                    item['maintenance_type'] as String? ?? 'N/A',
                'maintenance_check_user':
                    item['maintenance_check_user']?.toString() ?? 'N/A',
                'maintenance_date':
                    item['maintenance_date'] as String? ?? 'N/A',
                'is_check': item['is_check']?.toString() ?? '0',
              };

              // Group records by title
              if (!groupedRecords.containsKey(title)) {
                groupedRecords[title] = [];
              }
              groupedRecords[title]!.add(record);
            }
          }
          return groupedRecords;
        } else {
          if (mounted) {
            _showSnackBar(
                'Failed to load maintenance history. Invalid data format or success status.',
                color: Colors.red);
          }
          return {};
        }
      } else {
        String errorMessage =
            'Failed to load maintenance history. Server error.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          // Fallback if response body is not valid JSON
        }
        if (mounted) {
          _showSnackBar(errorMessage, color: Colors.red);
        }
        return {};
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
        _showSnackBar(errorMessage, color: Colors.red);
      }
      return {};
    }
  }

  /// Sends a request to update the 'is_check' status of a specific maintenance record.
  Future<void> _updateMaintenanceCheckStatus(String recordId) async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar('Authentication token missing.', color: Colors.red);
        return;
      }

      // Replace with your actual update endpoint
      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/maintenance/update/$recordId');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'id': recordId, 'is_check': '1'}),
      );
      print(uri);
      if (response.statusCode == 200) {
        _showSnackBar('Item checked successfully!');
        // Refresh the UI to reflect the change
        setState(() {
          _maintenanceHistoryFuture = _fetchGroupedMaintenanceRecords();
        });
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to update status.';
        _showSnackBar(errorMessage, color: Colors.red);
      }
    } catch (e) {
      _showSnackBar('An error occurred: ${e.toString()}', color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which "Create" buttons to show based on the widget.record flags
    final bool showMonthlyButton = widget.record['monthly'] == '1';
    final bool showQuarterlyButton = widget.record['quarterly'] == '1';
    final bool showAnnuallyButton = widget.record['annually'] == '1';
    final String gene = widget.record['generator_serial_number'] ?? 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Maintenance History for : ${widget.record['generator_serial_number']}'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (showMonthlyButton)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MaintenanceCreateScreen(
                                generatorSerialNumber: gene,
                                plan_id: widget.id,
                                maintenanceType: 'monthly',
                                initialTitle:
                                    'Monthly Maintenance for ${widget.record['generator_serial_number']}',
                              ),
                            ),
                          ).then((value) {
                            if (value == true) {
                              setState(() {
                                _maintenanceHistoryFuture =
                                    _fetchGroupedMaintenanceRecords();
                              });
                            }
                          });
                        },
                        icon: const Icon(Icons.add_task),
                        label: const Text('Create Monthly'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  if (showQuarterlyButton)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MaintenanceCreateScreen(
                                generatorSerialNumber: gene,
                                plan_id: widget.id,
                                maintenanceType: 'quarterly',
                                initialTitle:
                                    'Quarterly Maintenance for ${widget.record['generator_serial_number']}',
                              ),
                            ),
                          ).then((value) {
                            if (value == true) {
                              setState(() {
                                _maintenanceHistoryFuture =
                                    _fetchGroupedMaintenanceRecords();
                              });
                            }
                          });
                        },
                        icon: const Icon(Icons.add_task),
                        label: const Text('Create Quarterly'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  if (showAnnuallyButton)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MaintenanceCreateScreen(
                                generatorSerialNumber: gene,
                                plan_id: widget.id,
                                maintenanceType: 'annually',
                                initialTitle:
                                    'Annually Maintenance for ${widget.id}',
                              ),
                            ),
                          ).then((value) {
                            if (value == true) {
                              setState(() {
                                _maintenanceHistoryFuture =
                                    _fetchGroupedMaintenanceRecords();
                              });
                            }
                          });
                        },
                        icon: const Icon(Icons.add_task),
                        label: const Text('Create Annually'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, List<Map<String, String>>>>(
              future: _maintenanceHistoryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('No maintenance records found for this ID.'));
                } else {
                  final groupedRecords = snapshot.data!;
                  final titles = groupedRecords.keys.toList();

                  return ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: titles.length,
                    itemBuilder: (context, index) {
                      final title = titles[index];
                      final recordsForTitle = groupedRecords[title]!;
                      // print(groupedRecords[title]);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Title: ${recordsForTitle.first['maintenance_title'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF336EE5),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Checklist:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...recordsForTitle.map((record) {
                                final isChecked = record['is_check'] == '1';
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          record['maintenance_description'] ??
                                              'N/A',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isChecked
                                                ? Colors.green
                                                : Colors.grey[700],
                                            decoration: isChecked
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (!isChecked)
                                        ElevatedButton(
                                          onPressed: () {
                                            _updateMaintenanceCheckStatus(
                                                record['id']!);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[700],
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20)),
                                          ),
                                          child: const Text('Check'),
                                        ),
                                      if (isChecked)
                                        const Icon(Icons.check_circle,
                                            color: Colors.green),
                                    ],
                                  ),
                                );
                              }),
                              const Divider(height: 24, thickness: 1),
                              Text(
                                'Generator S/N: ${recordsForTitle.first['generator_serial_number'] ?? 'N/A'}',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
                              ),
                              Text(
                                'Type: ${recordsForTitle.first['maintenance_type'] ?? 'N/A'}',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
                              ),
                              Text(
                                'Date: ${recordsForTitle.first['maintenance_date'] ?? 'N/A'}',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
                              ),
                              Text(
                                'Checked By User ID: ${recordsForTitle.first['maintenance_check_user'] ?? 'N/A'}',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
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
      ),
    );
  }
}
