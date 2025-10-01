// lib/screens/customer/mobile_customer_report_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../service/report_service.dart';
import '../../../utils/shared_prefs.dart';
import 'report_details_screen.dart';
import 'report_complete_screen.dart';

enum ReportView {
  list,
  create,
}

class MobileCustomerReportScreen extends StatefulWidget {
  const MobileCustomerReportScreen({super.key});

  @override
  _MobileCustomerReportScreenState createState() =>
      _MobileCustomerReportScreenState();
}

class _MobileCustomerReportScreenState
    extends State<MobileCustomerReportScreen> {
  late Future<List<Map<String, dynamic>>> _reportsFuture;
  late Future<List<Map<String, dynamic>>> _customerProductsFuture;
  ReportView _currentView = ReportView.list;
  final ReportService _reportService = ReportService();

  String? _selectedReportType = 'normal';
  String? _selectedGeneratorSerialNumber;
  final TextEditingController _problemIssueController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  List<XFile>? _reportImages;
  XFile? _reportVideo;
  final ImagePicker _picker = ImagePicker();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _problemIssueController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _fetchInitialData() {
    setState(() {
      _reportsFuture = _reportService.fetchReports();
      _customerProductsFuture = _reportService.fetchCustomerProducts();
    });
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

  Future<void> _createReport() async {
    final int? userId = await SharedPrefs.getUserId();

    if (userId == null) {
      _showSnackBar(context,
          'Authentication token or User ID missing. Please log in again.',
          color: Colors.red);
      return;
    }

    if (_selectedGeneratorSerialNumber == null ||
        _problemIssueController.text.isEmpty) {
      _showSnackBar(
          context, 'Generator Serial Number and Problem Issue are required.',
          color: Colors.orange);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // The `ReportService` now handles the conversion from `XFile`
      // to the appropriate platform-specific file type.
      await _reportService.createReport(
        reportType: _selectedReportType!,
        generatorSerialNumber: _selectedGeneratorSerialNumber!,
        problemIssue: _problemIssueController.text.trim(),
        remarks: _remarksController.text.trim(),
        imageFiles: _reportImages, // Pass XFile objects directly
        videoFile: _reportVideo, // Pass XFile objects directly
        customerId: userId,
      );

      _showSnackBar(context, 'Report created successfully!',
          color: Colors.green);
      _clearControllers();
      setState(() {
        _currentView = ReportView.list;
        _fetchInitialData();
      });
    } catch (e) {
      _showSnackBar(context, e.toString(), color: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _clearControllers() {
    _selectedReportType = 'normal';
    _selectedGeneratorSerialNumber = null;
    _problemIssueController.clear();
    _remarksController.clear();
    _reportImages = null;
    _reportVideo = null;
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (mounted) {
      setState(() {
        _reportImages = images;
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null && mounted) {
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
          child: FutureBuilder<List<Map<String, dynamic>>>(
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
                    bool showCompleteButton = report['status'] == 'completed';

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
                                        reportId: report['id']!.toString()),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              child: const Text('View Report'),
                            ),
                            const SizedBox(width: 8),
                            if (showCompleteButton) ...[
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ReportCompleteScreen(
                                              reportId:
                                                  report['id']!.toString()),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepOrange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4)),
                                ),
                                child: const Text('Report Solution'),
                              ),
                            ],
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
    return FutureBuilder<List<Map<String, dynamic>>>(
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
                  items:
                      customerProducts.map<DropdownMenuItem<String>>((product) {
                    return DropdownMenuItem<String>(
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
                TextFormField(
                  controller: _remarksController,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
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
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _createReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF336EE5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Submit Report',
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
        return _buildListContent();
    }
  }
}
