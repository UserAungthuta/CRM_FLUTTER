// report_complete_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
import 'root_cause_screen.dart';
import 'corrective_action_screen.dart';
import 'effective_action_screen.dart';
import 'prevention_screen.dart';
import 'suggestion_screen.dart';

// Create new files:
// - lib/utils/file_saver.dart
// - lib/utils/file_saver_mobile.dart
// - lib/utils/file_saver_web.dart
import '../../../utils/file_saver.dart';

class ReportCompleteScreen extends StatefulWidget {
  final String reportId;

  const ReportCompleteScreen({super.key, required this.reportId});

  @override
  _ReportCompleteScreenState createState() => _ReportCompleteScreenState();
}

class _ReportCompleteScreenState extends State<ReportCompleteScreen> {
  bool _isLoading = true;
  bool _isDownloading = false;
  Map<String, dynamic>? _reportDetails;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _fetchReportDetails();
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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      _currentUserRole = await SharedPrefs.getUserRole();
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
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
          _showSnackBar(
              context, 'Failed to load report details. Invalid data format.',
              color: Colors.red);
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to load report details. Server error.',
            color: Colors.red);
      }
    } on TimeoutException {
      _showSnackBar(context, 'Request timed out. Server not responding.',
          color: Colors.red);
    } catch (e) {
      _showSnackBar(context, 'An error occurred: ${e.toString()}',
          color: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (!mounted ||
        _isDownloading ||
        _reportDetails == null ||
        _reportDetails!['id'] == null) {
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        return;
      }

      final int reportInternalId = _reportDetails!['id'];
      final String reportIndex = _reportDetails!['report_index'];
      print(reportInternalId);
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/reports/download-pdf/$reportInternalId');

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final String fileName = '$reportIndex.pdf';

        final fileSaver = getFileSaver();
        await fileSaver.savePdf(response.bodyBytes, fileName);

        if (!kIsWeb) {
          final directory = await getApplicationDocumentsDirectory();
          final String filePath = '${directory.path}/$fileName';

          if (mounted) {
            _showSnackBar(context, 'PDF downloaded to: $filePath',
                color: Colors.green);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewerScreen(pdfPath: filePath),
              ),
            );
          }
        } else {
          _showSnackBar(context, 'PDF download initiated.',
              color: Colors.green);
        }
      } else {
        String errorMessage =
            'Failed to download PDF. Status: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (_) {}
        _showSnackBar(context, errorMessage, color: Colors.red);
      }
    } on TimeoutException {
      _showSnackBar(
          context, 'PDF download request timed out. Server not responding.',
          color: Colors.red);
    } catch (e) {
      _showSnackBar(
          context, 'An error occurred during PDF download: ${e.toString()}',
          color: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Solution'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportDetails == null
              ? _buildErrorWidget()
              : Stack(
                  children: [
                    _buildReportDetailsForm(),
                    if (_isDownloading)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Text(
        'Failed to load report details for ID: ${widget.reportId}',
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _buildReportDetailsForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          _buildInfoText('Report Index', _reportDetails!['report_index']),
          _buildInfoText('Type', _reportDetails!['report_type']),
          _buildInfoText(
              'Generator S/N', _reportDetails!['generator_serial_number']),
          _buildInfoText('Problem', _reportDetails!['problem_issue']),
          _buildInfoText('Status', _reportDetails!['status']),
          _buildInfoText('Engineer Name', _reportDetails!['engineer_name']),
          _buildInfoText('Created', _reportDetails!['created_datetime']),
          const Divider(height: 30),
          _buildActionButton(
              'Root Cause',
              ReportRootCauseScreen(
                  reportId: _reportDetails!['report_index'],
                  reportUId: _reportDetails!['id'])),
          _buildActionButton(
              'Corrective Action',
              ReportCorrectiveActionScreen(
                  reportId: _reportDetails!['report_index'],
                  reportUId: _reportDetails!['id'])),
          _buildActionButton(
              'Effective Action',
              ReportEffectiveActionScreen(
                  reportId: _reportDetails!['report_index'],
                  reportUId: _reportDetails!['id'])),
          _buildActionButton(
              'Prevention',
              ReportPreventionActionScreen(
                  reportId: _reportDetails!['report_index'],
                  reportUId: _reportDetails!['id'])),
          _buildActionButton(
              'Suggestion',
              ReportSuggestionActionScreen(
                  reportId: _reportDetails!['report_index'],
                  reportUId: _reportDetails!['id'])),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _isDownloading ? null : _downloadPdf,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: _isDownloading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Download PDF Report'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoText(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        '$label: ${value ?? 'N/A'}',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildActionButton(String label, Widget screen) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => screen),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(label),
      ),
    );
  }
}

// This screen is only reachable on non-web platforms
class PdfViewerScreen extends StatelessWidget {
  final String pdfPath;

  const PdfViewerScreen({super.key, required this.pdfPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: SfPdfViewer.file(File(pdfPath)),
    );
  }
}
