// lib/services/report_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import '../utils/shared_prefs.dart';
import '../utils/api_config.dart';

class ReportService {
  final String _baseUrl = ApiConfig.baseUrl; // From api_config.dart

  // Helper function to get the access token from secure storage
  Future<String> _getAccessToken() async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Authentication token missing.");
    }
    return token;
  }

  // Helper function for sending a POST request with optional files
  Future<http.Response> _sendRequestWithFiles(String endpoint,
      Map<String, dynamic> data, List<File> imageFiles, File? videoFile) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    var request = http.MultipartRequest('POST', uri);
    final token = await _getAccessToken();

    // Set the authorization header
    request.headers['Authorization'] = 'Bearer $token';

    // Add form fields
    data.forEach((key, value) {
      request.fields[key] = value.toString();
    });

    // Add image files
    for (var file in imageFiles) {
      final mimeType = p.extension(file.path).toLowerCase().replaceAll('.', '');
      request.files.add(
        await http.MultipartFile.fromPath(
          'report_images[]', // Use array notation
          file.path,
          filename: p.basename(file.path),
          contentType: MediaType('image', mimeType),
        ),
      );
    }

    // Add video file
    if (videoFile != null) {
      final mimeType =
          p.extension(videoFile.path).toLowerCase().replaceAll('.', '');
      request.files.add(
        await http.MultipartFile.fromPath(
          'report_video', // Single video file
          videoFile.path,
          filename: p.basename(videoFile.path),
          contentType: MediaType('video', mimeType),
        ),
      );
    }

    final streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }

  // --- Create a new report ---
  Future<Map<String, dynamic>> createReport(
      {required String reportType,
      required String generatorSerialNumber,
      required String problemIssue,
      String? remarks,
      required List<File> imageFiles,
      File? videoFile,
      required int customerId}) async {
    final Map<String, dynamic> reportData = {
      'report_type': reportType,
      'generator_serial_number': generatorSerialNumber,
      'customer_id': customerId.toString(),
      'problem_issue': problemIssue,
      'remarks': remarks ?? '',
    };

    final response = await _sendRequestWithFiles(
        'reports/create', reportData, imageFiles, videoFile);

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Failed to create report: ${json.decode(response.body)['message']}');
    }
  }

  // --- Fetch all reports for the current customer ---
  Future<List<Map<String, dynamic>>> fetchReports() async {
    final token = await _getAccessToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/reports/readall'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData['success'] == true && responseData['data'] is List) {
        return List<Map<String, dynamic>>.from(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? 'Invalid data format.');
      }
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
          errorData['message'] ?? 'Failed to load reports. Server error.');
    }
  }

  // --- Fetch customer products ---
  Future<List<Map<String, dynamic>>> fetchCustomerProducts() async {
    final token = await _getAccessToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/customer-products/readall'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData['success'] == true && responseData['data'] is List) {
        return List<Map<String, dynamic>>.from(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? 'Invalid data format.');
      }
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ??
          'Failed to load customer products. Server error.');
    }
  }
}
