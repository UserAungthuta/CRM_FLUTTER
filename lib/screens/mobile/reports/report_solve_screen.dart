// lib/screens/engineer/report_solve_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // For TimeoutException

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
import 'root_cause_screen.dart';
import 'corrective_action_screen.dart';
import 'effective_action_screen.dart';
import 'prevention_screen.dart';
import 'suggestion_screen.dart'; // Import the new root cause screen

class ReportSolveScreen extends StatefulWidget {
  final String reportId;

  const ReportSolveScreen({super.key, required this.reportId});

  @override
  _ReportSolveScreenState createState() => _ReportSolveScreenState();
}

class _ReportSolveScreenState extends State<ReportSolveScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  Map<String, dynamic>? _reportDetails;
  String? _currentUserRole;

  // Now, _rootCauseController will store the value returned from root_cause_screen.dart
  // The other controllers remain as they are for direct input

  // New variable to hold the root cause data
  //String _currentRootCause = '';

  @override
  void initState() {
    super.initState();
    _fetchReportDetails();
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

  Future<void> _fetchReportDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _currentUserRole = await SharedPrefs.getUserRole();
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          _showSnackBar(
              context, 'Authentication token missing. Please log in again.',
              color: Colors.red);
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/reports/read/${widget.reportId}');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['data'] is Map) {
          setState(() {
            _reportDetails = responseData['data'];
          });
        } else {
          if (mounted) {
            _showSnackBar(
                context, 'Failed to load report details. Invalid data format.',
                color: Colors.red);
          }
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          _showSnackBar(
              context,
              errorData['message'] ??
                  'Failed to load report details. Server error.',
              color: Colors.red);
        }
      }
    } on TimeoutException {
      if (mounted) {
        _showSnackBar(context, 'Request timed out. Server not responding.',
            color: Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'An error occurred: ${e.toString()}',
            color: Colors.red);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _SolveReport() async {
    // Ensure all data is saved before completing
    // You might want to call _saveReportUpdates() here, but be careful with async/await nesting.
    // For simplicity, let's assume _saveReportUpdates has been called, or handle validation here.

    setState(() {
      _isLoading = true;
    });

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          _showSnackBar(
              context, 'Authentication token missing. Please log in again.',
              color: Colors.red);
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/reports/solve/${widget.reportId}');
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              // You might send final notes or just rely on backend to change status
              'status': 'checking', // Explicitly set status to completed
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          _showSnackBar(context, 'Report marked as completed!',
              color: Colors.green);
          Navigator.pop(context); // Go back to the reports list
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          _showSnackBar(
              context,
              errorData['message'] ??
                  'Failed to complete report. Server error.',
              color: Colors.red);
        }
      }
    } on TimeoutException {
      if (mounted) {
        _showSnackBar(context, 'Request timed out. Server not responding.',
            color: Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context,
            'An error occurred while completing report: ${e.toString()}',
            color: Colors.red);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _CompleteReport() async {
    // Ensure all data is saved before completing
    // You might want to call _saveReportUpdates() here, but be careful with async/await nesting.
    // For simplicity, let's assume _saveReportUpdates has been called, or handle validation here.

    setState(() {
      _isLoading = true;
    });

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          _showSnackBar(
              context, 'Authentication token missing. Please log in again.',
              color: Colors.red);
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/reports/complete/${widget.reportId}');
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              // You might send final notes or just rely on backend to change status
              'status': 'checking', // Explicitly set status to completed
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          _showSnackBar(context, 'Report marked as completed!',
              color: Colors.green);
          Navigator.pop(context); // Go back to the reports list
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          _showSnackBar(
              context,
              errorData['message'] ??
                  'Failed to complete report. Server error.',
              color: Colors.red);
        }
      }
    } on TimeoutException {
      if (mounted) {
        _showSnackBar(context, 'Request timed out. Server not responding.',
            color: Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context,
            'An error occurred while completing report: ${e.toString()}',
            color: Colors.red);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solve Report'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportDetails == null
              ? Center(
                  child: Text(
                      'Failed to load report details for ID: ${widget.reportId}',
                      style: const TextStyle(color: Colors.red)),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        Text(
                          'Report Index: ${_reportDetails!['report_index'] ?? 'N/A'}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                            'Type: ${_reportDetails!['report_type'] ?? 'N/A'}'),
                        Text(
                            'Generator S/N: ${_reportDetails!['generator_serial_number'] ?? 'N/A'}'),
                        Text(
                            'Problem: ${_reportDetails!['problem_issue'] ?? 'N/A'}'),
                        Text('Status: ${_reportDetails!['status'] ?? 'N/A'}'),
                        Text(
                            'Engineer Name: ${_reportDetails!['engineer_name'] ?? 'N/A'}'),
                        Text(
                            'Created: ${_reportDetails!['created_datetime'] ?? 'N/A'}'),
                        const Divider(height: 30),

                        // Root Cause: Now a clickable item

                        const SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReportRootCauseScreen(
                                    reportId: _reportDetails!['report_index'],
                                    reportUId: _reportDetails![
                                        'id']), // Fixed: Null safety
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue, // Example color
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Text('Root Cause'),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ReportCorrectiveActionScreen(
                                        reportId:
                                            _reportDetails!['report_index'],
                                        reportUId: _reportDetails![
                                            'id']), // Fixed: Null safety
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue, // Example color
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Text('Corrective Action'),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ReportEffectiveActionScreen(
                                        reportId:
                                            _reportDetails!['report_index'],
                                        reportUId: _reportDetails![
                                            'id']), // Fixed: Null safety
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue, // Example color
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Text('Effective Action'),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ReportPreventionActionScreen(
                                        reportId:
                                            _reportDetails!['report_index'],
                                        reportUId: _reportDetails![
                                            'id']), // Fixed: Null safety
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue, // Example color
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Text('Prevention'),
                        ),
                        const SizedBox(height: 10),

                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ReportSuggestionActionScreen(
                                        reportId:
                                            _reportDetails!['report_index'],
                                        reportUId: _reportDetails![
                                            'id']), // Fixed: Null safety
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue, // Example color
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Text('Suggestion'),
                        ),
                        const SizedBox(height: 20),
                        if (_currentUserRole == 'engineer')
                          ElevatedButton(
                            onPressed: _isLoading ? null : _SolveReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Solved Report',
                                    style: TextStyle(fontSize: 16)),
                          )
                        else
                          ElevatedButton(
                            onPressed: _isLoading ? null : _CompleteReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Complete Report',
                                    style: TextStyle(fontSize: 16)),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    int maxLines = 3,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        maxLines: maxLines,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $labelText';
          }
          return null;
        },
      ),
    );
  }

  // New helper for clickable fields
}
