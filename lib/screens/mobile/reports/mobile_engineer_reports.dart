// lib/screens/engineer/mobile_engineer_reports.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
import 'report_solve_screen.dart';
import 'report_details_screen.dart';
import 'report_complete_screen.dart'; // Import the new solve screen

// Enum to manage the current view state
enum ReportView {
  list,
}

class MobileEngineerReportScreen extends StatefulWidget {
  const MobileEngineerReportScreen({super.key});

  @override
  _MobileEngineerReportScreenState createState() =>
      _MobileEngineerReportScreenState();
}

class _MobileEngineerReportScreenState
    extends State<MobileEngineerReportScreen> {
  late Future<List<Map<String, String>>> _reportsFuture;
  final ReportView _currentView = ReportView.list;

  List<XFile>? _reportImages;
  XFile? _reportVideo;
  final ImagePicker _picker = ImagePicker();

  bool _quickStatsLoading = false;
  late Future<List<Map<String, String>>> _customersFuture;
  String? _selectedCustomerId;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _fetchReports();
    _customersFuture = _fetchUsers(roles: ['localcustomer', 'globalcustomer']);
  }

  @override
  void dispose() {
    super.dispose();
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

  Future<List<Map<String, String>>> _fetchReports({String? customerId}) async {
    try {
      final String? token = await SharedPrefs.getToken();
      final int? userId = await SharedPrefs.getUserId();

      if (token == null || token.isEmpty || userId == null) {
        if (mounted) {
          _showSnackBar(context,
              'Authentication token or User ID missing. Please log in again.',
              color: Colors.red);
        }
        return [];
      }

      final Map<String, dynamic> queryParameters = {};
      if (customerId != null && customerId.isNotEmpty) {
        queryParameters['customer_id'] = customerId;
      }

      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/reports/readall').replace(
          queryParameters: queryParameters.isEmpty ? null : queryParameters);

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
          List<Map<String, String>> reports = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              reports.add({
                'id': item['id']?.toString() ?? '',
                'report_index': item['report_index'] as String? ?? 'N/A',
                'report_type': item['report_type'] as String? ?? 'N/A',
                'generator_serial_number':
                    item['generator_serial_number'] as String? ?? 'N/A',
                'customer_id': item['customer_id']?.toString() ?? 'N/A',
                'problem_issue': item['problem_issue'] as String? ?? 'N/A',
                'status': item['status'] as String? ?? 'N/A',
                'engineer_name': item['engineer_name'] as String? ?? 'N/A',
                'engineer_id': item['engineer_id']?.toString() ?? 'N/A',
                'created_datetime':
                    item['created_datetime'] as String? ?? 'N/A',
              });
            }
          }
          return reports;
        } else {
          if (mounted) {
            _showSnackBar(
                context, 'Failed to load reports. Invalid data format.',
                color: Colors.red);
          }
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          _showSnackBar(context,
              errorData['message'] ?? 'Failed to load reports. Server error.',
              color: Colors.red);
        }
        return [];
      }
    } on SocketException {
      if (mounted) {
        _showSnackBar(context, 'Network error. Check your internet connection.',
            color: Colors.red);
      }
      return [];
    } on TimeoutException {
      if (mounted) {
        _showSnackBar(context, 'Request timed out. Server not responding.',
            color: Colors.red);
      }
      return [];
    } on FormatException {
      if (mounted) {
        _showSnackBar(context, 'Invalid response format from server.',
            color: Colors.red);
      }
      return [];
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
            color: Colors.red);
      }
      return [];
    }
  }

  Future<void> _pickupReport(String reportId) async {
    final String? token = await SharedPrefs.getToken();
    final int? userId = await SharedPrefs.getUserId();

    if (token == null || token.isEmpty || userId == null) {
      if (mounted) {
        _showSnackBar(context,
            'Authentication token or User ID missing. Please log in again.',
            color: Colors.red);
      }
      return;
    }

    if (mounted) {
      setState(() {
        _quickStatsLoading = true;
      });
    }

    try {
      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/reports/pickup/$reportId');
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          _showSnackBar(context, 'Report picked up successfully!',
              color: Colors.green);
          setState(() {
            _reportsFuture = _fetchReports(customerId: _selectedCustomerId);
          });
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          _showSnackBar(context,
              errorData['message'] ?? 'Failed to pick up report. Server error.',
              color: Colors.red);
        }
      }
    } on SocketException {
      if (mounted) {
        _showSnackBar(context, 'Network error. Check your internet connection.',
            color: Colors.red);
      }
    } on TimeoutException {
      if (mounted) {
        _showSnackBar(context, 'Request timed out. Server not responding.',
            color: Colors.red);
      }
    } on FormatException {
      if (mounted) {
        _showSnackBar(context, 'Invalid response format from server.',
            color: Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
            color: Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _quickStatsLoading = false;
        });
      }
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    setState(() {
      _reportImages = images;
    });
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _reportVideo = video;
      });
    }
  }

  Widget _buildListContent() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reports for Engineer',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
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
                      _reportsFuture =
                          _fetchReports(customerId: _selectedCustomerId);
                    });
                  },
                ),
              );
            }
          },
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, String>>>(
            future: _reportsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No reports found.'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final report = snapshot.data![index];
                    Color statusColor;
                    switch (report['status']) {
                      case 'pending':
                        statusColor = Colors.orange;
                        break;
                      case 'solving':
                        statusColor = Colors.blue;
                        break;
                      case 'checking':
                        statusColor = Colors.purple;
                        break;
                      case 'completed':
                        statusColor = Colors.green;
                        break;
                      default:
                        statusColor = Colors.grey;
                    }

                    bool showPickupButton = report['status'] == 'pending' &&
                        (report['engineer_id'] == '0' ||
                            report['engineer_id'] == 'N/A' ||
                            report['engineer_id'] == '');

                    bool showSolveButton = report['status'] == 'solving';
                    bool showCompleteButton = report['status'] == 'completed';

                    bool statusChecking = report['status'] ==
                        'checking'; // Logic for Solve button

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MobileEngineerReportDetailsScreen(
                                      reportId: report['id']!),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Report Index: ${report['report_index']}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text('Type: ${report['report_type']}'),
                              Text(
                                  'Generator S/N: ${report['generator_serial_number']}'),
                              Text('Problem: ${report['problem_issue']}'),
                              Text(
                                'Status: ${report['status']}',
                                style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text('Engineer Name: ${report['engineer_name']}'),
                              Text('Created: ${report['created_datetime']}'),
                              const SizedBox(height: 10),
                              // Fix: Wrap the children of Row in a `children: []` list
                              Row(children: [
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ReportDetailsScreen(
                                                reportId: report['id']!),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.green, // Example color
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4)),
                                  ),
                                  child: const Text('View Report'),
                                ),
                                const SizedBox(width: 8),
                                if (!statusChecking) ...[
                                  // Use `if` with spread operator directly inside the children list
                                  if (showPickupButton) ...[
                                    ElevatedButton(
                                      onPressed: () =>
                                          _pickupReport(report['id']!),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                      ),
                                      child: const Text('Pick Up Report'),
                                    ),
                                  ],
                                  if (showSolveButton) ...[
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ReportSolveScreen(
                                                    reportId: report['id']!),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.deepOrange, // Example color
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                      ),
                                      child: const Text('Solve Report'),
                                    ),
                                  ],
                                ],
                                const SizedBox(width: 8),
                                if (showCompleteButton) ...[
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ReportCompleteScreen(
                                                  reportId: report['id']!),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.deepOrange, // Example color
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                    ),
                                    child: const Text('Report Solution'),
                                  ),
                                ],
                              ] // End of Row children
                                  )
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Engineer Reports'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentView) {
      case ReportView.list:
        return _buildListContent();
      default:
        return _buildListContent();
    }
  }
}

class MobileEngineerReportDetailsScreen extends StatelessWidget {
  final String reportId;

  const MobileEngineerReportDetailsScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          'Details for Report ID: $reportId\n(Implementation for details view coming soon!)',
          style: const TextStyle(fontSize: 20, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
