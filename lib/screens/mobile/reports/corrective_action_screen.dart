// corrective_action_screen.dart
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
enum CorrectiveActionView {
  list,
  create,
  update, // Added for update functionality
  detail, // Added for single corrective action detail view
}

class ReportCorrectiveActionScreen extends StatefulWidget {
  final String reportId;
  final int reportUId;
  const ReportCorrectiveActionScreen(
      {super.key, required this.reportId, required this.reportUId});

  @override
  _ReportCorrectiveActionScreenState createState() =>
      _ReportCorrectiveActionScreenState();
}

class _ReportCorrectiveActionScreenState
    extends State<ReportCorrectiveActionScreen> {
  final _formKey = GlobalKey<FormState>();
  late Future<List<Map<String, String>>> _correctiveActionFuture;
  CorrectiveActionView _currentView = CorrectiveActionView.list;
  final TextEditingController _correctiveActionTitleController =
      TextEditingController();

  // For media attachments
  List<XFile>? _correctiveActionImages;
  XFile? _correctiveActionVideo;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false; // For showing loading indicator during API calls
  Map<String, String>?
      _editingCorrectiveAction; // Holds data of the corrective action being edited
  Map<String, String>?
      _selectedCorrectiveAction; // Holds data of the corrective action being viewed in detail
  String? _reportStatus;

  // For video playback
  // VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _fetchCorrectiveActionsData();
    _fetchReportStatus();
  }

  @override
  void dispose() {
    _correctiveActionTitleController.dispose();
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

  // Refreshes the corrective action list data
  void _fetchCorrectiveActionsData() {
    setState(() {
      _correctiveActionFuture =
          _fetchCorrectiveActionsByReportId(widget.reportId);
    });
  }

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

  // New method to fetch corrective actions by report_index
  Future<List<Map<String, String>>> _fetchCorrectiveActionsByReportId(
      String reportId) async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          _showSnackBar(
              context, 'Authentication token missing. Please log in again.',
              color: Colors.red);
        }
        return [];
      }

      // Assuming your API has an endpoint like /corrective-action/readall-by-report/{report_index}
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/corrective-action/readall-by-report/$reportId');
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
          List<Map<String, String>> correctiveActions = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              correctiveActions.add({
                'id': item['id']?.toString() ?? '',
                'report_index': item['report_index']?.toString() ?? '',
                'corrective_action_title':
                    item['corrective_action_title'] as String? ?? 'N/A',
                'corrective_action_media_type':
                    item['corrective_action_media_type'] as String? ?? '',
                'corrective_action_media_path':
                    item['corrective_action_media_path'] as String? ?? '',
                'corrective_action_media_name':
                    item['corrective_action_media_name'] as String? ?? '',
                'created_user_name': item['created_user_name'] as String? ?? '',
                'created_user': item['created_user']?.toString() ?? 'N/A',
                'created_datetime':
                    item['created_datetime'] as String? ?? 'N/A',
                'modified_datetime':
                    item['modified_datetime'] as String? ?? 'N/A',
              });
            }
          }
          return correctiveActions;
        } else {
          if (mounted) {
            _showSnackBar(context,
                'Failed to load corrective actions. Invalid data format.',
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
                  'Failed to load corrective actions. Server error.',
              color: Colors.red);
        }
        return [];
      }
    } on Exception catch (e) {
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

  Future<void> _createCorrectiveAction() async {
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

    final Uri uri = Uri.parse('${ApiConfig.baseUrl}/corrective-action/create');
    var request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['report_index'] = widget.reportId
      ..fields['corrective_action_title'] =
          _correctiveActionTitleController.text;

    // Add images
    if (_correctiveActionImages != null) {
      for (var image in _correctiveActionImages!) {
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
    if (_correctiveActionVideo != null) {
      Uint8List videoBytes = await _correctiveActionVideo!.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'media_video', // Use a distinct name for video
          videoBytes,
          filename: _correctiveActionVideo!.name, // Use XFile's name property
          contentType:
              MediaType('video', _correctiveActionVideo!.name.split('.').last),
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
            _showSnackBar(context, 'Corrective Action created successfully!',
                color: Colors.green);
            _clearForm();
            setState(() {
              _currentView = CorrectiveActionView.list;
              _fetchCorrectiveActionsData(); // Refresh list
            });
          }
        } else {
          if (mounted) {
            _showSnackBar(
                context,
                responseData['message'] ??
                    'Failed to create corrective action.',
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
          errorMessage = 'Invalid response hehehe from server.';
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

  Future<void> _updateCorrectiveAction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_editingCorrectiveAction == null) {
      _showSnackBar(context, 'No corrective action selected for update.',
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
        '${ApiConfig.baseUrl}/corrective-action/update/${_editingCorrectiveAction!['id']}');
    var request = http.MultipartRequest('POST', uri) // Use PUT for update
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['report_index'] = widget.reportId
      ..fields['corrective_action_title'] =
          _correctiveActionTitleController.text;

    // Add images (re-upload or new images)
    if (_correctiveActionImages != null &&
        _correctiveActionImages!.isNotEmpty) {
      for (var image in _correctiveActionImages!) {
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
    if (_correctiveActionVideo != null) {
      Uint8List videoBytes = await _correctiveActionVideo!.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'media_video',
          videoBytes,
          filename: _correctiveActionVideo!.name, // Use XFile's name property
          contentType:
              MediaType('video', _correctiveActionVideo!.name.split('.').last),
        ),
      );
      request.fields['media_type'] = 'video';
    } else if (_correctiveActionImages != null &&
        _correctiveActionImages!.isEmpty &&
        _editingCorrectiveAction!['corrective_action_media_path'] != null &&
        _editingCorrectiveAction!['corrective_action_media_path']!.isNotEmpty) {
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
            _showSnackBar(context, 'Corrective Action updated successfully!',
                color: Colors.green);
            _clearForm();
            setState(() {
              _currentView = CorrectiveActionView.list;
              _editingCorrectiveAction = null;
              _fetchCorrectiveActionsData(); // Refresh list
            });
          }
        } else {
          if (mounted) {
            _showSnackBar(
                context,
                responseData['message'] ??
                    'Failed to update corrective action.',
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

  Future<void> _deleteCorrectiveAction(String correctiveActionId) async {
    final bool confirmDelete = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text(
                'Are you sure you want to delete this corrective action?'),
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
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/corrective-action/delete/$correctiveActionId');
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
            _showSnackBar(context, 'Corrective Action deleted successfully!',
                color: Colors.green);
            _fetchCorrectiveActionsData(); // Refresh list
          }
        } else {
          if (mounted) {
            _showSnackBar(
                context,
                responseData['message'] ??
                    'Failed to delete corrective action.',
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
    _correctiveActionTitleController.clear();
    setState(() {
      _correctiveActionImages = null;
      _correctiveActionVideo = null;
    });
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    setState(() {
      _correctiveActionImages = images;
      _correctiveActionVideo = null; // Clear video if images are picked
    });
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _correctiveActionVideo = video;
        _correctiveActionImages = null; // Clear images if video is picked
      });
    }
  }

  Widget _buildListContent() {
    bool isReportCompleted = _reportStatus == 'completed';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Corrective Actions for Report ID: ${widget.reportId}',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (!isReportCompleted)
          ElevatedButton.icon(
            onPressed: () {
              _clearForm();
              setState(() {
                _currentView = CorrectiveActionView.create;
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Corrective Action'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF336EE5),
              foregroundColor: Colors.white,
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Map<String, String>>>(
            future: _correctiveActionFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                    child:
                        Text('No corrective actions found for this report.'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final correctiveAction = snapshot.data![index];
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
                            _selectedCorrectiveAction = correctiveAction;
                            _currentView = CorrectiveActionView.detail;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Title: ${correctiveAction['corrective_action_title']}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                  'Created By: ${correctiveAction['created_user_name']}'),
                              Text(
                                  'Created On: ${correctiveAction['created_datetime']}'),
                              if (correctiveAction[
                                          'corrective_action_media_path'] !=
                                      null &&
                                  correctiveAction[
                                          'corrective_action_media_path']!
                                      .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Media: ${correctiveAction['corrective_action_media_name']} (${correctiveAction['corrective_action_media_type']})',
                                    style: const TextStyle(
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              if (!isReportCompleted)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _editingCorrectiveAction =
                                              correctiveAction;
                                          _correctiveActionTitleController
                                                  .text =
                                              correctiveAction[
                                                  'corrective_action_title']!;
                                          _correctiveActionImages =
                                              null; // Clear selected images
                                          _correctiveActionVideo =
                                              null; // Clear selected video
                                          _currentView =
                                              CorrectiveActionView.update;
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
                                        _deleteCorrectiveAction(
                                            correctiveAction['id']!);
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
              'Create Corrective Action for Report ID: ${widget.reportId}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _correctiveActionTitleController,
              decoration: const InputDecoration(
                labelText: 'Corrective Action Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a corrective action title';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildMediaPickerButtons(),
            if (_correctiveActionImages != null &&
                _correctiveActionImages!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child:
                    Text('Selected Images: ${_correctiveActionImages!.length}'),
              ),
            if (_correctiveActionVideo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Selected Video: ${_correctiveActionVideo!.name}'),
              ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _createCorrectiveAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF336EE5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Submit Corrective Action',
                        style: TextStyle(fontSize: 18)),
                  ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                _clearForm();
                setState(() {
                  _currentView = CorrectiveActionView.list;
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
    if (_editingCorrectiveAction == null) {
      return const Center(
          child: Text('Error: No corrective action selected for update.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Update Corrective Action (ID: ${_editingCorrectiveAction!['id']}) for Report ID: ${widget.reportId}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _correctiveActionTitleController,
              decoration: const InputDecoration(
                labelText: 'Corrective Action Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a corrective action title';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            // Display existing media if any
            if (_editingCorrectiveAction!['corrective_action_media_path'] !=
                    null &&
                _editingCorrectiveAction!['corrective_action_media_path']!
                    .isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  'Existing Media: ${_editingCorrectiveAction!['corrective_action_media_name']} (${_editingCorrectiveAction!['corrective_action_media_type']})',
                  style: const TextStyle(
                      fontStyle: FontStyle.italic, color: Colors.blueGrey),
                ),
              ),
            _buildMediaPickerButtons(),
            if (_correctiveActionImages != null &&
                _correctiveActionImages!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                    'New Selected Images: ${_correctiveActionImages!.length}'),
              ),
            if (_correctiveActionVideo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child:
                    Text('New Selected Video: ${_correctiveActionVideo!.name}'),
              ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _updateCorrectiveAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.orange, // Use a different color for update
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Update Corrective Action',
                        style: TextStyle(fontSize: 18)),
                  ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                _clearForm();
                setState(() {
                  _currentView = CorrectiveActionView.list;
                  _editingCorrectiveAction = null;
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
    if (_selectedCorrectiveAction == null) {
      return const Center(
          child: Text('No corrective action selected to view.'));
    }

    final String? mediaPath =
        _selectedCorrectiveAction!['corrective_action_media_path'];
    final String? mediaType =
        _selectedCorrectiveAction!['corrective_action_media_type'];
    final String? mediaName =
        _selectedCorrectiveAction!['corrective_action_media_name'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Corrective Action Details (ID: ${_selectedCorrectiveAction!['id']})',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(
            'Title: ${_selectedCorrectiveAction!['corrective_action_title']}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text('Created By: ${_selectedCorrectiveAction!['created_user']}'),
          Text('Created On: ${_selectedCorrectiveAction!['created_datetime']}'),
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
                      '${ApiConfig.baseUrl}/public/$mediaPath', // Assuming mediaPath is relative to baseUrl
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
            const Text('No media attached to this corrective action.'),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              // Dispose video controller if it was initialized
              // _videoController?.dispose();
              // _videoController = null;
              setState(() {
                _selectedCorrectiveAction = null;
                _currentView = CorrectiveActionView.list;
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
        if ((_correctiveActionImages != null &&
                _correctiveActionImages!.isNotEmpty) ||
            _correctiveActionVideo != null ||
            (_editingCorrectiveAction != null &&
                _editingCorrectiveAction!['corrective_action_media_path'] !=
                    null &&
                _editingCorrectiveAction!['corrective_action_media_path']!
                    .isNotEmpty))
          TextButton.icon(
            onPressed: () {
              setState(() {
                _correctiveActionImages = null;
                _correctiveActionVideo = null;
                // If in update mode, also clear existing media path for explicit removal
                if (_editingCorrectiveAction != null) {
                  _editingCorrectiveAction!['corrective_action_media_path'] =
                      '';
                  _editingCorrectiveAction!['corrective_action_media_name'] =
                      '';
                  _editingCorrectiveAction!['corrective_action_media_type'] =
                      '';
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
        title: const Text('Corrective Actions'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentView) {
      case CorrectiveActionView.list:
        return _buildListContent();
      case CorrectiveActionView.create:
        return _buildCreateContent();
      case CorrectiveActionView.update:
        return _buildUpdateContent();
      case CorrectiveActionView.detail: // Handle the new detail view
        return _buildDetailContent();
      default:
        return _buildListContent(); // Fallback to list view
    }
  }
}
