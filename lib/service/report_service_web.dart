// lib/service/report_service_web.dart

import 'dart:convert';
//import 'dart:html' as html;

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../utils/api_config.dart';
import '../utils/shared_prefs.dart';
import 'report_service.dart';

class ReportServiceWeb extends BaseReportService {
  final String _baseUrl = ApiConfig.baseUrl;

  Future<String> _getAccessToken() async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Authentication token missing.");
    }
    return token;
  }

  @override
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

  @override
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

  @override
  Future<void> createReport({
    required String reportType,
    required String generatorSerialNumber,
    required String problemIssue,
    required String remarks,
    required int customerId,
    required List<dynamic>? imageFiles,
    required dynamic videoFile,
  }) async {
    final uri = Uri.parse('$_baseUrl/reports/create');
    var request = http.MultipartRequest('POST', uri);
    final token = await _getAccessToken();

    request.headers['Authorization'] = 'Bearer $token';

    request.fields['report_type'] = reportType;
    request.fields['generator_serial_number'] = generatorSerialNumber;
    request.fields['customer_id'] = customerId.toString();
    request.fields['problem_issue'] = problemIssue;
    request.fields['remarks'] = remarks;

    if (imageFiles != null) {
      for (var xFile in imageFiles) {
        // Cast the dynamic list item to XFile
        // final file = html.File([await xFile.readAsBytes()], xFile.name);
        final bytes = await xFile.readAsBytes();
        final mimeType = lookupMimeType(xFile.name, headerBytes: bytes);
        request.files.add(
          http.MultipartFile.fromBytes(
            'images[]',
            bytes,
            // filename: file.name,
            contentType: MediaType.parse(mimeType!),
          ),
        );
      }
    }

    if (videoFile != null) {
      // Cast the dynamic video file to XFile
      //final file = html.File([await videoFile.readAsBytes()], videoFile.name);
      final bytes = await videoFile.readAsBytes();
      final mimeType = lookupMimeType(videoFile.name, headerBytes: bytes);
      request.files.add(
        http.MultipartFile.fromBytes(
          'video',
          bytes,
          //filename: file.name,
          contentType: MediaType.parse(mimeType!),
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 201) {
      throw Exception(
          'Failed to create report: ${json.decode(response.body)['message']}');
    }
  }
}
