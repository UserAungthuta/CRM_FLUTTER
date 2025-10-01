// lib/service/report_service.dart

import 'package:flutter/foundation.dart' show kIsWeb;

import 'report_service_io.dart';
//import 'report_service_web.dart';

// Abstract class to define the contract for both implementations.
// This ensures that both service classes have the same public methods.
abstract class BaseReportService {
  Future<List<Map<String, dynamic>>> fetchReports();
  Future<List<Map<String, dynamic>>> fetchCustomerProducts();
  Future<void> createReport({
    required String reportType,
    required String generatorSerialNumber,
    required String problemIssue,
    required String remarks,
    required int customerId,
    required List<dynamic>? imageFiles, // Use 'dynamic' for flexibility
    required dynamic videoFile,
  });
}

// The concrete class that your UI will use.
class ReportService implements BaseReportService {
  late final BaseReportService _service;

  // The constructor initializes the correct service based on the platform.
  ReportService() {
    if (kIsWeb) {
      _service = ReportServiceIO();
    } else {
      _service = ReportServiceIO();
    }
  }

  // Delegate the method calls to the appropriate platform-specific service.
  @override
  Future<List<Map<String, dynamic>>> fetchReports() => _service.fetchReports();

  @override
  Future<List<Map<String, dynamic>>> fetchCustomerProducts() =>
      _service.fetchCustomerProducts();

  @override
  Future<void> createReport({
    required String reportType,
    required String generatorSerialNumber,
    required String problemIssue,
    required String remarks,
    required int customerId,
    required List<dynamic>? imageFiles,
    required dynamic videoFile,
  }) =>
      _service.createReport(
        reportType: reportType,
        generatorSerialNumber: generatorSerialNumber,
        problemIssue: problemIssue,
        remarks: remarks,
        customerId: customerId,
        imageFiles: imageFiles,
        videoFile: videoFile,
      );
}
