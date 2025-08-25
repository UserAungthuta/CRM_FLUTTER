// root_cause_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart'; // Required for MediaType
import 'dart:typed_data'; // Required for Uint8List
// Import for video_player, uncomment if you add the dependency
// import 'package:video_player/video_player.dart';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

// Enum to manage the current view state
enum RootCauseView {
  list,
  create,
  update, // Added for update functionality
  detail, // Added for single root cause detail view
}

class ReportRootCauseScreen extends StatefulWidget {
  final String reportId;
  final int reportUId;
  const ReportRootCauseScreen(
      {super.key, required this.reportId, required this.reportUId});

  @override
  _ReportRootCauseScreenState createState() => _ReportRootCauseScreenState();
}

class _ReportRootCauseScreenState extends State<ReportRootCauseScreen> {
  final _formKey = GlobalKey<FormState>();
  late Future<List<Map<String, String>>> _rootCauseFuture;
  RootCauseView _currentView = RootCauseView.list;
  final TextEditingController _rootcausetitleController =
      TextEditingController();
  String? _currentUserRole;
  // For media attachments
  List<XFile>? _rootcauseImages;
  XFile? _rootcauseVideo;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false; // For showing loading indicator during API calls
  Map<String, String>?
      _editingRootCause; // Holds data of the root cause being edited
  Map<String, String>?
      _selectedRootCause; // Holds data of the root cause being viewed in detail

  String? _reportStatus; // Added to store the main report's status

  // For video playback
  // VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _fetchRootCausesData();
    _fetchReportStatus(); // Fetch the main report status
  }

  @override
  void dispose() {
    _rootcausetitleController.dispose();
    // _videoController?.dispose(); // Dispose video controller
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

  // Refreshes the root cause list data
  void _fetchRootCausesData() {
    setState(() {
      _rootCauseFuture = _fetchRootCausesByReportId(widget.reportId);
    });
  }

  // New method to fetch the main report's status
  Future<void> _fetchReportStatus() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          _showSnackBar(
              context, 'Authentication token missing. Please log in again.',
              color: Colors.red);
        }
        return;
      }

      // Assuming you have an API endpoint to get a single report's details
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/reports/read/${widget.reportUId}'); // Example endpoint
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true &&
            responseData['data'] is Map<String, dynamic>) {
          setState(() {
            _reportStatus = responseData['data']['status'] as String?;
          });
        } else {
          if (mounted) {
            _showSnackBar(
                context, 'Failed to load report status. Invalid data format.',
                color: Colors.red);
          }
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          _showSnackBar(
              context,
              errorData['message'] ??
                  'Failed to load report status. Server error.',
              color: Colors.red);
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        String errorMessage =
            'An error occurred fetching report status: ${e.toString()}';
        if (e is TimeoutException) {
          errorMessage = 'Request timed out. Server not responding.';
        } else if (e.toString().contains('SocketException')) {
          errorMessage = 'Network error. Check your internet connection.';
        } else if (e.toString().contains('FormatException')) {
          errorMessage = 'Invalid response format from server.';
        }
        _showSnackBar(context, errorMessage, color: Colors.red);
      }
    }
  }

  // New method to fetch root causes by report_index
  Future<List<Map<String, String>>> _fetchRootCausesByReportId(
      String reportId) async {
    try {
      _currentUserRole = await SharedPrefs.getUserRole();
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          _showSnackBar(
              context, 'Authentication token missing. Please log in again.',
              color: Colors.red);
        }
        return [];
      }

      // Assuming your API has an endpoint like /root-cause/readall-by-report/{report_index}
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/root-cause/readall-by-report/$reportId');
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
          List<Map<String, String>> rootCauses = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              rootCauses.add({
                'id': item['id']?.toString() ?? '',
                'report_index': item['report_index']?.toString() ?? '',
                'root_cause_title':
                    item['root_cause_title'] as String? ?? 'N/A',
                'root_cause_media_type':
                    item['root_cause_media_type'] as String? ?? '',
                'root_cause_media_path':
                    item['root_cause_media_path'] as String? ?? '',
                'root_cause_media_name':
                    item['root_cause_media_name'] as String? ?? '',
                'created_user_name': item['created_user_name'] as String? ?? '',
                'created_user': item['created_user']?.toString() ?? 'N/A',
                'report_status': item['report_status']?.toString() ?? 'N/A',
                'created_datetime':
                    item['created_datetime'] as String? ?? 'N/A',
                'modified_datetime':
                    item['modified_datetime'] as String? ?? 'N/A',
              });
            }
          }
          return rootCauses;
        } else {
          if (mounted) {
            _showSnackBar(
                context, 'Failed to load root causes. Invalid data format.',
                color: Colors.red);
          }
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          _showSnackBar(
              context,
              errorData['message'] ??
                  'Failed to load root causes. Server error.',
              color: Colors.red);
        }
        return [];
      }
    } on Exception catch (e) {
      // Changed SocketException, TimeoutException, FormatException to a general Exception catch
      // as SocketException and FormatException are not available on web.
      if (mounted) {
        String errorMessage = 'An error occurred: ${e.toString()}';
        if (e is TimeoutException) {
          errorMessage = 'Request timed out. Server not responding.';
        } else if (e.toString().contains('SocketException')) {
          errorMessage = 'Network error. Check your internet connection.';
        } else if (e.toString().contains('FormatException')) {
          errorMessage = 'Invalid response format from server.';
        }
        _showSnackBar(context, errorMessage, color: Colors.red);
      }
      return [];
    }
  }

  Future<void> _createRootCause() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        _showSnackBar(context, 'Authentication token missing.',
            color: Colors.red);
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final Uri uri = Uri.parse('${ApiConfig.baseUrl}/root-cause/create');
    var request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['report_index'] = widget.reportId
      ..fields['root_cause_title'] = _rootcausetitleController.text;

    // Add images
    if (_rootcauseImages != null) {
      for (var image in _rootcauseImages!) {
        // Read file as bytes instead of path
        Uint8List fileBytes = await image.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'media[]', // Use 'media[]' for multiple files
            fileBytes,
            filename: image.name, // Use XFile's name property
            contentType: MediaType('image', image.name.split('.').last),
          ),
        );
      }
      request.fields['media_type'] = 'image';
    }

    // Add video
    if (_rootcauseVideo != null) {
      // Read file as bytes instead of path
      Uint8List videoBytes = await _rootcauseVideo!.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'media_video', // Use a distinct name for video
          videoBytes,
          filename: _rootcauseVideo!.name, // Use XFile's name property
          contentType:
              MediaType('video', _rootcauseVideo!.name.split('.').last),
        ),
      );
      request.fields['media_type'] = 'video';
    }

    try {
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          if (mounted) {
            _showSnackBar(context, 'Root Cause created successfully!',
                color: Colors.green);
            _clearForm();
            setState(() {
              _currentView = RootCauseView.list;
              _fetchRootCausesData(); // Refresh list
            });
          }
        } else {
          if (mounted) {
            _showSnackBar(context,
                responseData['message'] ?? 'Failed to create root cause.',
                color: Colors.red);
          }
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          _showSnackBar(
              context, errorData['message'] ?? 'Server error during creation.',
              color: Colors.red);
        }
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
        _showSnackBar(context, errorMessage, color: Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateRootCause() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_editingRootCause == null) {
      _showSnackBar(context, 'No root cause selected for update.',
          color: Colors.red);
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        _showSnackBar(context, 'Authentication token missing.',
            color: Colors.red);
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final Uri uri = Uri.parse(
        '${ApiConfig.baseUrl}/root-cause/update/${_editingRootCause!['id']}');
    var request = http.MultipartRequest('POST', uri) // Use PUT for update
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['report_index'] = widget.reportId
      ..fields['root_cause_title'] = _rootcausetitleController.text;

    // Add images (re-upload or new images)
    if (_rootcauseImages != null && _rootcauseImages!.isNotEmpty) {
      for (var image in _rootcauseImages!) {
        // Read file as bytes instead of path
        Uint8List fileBytes = await image.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'media[]',
            fileBytes,
            filename: image.name, // Use XFile's name property
            contentType: MediaType('image', image.name.split('.').last),
          ),
        );
      }
      request.fields['media_type'] = 'image';
    }
    // Add video (re-upload or new video)
    if (_rootcauseVideo != null) {
      // Read file as bytes instead of path
      Uint8List videoBytes = await _rootcauseVideo!.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'media_video',
          videoBytes,
          filename: _rootcauseVideo!.name, // Use XFile's name property
          contentType:
              MediaType('video', _rootcauseVideo!.name.split('.').last),
        ),
      );
      request.fields['media_type'] = 'video';
    } else if (_rootcauseImages != null &&
        _rootcauseImages!.isEmpty &&
        _editingRootCause!['root_cause_media_path'] != null &&
        _editingRootCause!['root_cause_media_path']!.isNotEmpty) {
      // If no new media and there was existing media, explicitly indicate no media for current update to clear existing if any
      request.fields['clear_media'] = '1';
    }

    try {
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          if (mounted) {
            _showSnackBar(context, 'Root Cause updated successfully!',
                color: Colors.green);
            _clearForm();
            setState(() {
              _currentView = RootCauseView.list;
              _editingRootCause = null;
              _fetchRootCausesData(); // Refresh list
            });
          }
        } else {
          if (mounted) {
            _showSnackBar(context,
                responseData['message'] ?? 'Failed to update root cause.',
                color: Colors.red);
          }
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          _showSnackBar(
              context, errorData['message'] ?? 'Server error during update.',
              color: Colors.red);
        }
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
        _showSnackBar(context, errorMessage, color: Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRootCause(String rootCauseId) async {
    final bool confirmDelete = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content:
                const Text('Are you sure you want to delete this root cause?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmDelete) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        _showSnackBar(context, 'Authentication token missing.',
            color: Colors.red);
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/root-cause/delete/$rootCauseId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          if (mounted) {
            _showSnackBar(context, 'Root Cause deleted successfully!',
                color: Colors.green);
            _fetchRootCausesData(); // Refresh list
          }
        } else {
          if (mounted) {
            _showSnackBar(context,
                responseData['message'] ?? 'Failed to delete root cause.',
                color: Colors.red);
          }
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          _showSnackBar(
              context, errorData['message'] ?? 'Server error during deletion.',
              color: Colors.red);
        }
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
        _showSnackBar(context, errorMessage, color: Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearForm() {
    _rootcausetitleController.clear();
    setState(() {
      _rootcauseImages = null;
      _rootcauseVideo = null;
    });
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    setState(() {
      _rootcauseImages = images;
      _rootcauseVideo = null; // Clear video if images are picked
    });
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _rootcauseVideo = video;
        _rootcauseImages = null; // Clear images if video is picked
      });
    }
  }

  Widget _buildListContent() {
    // Check if _reportStatus is 'completed'
    bool isReportCompleted = _reportStatus == 'completed';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Root Causes for Report ID: ${widget.reportId}',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Conditionally display the "Add Root Cause" button
        if (!isReportCompleted) // Show only if report is not completed
          ElevatedButton.icon(
            onPressed: () {
              _clearForm();
              setState(() {
                _currentView = RootCauseView.create;
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Root Cause'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF336EE5),
              foregroundColor: Colors.white,
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Map<String, String>>>(
            future: _rootCauseFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                    child: Text('No root causes found for this report.'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final rootCause = snapshot.data![index];
                    // The `iscomplete` variable here checks individual root cause status,
                    // which might be different from the main report status.
                    // Keep it if you want to conditionally show edit/delete based on individual root cause status.
                    // If you want to control based on the *main report* status, use `isReportCompleted`
                    bool iscompleteRootCause =
                        rootCause['report_status'] == 'completed';
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: InkWell(
                        // Make the card clickable
                        onTap: () {
                          setState(() {
                            _selectedRootCause = rootCause;
                            _currentView = RootCauseView.detail;
                          });
                        },

                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Title: ${rootCause['root_cause_title']}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                  'Created By: ${rootCause['created_user_name']}'),
                              Text(
                                  'Created On: ${rootCause['created_datetime']}'),
                              if (rootCause['root_cause_media_path'] != null &&
                                  rootCause['root_cause_media_path']!
                                      .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Media: ${rootCause['root_cause_media_name']} (${rootCause['root_cause_media_type']})',
                                    style: const TextStyle(
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              // Conditionally show Edit/Delete based on the *main report* status
                              if (!isReportCompleted)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _editingRootCause = rootCause;
                                          _rootcausetitleController.text =
                                              rootCause['root_cause_title']!;
                                          _rootcauseImages =
                                              null; // Clear selected images
                                          _rootcauseVideo =
                                              null; // Clear selected video
                                          _currentView = RootCauseView.update;
                                        });
                                      },
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Edit'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF336EE5),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        _deleteRootCause(rootCause['id']!);
                                      },
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Delete'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
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

  Widget _buildCreateContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create Root Cause for Report ID: ${widget.reportId}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _rootcausetitleController,
              decoration: const InputDecoration(
                labelText: 'Root Cause Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a root cause title';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildMediaPickerButtons(),
            if (_rootcauseImages != null && _rootcauseImages!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Selected Images: ${_rootcauseImages!.length}'),
              ),
            if (_rootcauseVideo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Selected Video: ${_rootcauseVideo!.name}'),
              ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _createRootCause,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF336EE5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Submit Root Cause',
                        style: TextStyle(fontSize: 18)),
                  ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                _clearForm();
                setState(() {
                  _currentView = RootCauseView.list;
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
      ),
    );
  }

  Widget _buildUpdateContent() {
    if (_editingRootCause == null) {
      return const Center(
          child: Text('Error: No root cause selected for update.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Update Root Cause (ID: ${_editingRootCause!['id']}) for Report ID: ${widget.reportId}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _rootcausetitleController,
              decoration: const InputDecoration(
                labelText: 'Root Cause Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a root cause title';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            // Display existing media if any
            if (_editingRootCause!['root_cause_media_path'] != null &&
                _editingRootCause!['root_cause_media_path']!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  'Existing Media: ${_editingRootCause!['root_cause_media_name']} (${_editingRootCause!['root_cause_media_type']})',
                  style: const TextStyle(
                      fontStyle: FontStyle.italic, color: Colors.blueGrey),
                ),
              ),
            _buildMediaPickerButtons(),
            if (_rootcauseImages != null && _rootcauseImages!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('New Selected Images: ${_rootcauseImages!.length}'),
              ),
            if (_rootcauseVideo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('New Selected Video: ${_rootcauseVideo!.name}'),
              ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _updateRootCause,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.orange, // Use a different color for update
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Update Root Cause',
                        style: TextStyle(fontSize: 18)),
                  ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                _clearForm();
                setState(() {
                  _currentView = RootCauseView.list;
                  _editingRootCause = null;
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
      ),
    );
  }

  Widget _buildDetailContent() {
    if (_selectedRootCause == null) {
      return const Center(child: Text('No root cause selected to view.'));
    }

    final String? mediaPath = _selectedRootCause!['root_cause_media_path'];
    final String? mediaType = _selectedRootCause!['root_cause_media_type'];
    final String? mediaName = _selectedRootCause!['root_cause_media_name'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Root Cause Details (ID: ${_selectedRootCause!['id']})',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(
            'Title: ${_selectedRootCause!['root_cause_title']}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text('Created By: ${_selectedRootCause!['created_user_name']}'),
          Text('Created On: ${_selectedRootCause!['created_datetime']}'),
          const SizedBox(height: 20),
          if (mediaPath != null && mediaPath.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media Attachment: $mediaName',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (mediaType == 'image')
                  Center(
                    child: Image.network(
                      '${ApiConfig.baseUrl}/$mediaPath', // Assuming mediaPath is relative to baseUrl
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.broken_image,
                          size: 100,
                          color: Colors.grey),
                    ),
                  )
                else if (mediaType == 'video')
                  Column(
                    children: [
                      // Placeholder for video player.
                      // You'll need to add the 'video_player' package to your pubspec.yaml
                      // and implement VideoPlayerController.
                      // Example:
                      // _videoController = VideoPlayerController.network(
                      //   '${ApiConfig.baseUrl}/$mediaPath',
                      // )..initialize().then((_) {
                      //   setState(() {}); // setState to rebuild after initialization
                      // });
                      // if (_videoController != null && _videoController!.value.isInitialized)
                      //   AspectRatio(
                      //     aspectRatio: _videoController!.value.aspectRatio,
                      //     child: VideoPlayer(_videoController!),
                      //   )
                      // else
                      Container(
                        color: Colors.black,
                        height: 200,
                        alignment: Alignment.center,
                        child: const Text(
                          'Video playback not implemented in this example.\nRequires video_player package.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Video controls (play/pause) can be added here
                    ],
                  )
                else
                  Text('Unsupported media type: $mediaType'),
              ],
            )
          else
            const Text('No media attached to this root cause.'),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              // Dispose video controller if it was initialized
              // _videoController?.dispose();
              // _videoController = null;
              setState(() {
                _selectedRootCause = null;
                _currentView = RootCauseView.list;
              });
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to List'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPickerButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.image),
                label: const Text('Pick Images'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_file),
                label: const Text('Pick Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        if ((_rootcauseImages != null && _rootcauseImages!.isNotEmpty) ||
            _rootcauseVideo != null ||
            (_editingRootCause != null &&
                _editingRootCause!['root_cause_media_path'] != null &&
                _editingRootCause!['root_cause_media_path']!.isNotEmpty))
          TextButton.icon(
            onPressed: () {
              setState(() {
                _rootcauseImages = null;
                _rootcauseVideo = null;
                // If in update mode, also clear existing media path for explicit removal
                if (_editingRootCause != null) {
                  _editingRootCause!['root_cause_media_path'] = '';
                  _editingRootCause!['root_cause_media_name'] = '';
                  _editingRootCause!['root_cause_media_type'] = '';
                }
              });
            },
            icon: const Icon(Icons.clear, color: Colors.red),
            label: const Text('Clear Selected Media',
                style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Root Causes'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentView) {
      case RootCauseView.list:
        return _buildListContent();
      case RootCauseView.create:
        return _buildCreateContent();
      case RootCauseView.update:
        return _buildUpdateContent();
      case RootCauseView.detail: // Handle the new detail view
        return _buildDetailContent();
      default:
        return _buildListContent(); // Fallback to list view
    }
  }
}
