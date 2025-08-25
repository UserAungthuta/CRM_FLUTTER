// lib/screens/customer/mobile_customer_report_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io'; // Required for File class
import 'package:image_picker/image_picker.dart'; // Import for image/video picking
import 'package:http_parser/http_parser.dart'; // Required for MediaType

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
import 'report_details_screen.dart';

// Enum to manage the current view state
enum ReportView {
  list,
  create,
}

class MobileCustomerSolvedReportScreen extends StatefulWidget {
  const MobileCustomerSolvedReportScreen({super.key});

  @override
  _MobileCustomerSolvedReportScreenState createState() =>
      _MobileCustomerSolvedReportScreenState();
}

class _MobileCustomerSolvedReportScreenState
    extends State<MobileCustomerSolvedReportScreen> {
  late Future<List<Map<String, String>>> _reportsFuture;
  late Future<List<Map<String, String>>> _customerProductsFuture;
  ReportView _currentView = ReportView.list; // Default view is the list

  // Controllers for the forms (create)
  String? _selectedReportType = 'normal'; // Default to normal
  String? _selectedGeneratorSerialNumber;
  final TextEditingController _problemIssueController = TextEditingController();
  final TextEditingController _runningHoursController = TextEditingController();
  bool _loadTest = false; // Corresponds to tinyint 0 or 1
  final TextEditingController _loadHourController = TextEditingController();
  final TextEditingController _loadAmountController = TextEditingController();
  final TextEditingController _usedForController = TextEditingController();
  final TextEditingController _errorCodeController = TextEditingController();
  bool _testRun = false; // Corresponds to tinyint 0 or 1
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _remarksController =
      TextEditingController(); // Added remarks controller

  // For media attachments
  List<XFile>? _reportImages;
  XFile? _reportVideo; // Changed to single XFile for video
  final ImagePicker _picker = ImagePicker();

  // Added _quickStatsLoading to this class
  bool _quickStatsLoading = false; // Initialize with false

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _problemIssueController.dispose();
    _runningHoursController.dispose();
    _loadHourController.dispose();
    _loadAmountController.dispose();
    _usedForController.dispose();
    _errorCodeController.dispose();
    _locationController.dispose();
    _remarksController.dispose(); // Dispose remarks controller
    super.dispose();
  }

  void _fetchInitialData() {
    setState(() {
      _reportsFuture = _fetchReports();
      _customerProductsFuture = _fetchCustomerProducts();
    });
  }

  void _showSnackBar(BuildContext context, String message,
      {Color color = Colors.black}) {
    if (!mounted) return; // Check if the widget is still mounted
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<List<Map<String, String>>> _fetchReports() async {
    try {
      final String? token = await SharedPrefs.getToken();
      final int? userId = await SharedPrefs.getUserId();

      if (token == null || token.isEmpty || userId == null) {
        if (mounted) {
          // Check mounted before showing SnackBar
          _showSnackBar(context,
              'Authentication token or User ID missing. Please log in again.',
              color: Colors.red);
        }
        return [];
      }

      // API endpoint for customer-specific reports
      // The backend readAll method for reports should filter by customer_id based on role.
      // If not, you might need a specific endpoint like /reports/readbycustomer/$userId
      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/reports/complete-readall');
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
                'created_datetime':
                    item['created_datetime'] as String? ?? 'N/A',
                // Add other fields as needed for display
              });
            }
          }
          return reports;
        } else {
          if (mounted) {
            // Check mounted before showing SnackBar
            _showSnackBar(
                context, 'Failed to load reports. Invalid data format.',
                color: Colors.red);
          }
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          // Check mounted before showing SnackBar
          _showSnackBar(context,
              errorData['message'] ?? 'Failed to load reports. Server error.',
              color: Colors.red);
        }
        return [];
      }
    } on SocketException {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(context, 'Network error. Check your internet connection.',
            color: Colors.red);
      }
      return [];
    } on TimeoutException {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(context, 'Request timed out. Server not responding.',
            color: Colors.red);
      }
      return [];
    } on FormatException {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(context, 'Invalid response format from server.',
            color: Colors.red);
      }
      return [];
    } catch (e) {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
            color: Colors.red);
      }
      return [];
    }
  }

  Future<List<Map<String, String>>> _fetchCustomerProducts() async {
    try {
      final String? token = await SharedPrefs.getToken();
      final int? userId = await SharedPrefs.getUserId();

      if (token == null || token.isEmpty || userId == null) {
        if (mounted) {
          // Check mounted before showing SnackBar
          _showSnackBar(context,
              'Authentication token or User ID missing. Please log in again.',
              color: Colors.red);
        }
        return [];
      }

      // Assuming an API endpoint to get products assigned to the current customer
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/customer-products/readall'); // Adjusted endpoint
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
          List<Map<String, String>> products = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              products.add({
                'id': item['id']?.toString() ?? '',
                'generator_serial_number':
                    item['generator_serial_number'] as String? ?? '',
              });
            }
          }
          return products;
        } else {
          if (mounted) {
            // Check mounted before showing SnackBar
            _showSnackBar(
                context,
                responseData['message'] ??
                    'Failed to load customer products. Invalid data format.',
                color: Colors.red);
          }
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          // Check mounted before showing SnackBar
          _showSnackBar(
              context,
              errorData['message'] ??
                  'Failed to load customer products. Server error.',
              color: Colors.red);
        }
        return [];
      }
    } on SocketException {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(context,
            'Network error. Check your internet connection for products.',
            color: Colors.red);
      }
      return [];
    } on TimeoutException {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(
            context, 'Request for products timed out. Server not responding.',
            color: Colors.red);
      }
      return [];
    } on FormatException {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(
            context, 'Invalid response format from server for products.',
            color: Colors.red);
      }
      return [];
    } catch (e) {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(context,
            'An unexpected error occurred while fetching products: ${e.toString()}',
            color: Colors.red);
      }
      return [];
    }
  }

  Future<void> _createReport() async {
    final String? token = await SharedPrefs.getToken();
    final int? userId = await SharedPrefs.getUserId();

    if (token == null || token.isEmpty || userId == null) {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(context,
            'Authentication token or User ID missing. Please log in again.',
            color: Colors.red);
      }
      return;
    }

    if (_selectedGeneratorSerialNumber == null ||
        _problemIssueController.text.isEmpty) {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(
            context, 'Generator Serial Number and Problem Issue are required.',
            color: Colors.orange);
      }
      return;
    }

    if (mounted) {
      // Check mounted before setState
      setState(() {
        _quickStatsLoading = true; // Indicate loading for report submission
      });
    }

    try {
      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/reports/create/');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      request.fields['report_type'] = _selectedReportType ?? 'normal';
      request.fields['generator_serial_number'] =
          _selectedGeneratorSerialNumber!;
      request.fields['customer_id'] = userId.toString();
      request.fields['problem_issue'] = _problemIssueController.text.trim();
      request.fields['running_hours'] = _runningHoursController.text.trim();
      request.fields['load_test'] = _loadTest ? '1' : '0';
      request.fields['load_hour'] = _loadHourController.text.trim();
      request.fields['load_amount'] = _loadAmountController.text.trim();
      request.fields['used_for'] = _usedForController.text.trim();
      request.fields['error_code'] = _errorCodeController.text.trim();
      request.fields['test_run'] = _testRun ? '1' : '0';
      request.fields['location'] = _locationController.text.trim();
      request.fields['remarks'] =
          _remarksController.text.trim(); // Added remarks field

      // Add images
      if (_reportImages != null && _reportImages!.isNotEmpty) {
        for (int i = 0; i < _reportImages!.length; i++) {
          final imageFile = _reportImages![i];
          final fileBytes = await imageFile.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'report_images[]', // Use array notation for multiple files
            fileBytes,
            filename: imageFile.name,
            contentType: MediaType('image', imageFile.name.split('.').last),
          ));
        }
      }

      // Add video
      if (_reportVideo != null) {
        final videoFile = _reportVideo!;
        final fileBytes = await videoFile.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'report_video', // Single video file
          fileBytes,
          filename: videoFile.name,
          contentType: MediaType('video', videoFile.name.split('.').last),
        ));
      }

      final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30)); // Increased timeout for file uploads
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        if (mounted) {
          // Check mounted before showing SnackBar and setState
          _showSnackBar(context, 'Report created successfully!',
              color: Colors.green);
          _clearControllers();
          setState(() {
            _currentView = ReportView.list;
          });
          _fetchInitialData(); // Refresh list
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          // Check mounted before showing SnackBar
          _showSnackBar(context,
              errorData['message'] ?? 'Failed to create report. Server error.',
              color: Colors.red);
        }
      }
    } on SocketException {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(context, 'Network error. Check your internet connection.',
            color: Colors.red);
      }
    } on TimeoutException {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(context, 'Request timed out. Server not responding.',
            color: Colors.red);
      }
    } on FormatException {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(context, 'Invalid response format from server.',
            color: Colors.red);
      }
    } catch (e) {
      if (mounted) {
        // Check mounted before showing SnackBar
        _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
            color: Colors.red);
      }
    } finally {
      if (mounted) {
        // Check mounted before setState
        setState(() {
          _quickStatsLoading = false; // End loading state
        });
      }
    }
  }

  void _clearControllers() {
    _selectedReportType = 'normal';
    _selectedGeneratorSerialNumber = null;
    _problemIssueController.clear();
    _runningHoursController.clear();
    _loadTest = false;
    _loadHourController.clear();
    _loadAmountController.clear();
    _usedForController.clear();
    _errorCodeController.clear();
    _testRun = false;
    _locationController.clear();
    _remarksController.clear(); // Clear remarks controller
    _reportImages = null;
    _reportVideo = null;
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Reports',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _clearControllers();
                  setState(() {
                    _currentView = ReportView.create;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Create New Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF336EE5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
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

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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
                            Text('Created: ${report['created_datetime']}'),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReportDetailsScreen(
                                        reportId: report['id']!),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, // Example color
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              child: const Text('View Report'),
                            ),
                            // You can add more details or an action button here
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
    );
  }

  Widget _buildCreateContent() {
    return FutureBuilder<List<Map<String, String>>>(
      future: _customerProductsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text('Error loading products: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Text(
                  'No products assigned to you. Cannot create a report.',
                  style: TextStyle(color: Colors.orange[700])));
        } else {
          final customerProducts = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Create New Report',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _selectedReportType,
                  decoration: const InputDecoration(
                    labelText: 'Report Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(
                        value: 'emergency', child: Text('Emergency')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedReportType = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGeneratorSerialNumber,
                  decoration: const InputDecoration(
                    labelText: 'Generator Serial Number',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select Generator S/N'),
                  items: customerProducts.map((product) {
                    return DropdownMenuItem(
                      value: product['generator_serial_number'],
                      child: Text(product['generator_serial_number']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGeneratorSerialNumber = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a generator serial number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _problemIssueController,
                  decoration: const InputDecoration(
                    labelText: 'Problem Issue (Required)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Problem issue cannot be empty.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _runningHoursController,
                  decoration: const InputDecoration(
                    labelText: 'Running Hours',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Load Test'),
                    ),
                    Switch(
                      value: _loadTest,
                      onChanged: (bool value) {
                        setState(() {
                          _loadTest = value;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _loadHourController,
                  decoration: const InputDecoration(
                    labelText: 'Load Hour',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _loadAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Load Amount',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usedForController,
                  decoration: const InputDecoration(
                    labelText: 'Used For',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _errorCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Error Code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Test Run'),
                    ),
                    Switch(
                      value: _testRun,
                      onChanged: (bool value) {
                        setState(() {
                          _testRun = value;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  // Added Remarks field
                  controller: _remarksController,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // --- Media Attachment Fields ---
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.image),
                  label: Text(_reportImages == null
                      ? 'Add Images'
                      : '${_reportImages!.length} Image(s) Selected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam),
                  label: Text(
                      _reportVideo == null ? 'Add Video' : '1 Video Selected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 30),
                // --- End Media Attachment Fields ---
                ElevatedButton(
                  onPressed: _createReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF336EE5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('Submit Report',
                      style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    _clearControllers();
                    setState(() {
                      _currentView = ReportView.list;
                    });
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
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
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
      case ReportView.create:
        return _buildCreateContent();
      default:
        return _buildListContent(); // Fallback to list view
    }
  }
}
