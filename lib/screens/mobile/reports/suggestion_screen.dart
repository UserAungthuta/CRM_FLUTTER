// suggestion_action_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

// Enum to manage the current view state
enum SuggestionActionView {
  list,
  create,
  update, // Added for update functionality
  detail, // Added for single suggestion action detail view
}

class ReportSuggestionActionScreen extends StatefulWidget {
  final String reportId;
  final int reportUId;
  const ReportSuggestionActionScreen(
      {super.key, required this.reportId, required this.reportUId});

  @override
  _ReportSuggestionActionScreenState createState() =>
      _ReportSuggestionActionScreenState();
}

class _ReportSuggestionActionScreenState
    extends State<ReportSuggestionActionScreen> {
  final _formKey = GlobalKey<FormState>();
  late Future<List<Map<String, String>>> _suggestionActionFuture;
  SuggestionActionView _currentView = SuggestionActionView.list;
  final TextEditingController _suggestionActionTitleController =
      TextEditingController();

  bool _isLoading = false; // For showing loading indicator during API calls
  Map<String, String>?
      _editingSuggestionAction; // Holds data of the suggestion action being edited
  Map<String, String>?
      _selectedSuggestionAction; // Holds data of the suggestion action being viewed in detail
  String? _reportStatus;

  @override
  void initState() {
    super.initState();
    _fetchSuggestionActionsData();
    _fetchReportStatus();
  }

  @override
  void dispose() {
    _suggestionActionTitleController.dispose();
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

  // Refreshes the suggestion action list data
  void _fetchSuggestionActionsData() {
    setState(() {
      _suggestionActionFuture =
          _fetchSuggestionActionsByReportId(widget.reportId);
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

  // New method to fetch suggestion actions by report_index
  Future<List<Map<String, String>>> _fetchSuggestionActionsByReportId(
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
          '${ApiConfig.baseUrl}/suggestion/read-by-report/$reportId'); // Adjusted API endpoint
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
          List<Map<String, String>> suggestionActions = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              suggestionActions.add({
                'id': item['id']?.toString() ?? '',
                'report_index': item['report_index']?.toString() ?? '',
                'suggestion_title':
                    item['suggestion_title'] as String? ?? 'N/A',
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
          return suggestionActions;
        } else {
          if (mounted) {
            _showSnackBar(context,
                'Failed to load suggestion actions. Invalid data format or success status.',
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

  Future<void> _createSuggestionAction() async {
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

    final Uri uri = Uri.parse('${ApiConfig.baseUrl}/suggestion/create');
    var request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['report_index'] = widget.reportId
      ..fields['suggestion_title'] = _suggestionActionTitleController.text;

    try {
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          if (mounted) {
            _showSnackBar(context, 'Suggestion created successfully!',
                color: Colors.green);
            _clearForm();
            setState(() {
              _currentView = SuggestionActionView.list;
              _fetchSuggestionActionsData(); // Refresh list
            });
          }
        } else {
          if (mounted) {
            _showSnackBar(context,
                responseData['message'] ?? 'Failed to create suggestion.',
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

  Future<void> _updateSuggestionAction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_editingSuggestionAction == null) {
      _showSnackBar(context, 'No suggestion selected for update.',
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
        '${ApiConfig.baseUrl}/suggestion/update/${_editingSuggestionAction!['id']}');
    var request = http.MultipartRequest(
        'POST', uri) // Changed to POST to match index.php routing
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['report_index'] = widget.reportId
      ..fields['suggestion_title'] = _suggestionActionTitleController.text;

    try {
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          if (mounted) {
            _showSnackBar(context, 'Suggestion updated successfully!',
                color: Colors.green);
            _clearForm();
            setState(() {
              _currentView = SuggestionActionView.list;
              _editingSuggestionAction = null;
              _fetchSuggestionActionsData(); // Refresh list
            });
          }
        } else {
          if (mounted) {
            _showSnackBar(context,
                responseData['message'] ?? 'Failed to update suggestion.',
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

  Future<void> _deleteSuggestionAction(String suggestionActionId) async {
    final bool confirmDelete = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content:
                const Text('Are you sure you want to delete this suggestion?'),
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
          '${ApiConfig.baseUrl}/suggestion/delete/$suggestionActionId');
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
            _showSnackBar(context, 'Suggestion deleted successfully!',
                color: Colors.green);
            _fetchSuggestionActionsData(); // Refresh list
          }
        } else {
          if (mounted) {
            _showSnackBar(context,
                responseData['message'] ?? 'Failed to delete suggestion.',
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
    _suggestionActionTitleController.clear();
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
                'Suggestion Actions for Report ID: ${widget.reportId}',
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
                _currentView = SuggestionActionView.create;
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Suggestion'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF336EE5),
              foregroundColor: Colors.white,
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Map<String, String>>>(
            future: _suggestionActionFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                    child: Text('No suggestions found for this report.'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final suggestionAction = snapshot.data![index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedSuggestionAction = suggestionAction;
                            _currentView = SuggestionActionView.detail;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Title: ${suggestionAction['suggestion_title']}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                  'Created By: ${suggestionAction['created_user_name']}'),
                              Text(
                                  'Created On: ${suggestionAction['created_datetime']}'),
                              const SizedBox(height: 10),
                              if (!isReportCompleted)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _editingSuggestionAction =
                                              suggestionAction;
                                          _suggestionActionTitleController
                                                  .text =
                                              suggestionAction[
                                                  'suggestion_title']!;
                                          _currentView =
                                              SuggestionActionView.update;
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
                                        _deleteSuggestionAction(
                                            suggestionAction['id']!);
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
              'Create Suggestion for Report ID: ${widget.reportId}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _suggestionActionTitleController,
              decoration: const InputDecoration(
                labelText: 'Suggestion Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a suggestion title';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _createSuggestionAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF336EE5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Submit Suggestion',
                        style: TextStyle(fontSize: 18)),
                  ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                _clearForm();
                setState(() {
                  _currentView = SuggestionActionView.list;
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
    if (_editingSuggestionAction == null) {
      return const Center(
          child: Text('Error: No suggestion selected for update.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Update Suggestion (ID: ${_editingSuggestionAction!['id']}) for Report ID: ${widget.reportId}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _suggestionActionTitleController,
              decoration: const InputDecoration(
                labelText: 'Suggestion Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a suggestion title';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _updateSuggestionAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.orange, // Use a different color for update
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Update Suggestion',
                        style: TextStyle(fontSize: 18)),
                  ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                _clearForm();
                setState(() {
                  _currentView = SuggestionActionView.list;
                  _editingSuggestionAction = null;
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
    if (_selectedSuggestionAction == null) {
      return const Center(child: Text('No suggestion selected to view.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Suggestion Details (ID: ${_selectedSuggestionAction!['id']})',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(
            'Title: ${_selectedSuggestionAction!['suggestion_title']}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text(
              'Created By: ${_selectedSuggestionAction!['created_user_name']}'),
          Text('Created On: ${_selectedSuggestionAction!['created_datetime']}'),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedSuggestionAction = null;
                _currentView = SuggestionActionView.list;
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
        title: const Text('Suggestions'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentView) {
      case SuggestionActionView.list:
        return _buildListContent();
      case SuggestionActionView.create:
        return _buildCreateContent();
      case SuggestionActionView.update:
        return _buildUpdateContent();
      case SuggestionActionView.detail: // Handle the new detail view
        return _buildDetailContent();
      default:
        return _buildListContent(); // Fallback to list view
    }
  }
}
