// lib/screens/customer/report_details_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart'; // For launching video links

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

class ReportDetailsScreen extends StatefulWidget {
  final String reportId; // Now accepts reportId instead of full data

  const ReportDetailsScreen({super.key, required this.reportId});

  @override
  _ReportDetailsScreenState createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>?
      _reportDetails; // Holds the 'data' part of the API response
  List<dynamic>? _media; // Holds the 'media' part of the API response
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchReportDetailsAndMedia();
  }

  Future<void> _fetchReportDetailsAndMedia() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final token = await SharedPrefs.getToken();
    if (token == null) {
      setState(() {
        _errorMessage = 'Authentication token not found.';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/reports/read/${widget.reportId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        setState(() {
          _reportDetails = responseData['data'];
          _media = responseData['media'];
          _isLoading = false;
        });
      } else {
        final errorBody = json.decode(response.body);
        setState(() {
          _errorMessage =
              'Failed to load report details: ${errorBody['message'] ?? response.reasonPhrase} (Status: ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching report details: $e';
        _isLoading = false;
      });
    }
  }

  // Helper to build detail rows, converting values to string if necessary
  Widget _buildDetailRow(String label, dynamic value) {
    String displayValue;
    if (value == null) {
      displayValue = 'N/A';
    } else if (value is bool) {
      displayValue = value ? 'Yes' : 'No';
    } else if (value is int &&
        (label == 'Load Test Performed' ||
            label == 'Is Picked Up' ||
            label == 'Test Run')) {
      displayValue = value == 1 ? 'Yes' : 'No';
    } else {
      displayValue = value.toString();
    }

    // Format datetime fields
    if ((label == 'Created At' || label == 'Modified At') && value != null) {
      try {
        DateTime dateTime = DateTime.parse(value.toString());
        displayValue =
            dateTime.toLocal().toString().split('.')[0]; // Remove milliseconds
      } catch (e) {
        // Fallback to original value if parsing fails
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150, // Consistent width for labels
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _fetchReportDetailsAndMedia,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _reportDetails == null
                  ? const Center(child: Text('Report details not found.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Report Information',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const Divider(),
                          _buildDetailRow(
                              'Report Index', _reportDetails!['report_index']),
                          _buildDetailRow(
                              'Title',
                              _reportDetails![
                                  'problem_issue']), // Changed from 'title' to 'problem_issue' as per API
                          _buildDetailRow(
                              'Report Type', _reportDetails!['report_type']),
                          _buildDetailRow('Status', _reportDetails!['status']),
                          _buildDetailRow('Generator S/N',
                              _reportDetails!['generator_serial_number']),
                          _buildDetailRow('Customer Name',
                              _reportDetails!['customer_name']),
                          _buildDetailRow('Engineer Name',
                              _reportDetails!['engineer_name']),
                          _buildDetailRow('Supervisor Name',
                              _reportDetails!['supervisor_name']),
                          _buildDetailRow('Level', _reportDetails!['level']),
                          _buildDetailRow('Gantry', _reportDetails!['gantry']),
                          _buildDetailRow(
                              'Remarks', _reportDetails!['remarks']),
                          _buildDetailRow(
                              'Is Picked Up', _reportDetails!['is_pick_up']),
                          _buildDetailRow('Created At',
                              _reportDetails!['created_datetime']),
                          _buildDetailRow('Modified At',
                              _reportDetails!['modified_datetime']),

                          const SizedBox(height: 20),
                          const Text('Attachments',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const Divider(),
                          if (_media != null && _media!.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _media!.map<Widget>((mediaItem) {
                                String mediaType = mediaItem['media_type'];
                                String mediaPath = mediaItem['media_path'];
                                String fullUrl =
                                    '${ApiConfig.baseUrl}/$mediaPath';

                                if (mediaType == 'image') {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'Image: ${mediaItem['media_name']}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          child: Image.network(
                                            fullUrl,
                                            width: double.infinity,
                                            height: 200,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              print(
                                                  'Image.network failed for URL: $fullUrl with error: $error');
                                              return Container(
                                                height: 200,
                                                color: Colors.grey[200],
                                                child: const Center(
                                                  child: Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey,
                                                      size: 50),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                } else if (mediaType == 'video') {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'Video: ${mediaItem['media_name']}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        ElevatedButton.icon(
                                          icon: const Icon(
                                              Icons.play_circle_fill),
                                          label: const Text('Play Video'),
                                          onPressed: () async {
                                            if (await canLaunchUrl(
                                                Uri.parse(fullUrl))) {
                                              await launchUrl(
                                                  Uri.parse(fullUrl));
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Could not launch $fullUrl')),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox
                                    .shrink(); // Hide unsupported media types
                              }).toList(),
                            )
                          else
                            const Text('No media attachments found.'),
                        ],
                      ),
                    ),
    );
  }
}
