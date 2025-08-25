// prevention_action_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

// Enum to manage the current view state
enum PreventionActionView {
  list,
  create,
  update, // Added for update functionality
  detail, // Added for single prevention action detail view
}

class ReportPreventionActionScreen extends StatefulWidget {
  final String reportId;
  final int reportUId;
  const ReportPreventionActionScreen(
      {super.key, required this.reportId, required this.reportUId});

  @override
  _ReportPreventionActionScreenState createState() =>
      _ReportPreventionActionScreenState();
}

class _ReportPreventionActionScreenState
    extends State<ReportPreventionActionScreen> {
  final _formKey = GlobalKey<FormState>();
  late Future<List<Map<String, String>>> _preventionActionFuture;
  PreventionActionView _currentView = PreventionActionView.list;
  final TextEditingController _preventionActionTitleController =
      TextEditingController();

  bool _isLoading = false; // For showing loading indicator during API calls
  Map<String, String>?
      _editingPreventionAction; // Holds data of the prevention action being edited
  Map<String, String>?
      _selectedPreventionAction; // Holds data of the prevention action being viewed in detail
  String? _reportStatus;

  @override
  void initState() {
    super.initState();
    _fetchPreventionActionsData();
    _fetchReportStatus();
  }

  @override
  void dispose() {
    _preventionActionTitleController.dispose();
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

  // Refreshes the prevention action list data
  void _fetchPreventionActionsData() {
    setState(() {
      _preventionActionFuture =
          _fetchPreventionActionsByReportId(widget.reportId);
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

  // New method to fetch prevention actions by report_index
  Future<List<Map<String, String>>> _fetchPreventionActionsByReportId(
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

      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/prevention/read-by-report/$reportId'); // Adjusted API endpoint
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
          List<Map<String, String>> preventionActions = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              preventionActions.add({
                'id': item['id']?.toString() ?? '',
                'report_index': item['report_index']?.toString() ?? '',
                'prevention_title':
                    item['prevention_title'] as String? ?? 'N/A',
                'created_user_name':
                    item['created_user_name'] as String? ?? 'N/A',
                'created_user': item['created_user']?.toString() ?? 'N/A',
                'created_datetime':
                    item['created_datetime'] as String? ?? 'N/A',
                'modified_datetime':
                    item['modified_datetime'] as String? ?? 'N/A',
              });
            }
          }
          return preventionActions;
        } else {
          if (mounted) {
            _showSnackBar(context,
                'Failed to load prevention actions. Invalid data format or success status.',
                color: Colors.red);
          }
          return [];
        }
      } else {
        String errorMessage = 'Server error during fetching.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Server responded with status ${response.statusCode}.';
        }
        if (mounted) {
          _showSnackBar(context, errorMessage, color: Colors.red);
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

  Future<void> _createPreventionAction() async {
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

    final Uri uri = Uri.parse('${ApiConfig.baseUrl}/prevention/create');
    var request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['report_index'] = widget.reportId
      ..fields['prevention_title'] = _preventionActionTitleController.text;

    try {
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          if (mounted) {
            _showSnackBar(context, 'Prevention Action created successfully!',
                color: Colors.green);
            _clearForm();
            setState(() {
              _currentView = PreventionActionView.list;
              _fetchPreventionActionsData(); // Refresh list
            });
          }
        } else {
          if (mounted) {
            _showSnackBar(
                context,
                responseData['message'] ??
                    'Failed to create prevention action.',
                color: Colors.red);
          }
        }
      } else {
        String errorMessage = 'Server error during creation.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Server responded with status ${response.statusCode}.';
        }
        if (mounted) {
          _showSnackBar(context, errorMessage, color: Colors.red);
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

  Future<void> _updatePreventionAction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_editingPreventionAction == null) {
      _showSnackBar(context, 'No prevention action selected for update.',
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
        '${ApiConfig.baseUrl}/prevention/update/${_editingPreventionAction!['id']}');
    var request = http.MultipartRequest(
        'POST', uri) // Changed to POST to match index.php routing
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['report_index'] = widget.reportId
      ..fields['prevention_title'] = _preventionActionTitleController.text;

    try {
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          if (mounted) {
            _showSnackBar(context, 'Prevention Action updated successfully!',
                color: Colors.green);
            _clearForm();
            setState(() {
              _currentView = PreventionActionView.list;
              _editingPreventionAction = null;
              _fetchPreventionActionsData(); // Refresh list
            });
          }
        } else {
          if (mounted) {
            _showSnackBar(
                context,
                responseData['message'] ??
                    'Failed to update prevention action.',
                color: Colors.red);
          }
        }
      } else {
        String errorMessage = 'Server error during update.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Server responded with status ${response.statusCode}.';
        }
        if (mounted) {
          _showSnackBar(context, errorMessage, color: Colors.red);
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

  Future<void> _deletePreventionAction(String preventionActionId) async {
    final bool confirmDelete = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text(
                'Are you sure you want to delete this prevention action?'),
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
          '${ApiConfig.baseUrl}/prevention/delete/$preventionActionId');
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
            _showSnackBar(context, 'Prevention Action deleted successfully!',
                color: Colors.green);
            _fetchPreventionActionsData(); // Refresh list
          }
        } else {
          if (mounted) {
            _showSnackBar(
                context,
                responseData['message'] ??
                    'Failed to delete prevention action.',
                color: Colors.red);
          }
        }
      } else {
        String errorMessage = 'Server error during deletion.';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Server responded with status ${response.statusCode}.';
        }
        if (mounted) {
          _showSnackBar(context, errorMessage, color: Colors.red);
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
    _preventionActionTitleController.clear();
    setState(() {});
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
                'Prevention Actions for Report ID: ${widget.reportId}',
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
                _currentView = PreventionActionView.create;
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Prevention Action'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF336EE5),
              foregroundColor: Colors.white,
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Map<String, String>>>(
            future: _preventionActionFuture,
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
                        Text('No prevention actions found for this report.'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final preventionAction = snapshot.data![index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedPreventionAction = preventionAction;
                            _currentView = PreventionActionView.detail;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Title: ${preventionAction['prevention_title']}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                  'Created By: ${preventionAction['created_user_name']}'),
                              Text(
                                  'Created On: ${preventionAction['created_datetime']}'),
                              const SizedBox(height: 10),
                              if (!isReportCompleted)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _editingPreventionAction =
                                              preventionAction;
                                          _preventionActionTitleController
                                                  .text =
                                              preventionAction[
                                                  'prevention_title']!;
                                          _currentView =
                                              PreventionActionView.update;
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
                                        _deletePreventionAction(
                                            preventionAction['id']!);
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
              'Create Prevention Action for Report ID: ${widget.reportId}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _preventionActionTitleController,
              decoration: const InputDecoration(
                labelText: 'Prevention Action Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a prevention action title';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _createPreventionAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF336EE5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Submit Prevention Action',
                        style: TextStyle(fontSize: 18)),
                  ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                _clearForm();
                setState(() {
                  _currentView = PreventionActionView.list;
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
    if (_editingPreventionAction == null) {
      return const Center(
          child: Text('Error: No prevention action selected for update.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Update Prevention Action (ID: ${_editingPreventionAction!['id']}) for Report ID: ${widget.reportId}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _preventionActionTitleController,
              decoration: const InputDecoration(
                labelText: 'Prevention Action Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a prevention action title';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _updatePreventionAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.orange, // Use a different color for update
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Update Prevention Action',
                        style: TextStyle(fontSize: 18)),
                  ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                _clearForm();
                setState(() {
                  _currentView = PreventionActionView.list;
                  _editingPreventionAction = null;
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
    if (_selectedPreventionAction == null) {
      return const Center(
          child: Text('No prevention action selected to view.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Prevention Action Details (ID: ${_selectedPreventionAction!['id']})',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(
            'Title: ${_selectedPreventionAction!['prevention_title']}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text(
              'Created By: ${_selectedPreventionAction!['created_user_name']}'),
          Text('Created On: ${_selectedPreventionAction!['created_datetime']}'),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedPreventionAction = null;
                _currentView = PreventionActionView.list;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prevention Actions'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentView) {
      case PreventionActionView.list:
        return _buildListContent();
      case PreventionActionView.create:
        return _buildCreateContent();
      case PreventionActionView.update:
        return _buildUpdateContent();
      case PreventionActionView.detail: // Handle the new detail view
        return _buildDetailContent();
      default:
        return _buildListContent(); // Fallback to list view
    }
  }
}
