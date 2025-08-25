// mobile_assign_engineer_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

// Enum to manage the current view state
enum AssignmentView {
  list,
  create,
  edit,
}

class MobileAssignEngineerScreen extends StatefulWidget {
  const MobileAssignEngineerScreen({super.key});

  @override
  _MobileAssignEngineerScreenState createState() =>
      _MobileAssignEngineerScreenState();
}

class _MobileAssignEngineerScreenState
    extends State<MobileAssignEngineerScreen> {
  late Future<List<Map<String, String>>> _assignFuture;
  AssignmentView _currentView = AssignmentView.list; // Default view is the list
  Map<String, String>?
      _editingAssignment; // Holds data of the assignment being edited

  // Controllers for the forms (add/edit)
  String? _engineerId; // Holds the selected engineer ID
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  List<Map<String, String>> _engineerIDs = []; // To store fetched engineer IDs

  @override
  void initState() {
    super.initState();
    _assignFuture = Future.value([]);
    _initializeData(); // Start fetching real data
  }

  Future<void> _initializeData() async {
    await _fetchEngineers();
    setState(() {
      _assignFuture = _fetchAssignmentsData();
    });
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  // This function fetches users with the 'engineer' role
  Future<void> _fetchEngineers() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(context, 'Authentication token missing.',
            color: Colors.red);
        return;
      }

      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/users/readall');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['data'] is List) {
          final List<Map<String, String>> allUsers = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              allUsers.add({
                'id': item['id']?.toString() ?? '',
                'fullname': item['fullname'] as String? ?? 'N/A',
                'role': item['role'] as String? ?? 'N/A',
              });
            }
          }
          setState(() {
            _engineerIDs =
                allUsers.where((user) => user['role'] == 'engineer').toList();
          });
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context, errorData['message'] ?? 'Failed to load users.',
            color: Colors.red);
      }
    } on Exception catch (e) {
      _showSnackBar(context, 'An error occurred while fetching users: $e',
          color: Colors.red);
    }
  }

  // This function fetches the actual engineer assignment records
  Future<List<Map<String, String>>> _fetchAssignmentsData() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(context, 'Authentication token missing.',
            color: Colors.red);
        return [];
      }

      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/assign-engineer/readall');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['data'] is List) {
          List<Map<String, String>> assignments = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              assignments.add({
                'id': item['id']?.toString() ?? '',
                'engineer_id': item['engineer_id']?.toString() ?? 'N/A',
                'start_date': item['start_date']?.toString() ?? 'N/A',
                'end_date': item['end_date']?.toString() ?? 'N/A',
              });
            }
          }
          return assignments;
        } else {
          _showSnackBar(
              context, 'Failed to load assignments. Invalid data format.',
              color: Colors.red);
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to load assignments. Server error.',
            color: Colors.red);
        return [];
      }
    } on SocketException {
      _showSnackBar(context, 'Network error. Check your internet connection.',
          color: Colors.red);
      return [];
    } on TimeoutException {
      _showSnackBar(
          context, 'Assignments request timed out. Server not responding.',
          color: Colors.red);
      return [];
    } on FormatException {
      _showSnackBar(
          context, 'Invalid response format for assignments from server.',
          color: Colors.red);
      return [];
    } catch (e) {
      _showSnackBar(context,
          'An unexpected error occurred while fetching assignments: ${e.toString()}',
          color: Colors.red);
      return [];
    }
  }

  // Helper method to show a SnackBar message
  void _showSnackBar(BuildContext context, String message,
      {Color color = Colors.black}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _createAssignment() async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(context, 'Authentication token missing.',
          color: Colors.red);
      return;
    }

    if (_engineerId == null ||
        _startDateController.text.isEmpty ||
        _endDateController.text.isEmpty) {
      _showSnackBar(context, 'All fields are required.', color: Colors.orange);
      return;
    }

    final int? engineerIdInt = int.tryParse(_engineerId!);
    if (engineerIdInt == null) {
      _showSnackBar(context, 'Invalid Engineer ID selected.',
          color: Colors.red);
      return;
    }

    // New logic to check for existing assignments
    final assignedEngineers = await _fetchAssignmentsData();
    final isAlreadyAssigned = assignedEngineers.any((assignment) {
      final assignedEngineerId = assignment['engineer_id'];
      if (assignedEngineerId == _engineerId) {
        final assignedStartDate =
            DateTime.tryParse(assignment['start_date'] ?? '');
        final assignedEndDate = DateTime.tryParse(assignment['end_date'] ?? '');
        final newStartDate = DateTime.tryParse(_startDateController.text);
        final newEndDate = DateTime.tryParse(_endDateController.text);

        if (assignedStartDate != null &&
            assignedEndDate != null &&
            newStartDate != null &&
            newEndDate != null) {
          // Check for date overlap
          return newStartDate.isBefore(assignedEndDate) &&
              newEndDate.isAfter(assignedStartDate);
        }
      }
      return false;
    });

    if (isAlreadyAssigned) {
      _showSnackBar(context,
          'This engineer is already assigned for the selected date range.',
          color: Colors.red);
      return;
    }

    try {
      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/assign-engineer/create');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'engineer_id': engineerIdInt,
              'start_date': _startDateController.text,
              'end_date': _endDateController.text,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        _showSnackBar(context, 'Engineer assigned successfully!',
            color: Colors.green);
        setState(() {
          _engineerId = null;
          _startDateController.clear();
          _endDateController.clear();
          _currentView = AssignmentView.list;
        });
        _initializeData();
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context, errorData['message'] ?? 'Failed to assign engineer.',
            color: Colors.red);
      }
    } on Exception catch (e) {
      _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
          color: Colors.red);
    }
  }

  Future<void> _updateAssignment(String assignmentId) async {
    if (assignmentId.isEmpty) {
      _showSnackBar(context, 'Assignment ID is missing for update.',
          color: Colors.red);
      return;
    }

    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(context, 'Authentication token missing.',
          color: Colors.red);
      return;
    }

    final int? engineerIdInt = int.tryParse(_engineerId!);
    if (engineerIdInt == null) {
      _showSnackBar(context, 'Invalid Engineer ID selected.',
          color: Colors.red);
      return;
    }

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/assign-engineer/update/$assignmentId');
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'engineer_id': engineerIdInt,
              'start_date': _startDateController.text,
              'end_date': _endDateController.text,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Engineer assignment updated successfully!',
            color: Colors.green);

        setState(() {
          _engineerId = null;
          _startDateController.clear();
          _endDateController.clear();
          _currentView = AssignmentView.list;
          _editingAssignment = null; // Clear editing state
        });
        _initializeData(); // Refresh list after update
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context, errorData['message'] ?? 'Failed to update assignment.',
            color: Colors.red);
      }
    } on Exception catch (e) {
      _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
          color: Colors.red);
    }
  }

  Future<void> _deleteAssignment(String assignmentId) async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(context, 'Authentication token missing.',
          color: Colors.red);
      return;
    }

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/assign-engineer/delete/$assignmentId');
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Engineer assignment deleted successfully!',
            color: Colors.green);
        _initializeData(); // Refresh the list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context, errorData['message'] ?? 'Failed to delete assignment.',
            color: Colors.red);
      }
    } on Exception catch (e) {
      _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
          color: Colors.red);
    }
  }

  Widget _buildListContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Engineer Assignments',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _editingAssignment = null;
                    _engineerId = null;
                    _startDateController.clear();
                    _endDateController.clear();
                    _currentView = AssignmentView.create;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add New Assignment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, String>>>(
            future: _assignFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                    child: Text('No engineer assignments available.'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final assignment = snapshot.data![index];
                    final engineer = _engineerIDs.firstWhere(
                      (user) => user['id'] == assignment['engineer_id'],
                      orElse: () => {'fullname': 'N/A'},
                    );
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Engineer: ${engineer['fullname']}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text('Start Date: ${assignment['start_date']}'),
                            Text('End Date: ${assignment['end_date']}'),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () {
                                      setState(() {
                                        _editingAssignment = assignment;
                                        _currentView = AssignmentView.edit;
                                        _engineerId = assignment['engineer_id'];
                                        _startDateController.text =
                                            assignment['start_date'] ?? '';
                                        _endDateController.text =
                                            assignment['end_date'] ?? '';
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () {
                                      _deleteAssignment(assignment['id']!);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
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

  Widget _buildDateField({
    required TextEditingController controller,
    required String labelText,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true, // Prevents manual text input
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () async {
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (pickedDate != null) {
          controller.text =
              pickedDate.toString().split(' ')[0]; // Format to YYYY-MM-DD
        }
      },
    );
  }

  Widget _buildCreateContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Create New Engineer Assignment',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _engineerId,
            decoration: const InputDecoration(
              labelText: 'Engineer',
              border: OutlineInputBorder(),
            ),
            items: _engineerIDs.map((Map<String, String> user) {
              return DropdownMenuItem<String>(
                value: user['id'],
                child: Text(user['fullname'] ?? 'N/A'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _engineerId = newValue;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select an engineer';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildDateField(
              controller: _startDateController, labelText: 'Start Date'),
          const SizedBox(height: 16),
          _buildDateField(
              controller: _endDateController, labelText: 'End Date'),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _createAssignment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child:
                const Text('Create Assignment', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _engineerId = null;
                _startDateController.clear();
                _endDateController.clear();
                _currentView = AssignmentView.list;
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
    );
  }

  Widget _buildEditContent(Map<String, String> assignment) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit Assignment: ${assignment['id']}',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _engineerId,
            decoration: const InputDecoration(
              labelText: 'Engineer',
              border: OutlineInputBorder(),
            ),
            items: _engineerIDs.map((Map<String, String> user) {
              return DropdownMenuItem<String>(
                value: user['id'],
                child: Text(user['fullname'] ?? 'N/A'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _engineerId = newValue;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildDateField(
              controller: _startDateController, labelText: 'Start Date'),
          const SizedBox(height: 16),
          _buildDateField(
              controller: _endDateController, labelText: 'End Date'),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => _updateAssignment(assignment['id']!),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child:
                const Text('Update Assignment', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _engineerId = null;
                _startDateController.clear();
                _endDateController.clear();
                _currentView = AssignmentView.list;
                _editingAssignment = null;
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Engineer Assignment Management'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentView) {
      case AssignmentView.list:
        return _buildListContent();
      case AssignmentView.create:
        return _buildCreateContent();
      case AssignmentView.edit:
        if (_editingAssignment != null) {
          return _buildEditContent(_editingAssignment!);
        }
        return const Center(
            child: Text('Error: No assignment selected for editing.'));
      default:
        return _buildListContent(); // Fallback to list view
    }
  }
}
