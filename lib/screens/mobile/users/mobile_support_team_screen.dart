// mobile_settings_users_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

// Enum to manage the current view state
enum SupportView {
  list,
  create,
  edit,
}

class MobileSupportTeamScreen extends StatefulWidget {
  const MobileSupportTeamScreen({super.key});

  @override
  _MobileSupportTeamScreenState createState() =>
      _MobileSupportTeamScreenState();
}

class _MobileSupportTeamScreenState extends State<MobileSupportTeamScreen> {
  late Future<List<Map<String, String>>> _supportFuture;
  SupportView _currentView = SupportView.list; // Default view is the list
  Map<String, String>?
      _editingSupport; // Holds data of the support being edited
  final List<String> _userRoles = [
    'superadmin',
    'admin',
    'supervisor',
    'engineer',
    'champion',
    'member',
    'localcustomer',
    'globalcustomer',
  ];

  // Controllers for the forms (add/edit)
  String? _customerId; // Holds the customer ID for editing
  String? _engineerId; // Holds the selected engineer ID
  String? _championId; // Holds the selected role
  String? _memberId; // Holds the selected member ID
  List<Map<String, String>> _customerIDs = []; // To store fetched customer IDs
  List<Map<String, String>> _engineerIDs = []; // To store fetched engineer IDs
  List<Map<String, String>> _championIDs = []; // To store fetched champion IDs
  List<Map<String, String>> _memberIDs = []; // To store fetched member IDs

  // Declare _countries list here (retained if still needed for other purposes, though not directly used for support team filtering anymore)
  final List<Map<String, String>> _countries = [];

  // Declare TextEditingControllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Declare selectedRole and selectedCountryId
  String? _selectedRole;
  String? _selectedCountryId;

  @override
  void initState() {
    super.initState();
    // Initialize _supportFuture with an empty list to prevent LateInitializationError
    _supportFuture = Future.value([]);
    _initializeData(); // Start fetching real data
  }

  Future<void> _initializeData() async {
    // 1. Fetch all users and categorize them for dropdowns and full name display
    await _fetchAndCategorizeUsers();
    // 2. Fetch the actual support team relationships
    setState(() {
      _supportFuture = _fetchSupportTeamData();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // This function now fetches all users and populates the ID lists based on roles
  Future<void> _fetchAndCategorizeUsers() async {
    try {
      final List<Map<String, String>> allUsers =
          await _fetchUsers(); // Re-use existing _fetchUsers
      setState(() {
        _customerIDs = allUsers
            .where((user) =>
                user['role'] == 'localcustomer' ||
                user['role'] == 'globalcustomer')
            .toList();
        _engineerIDs = allUsers
            .where((user) =>
                user['role'] == 'engineer' || user['role'] == 'supervisor')
            .toList();
        _championIDs = allUsers
            .where(
                (user) => user['role'] == 'champion' || user['role'] == 'admin')
            .toList();
        _memberIDs = allUsers
            .where(
                (user) => user['role'] == 'member' || user['role'] == 'admin')
            .toList();
      });
    } catch (e) {
      // Handle errors during user fetching for dropdowns, e.g., log it
      print('Error fetching and categorizing users: $e');
    }
  }

  // This function fetches the actual support team relationships
  Future<List<Map<String, String>>> _fetchSupportTeamData() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        return [];
      }

      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/support-team/readall'); // New endpoint assumed for fetching support teams
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Request timeout - Server not responding for support teams.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['data'] is List) {
          List<Map<String, String>> supportTeams = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              supportTeams.add({
                'id': item['id']?.toString() ?? '',
                'customer_id': item['customer_id']?.toString() ?? 'N/A',
                'engineer_id': item['engineer_id']?.toString() ?? 'N/A',
                'champion_id': item['champion_id']?.toString() ?? 'N/A',
                'member_id': item['member_id']?.toString() ?? 'N/A',
              });
            }
          }
          return supportTeams;
        } else {
          _showSnackBar(
              context, 'Failed to load support teams. Invalid data format.',
              color: Colors.red);
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to load support teams. Server error.',
            color: Colors.red);
        return [];
      }
    } on SocketException {
      _showSnackBar(context,
          'Network error while fetching support teams. Check your internet connection.',
          color: Colors.red);
      return [];
    } on TimeoutException {
      _showSnackBar(
          context, 'Support teams request timed out. Server not responding.',
          color: Colors.red);
      return [];
    } on FormatException {
      _showSnackBar(
          context, 'Invalid response format for support teams from server.',
          color: Colors.red);
      return [];
    } catch (e) {
      _showSnackBar(context,
          'An unexpected error occurred while fetching support teams: ${e.toString()}',
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

  Future<List<Map<String, String>>> _fetchUsers() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        return [];
      }

      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/users/readall'); // Fixed: Changed /user/ to /users/

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timeout - Server not responding.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['data'] is List) {
          List<Map<String, String>> users = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              users.add({
                'id': item['id']?.toString() ?? '',
                'username': item['username'] as String? ?? 'N/A',
                'fullname': item['fullname'] as String? ?? 'N/A',
                'email': item['email'] as String? ?? 'N/A',
                'phone': item['phone'] as String? ?? 'N/A',
                'address': item['address'] as String? ?? 'N/A',
                'role': item['role'] as String? ?? 'N/A',
                'country_id': item['country_id']?.toString() ?? 'N/A',
              });
            }
          }
          return users;
        } else {
          _showSnackBar(context, 'Failed to load users. Invalid data format.',
              color: Colors.red);
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to load users. Server error.',
            color: Colors.red);
        return [];
      }
    } on SocketException {
      _showSnackBar(context, 'Network error. Check your internet connection.',
          color: Colors.red);
      return [];
    } on TimeoutException {
      _showSnackBar(context, 'Request timed out. Server not responding.',
          color: Colors.red);
      return [];
    } on FormatException {
      _showSnackBar(context, 'Invalid response format from server.',
          color: Colors.red);
      return [];
    } catch (e) {
      _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
          color: Colors.red);
      return [];
    }
  }

  // Function to handle Create User API Call
  Future<void> _createSupportTeam() async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    if (_customerId == null ||
        _engineerId == null ||
        _championId == null ||
        _memberId == null) {
      // Validate country
      _showSnackBar(context, 'All fields are required.', color: Colors.orange);
      return;
    }

    final int? customerIdInt = int.tryParse(_customerId!);
    if (customerIdInt == null) {
      _showSnackBar(context, 'Invalid Customer ID selected.',
          color: Colors.red);
      return;
    }
    final int? engineerIdInt = int.tryParse(_engineerId!);
    if (engineerIdInt == null) {
      _showSnackBar(context, 'Invalid Engineer ID selected.',
          color: Colors.red);
      return;
    }
    final int? championIdInt = int.tryParse(_championId!);
    if (championIdInt == null) {
      _showSnackBar(context, 'Invalid Champion ID selected.',
          color: Colors.red);
      return;
    }
    final int? memberIdInt = int.tryParse(_memberId!);
    if (memberIdInt == null) {
      _showSnackBar(context, 'Invalid Member ID selected.', color: Colors.red);
      return;
    }

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/support-team/create'); // Fixed: Changed /user/ to /users/
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              // Include selected role
              'customer_id': customerIdInt, // Include selected customer ID
              'engineer_id': engineerIdInt, // Include selected engineer ID
              'champion_id': championIdInt, // Include selected champion ID
              'member_id': memberIdInt, // Include selected member ID
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        _showSnackBar(context, 'Support team created successfully!',
            color: Colors.green);
        setState(() {
          _customerId = null; // Clear selected customer
          _engineerId = null; // Clear selected engineer
          _championId = null; // Clear selected champion
          _memberId = null; // Clear selected member
          _currentView = SupportView.list;
        });
        _initializeData(); // Refresh list after creation
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to create support team. Server error.',
            color: Colors.red);
      }
    } on SocketException {
      _showSnackBar(context, 'Network error. Check your internet connection.',
          color: Colors.red);
    } on TimeoutException {
      _showSnackBar(context, 'Request timed out. Server not responding.',
          color: Colors.red);
    } on FormatException {
      _showSnackBar(context, 'Invalid response format from server.',
          color: Colors.red);
    } catch (e) {
      _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
          color: Colors.red);
    }
  }

  // Function to handle Update Support API Call
  Future<void> _updateSupport(String teamId) async {
    if (teamId.isEmpty) {
      _showSnackBar(context, 'Team ID is missing for update.',
          color: Colors.red);
      return;
    }

    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    // These fields will send their current values (which might be empty if they were
    // originally empty from the backend, or if the user cleared them).
    // Backend should handle further validation for empty strings if required.
    final int? customerIdInt = int.tryParse(_customerId!);
    if (customerIdInt == null) {
      _showSnackBar(context, 'Invalid Customer ID selected.',
          color: Colors.red);
      return;
    }
    final int? engineerIdInt = int.tryParse(_engineerId!);
    if (engineerIdInt == null) {
      _showSnackBar(context, 'Invalid Engineer ID selected.',
          color: Colors.red);
      return;
    }
    final int? championIdInt = int.tryParse(_championId!);
    if (championIdInt == null) {
      _showSnackBar(context, 'Invalid Champion ID selected.',
          color: Colors.red);
      return;
    }
    final int? memberIdInt = int.tryParse(_memberId!);
    if (memberIdInt == null) {
      _showSnackBar(context, 'Invalid Member ID selected.', color: Colors.red);
      return;
    }

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/support-team/update/$teamId'); // Fixed: Changed /user/ to /users/
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'customer_id': customerIdInt,
              'engineer_id': engineerIdInt,
              'champion_id': championIdInt,
              'member_id': memberIdInt,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Support team updated successfully!',
            color: Colors.green);

        setState(() {
          _customerId = null;
          _engineerId = null;
          _championId = null;
          _memberId = null;
          _currentView = SupportView.list;
          _editingSupport = null; // Clear editing state
        });
        _initializeData(); // Refresh list after update
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to update support team. Server error.',
            color: Colors.red);
      }
    } on SocketException {
      _showSnackBar(context, 'Network error. Check your internet connection.',
          color: Colors.red);
    } on TimeoutException {
      _showSnackBar(context, 'Request timed out. Server not responding.',
          color: Colors.red);
    } on FormatException {
      _showSnackBar(context, 'Invalid response format from server.',
          color: Colors.red);
    } catch (e) {
      _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
          color: Colors.red);
    }
  }

  // Function to handle Delete User API Call (now adjusted to delete a support team entry)
  Future<void> _deleteSupportTeam(String teamId) async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/support-team/delete/$teamId'); // Assuming a delete endpoint for support teams
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Support team deleted successfully!',
            color: Colors.green);
        _initializeData(); // Refresh the list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to delete support team. Server error.',
            color: Colors.red);
      }
    } on SocketException {
      _showSnackBar(context, 'Network error. Check your internet connection.',
          color: Colors.red);
    } on TimeoutException {
      _showSnackBar(context, 'Request timed out. Server not responding.',
          color: Colors.red);
    } on FormatException {
      _showSnackBar(context, 'Invalid response format from server.',
          color: Colors.red);
    } catch (e) {
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
                'Support Team',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _editingSupport = null; // Clear editing state
                    _customerId = null; // Clear selected customer for new user
                    _engineerId = null; // Clear selected engineer for new user
                    _championId = null; // Clear selected champion for new user
                    _memberId = null; // Clear selected member for new user
                    _currentView = SupportView.create;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add New Support Team'),
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
            future: _supportFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No support teams available.'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final supportTeam = snapshot.data![index];
                    // Find full names using the pre-populated ID lists
                    final customer = _customerIDs.firstWhere(
                      (user) => user['id'] == supportTeam['customer_id'],
                      orElse: () => {'fullname': 'N/A'},
                    );
                    final engineer = _engineerIDs.firstWhere(
                      (user) => user['id'] == supportTeam['engineer_id'],
                      orElse: () => {'fullname': 'N/A'},
                    );
                    final champion = _championIDs.firstWhere(
                      (user) => user['id'] == supportTeam['champion_id'],
                      orElse: () => {'fullname': 'N/A'},
                    );
                    final member = _memberIDs.firstWhere(
                      (user) => user['id'] == supportTeam['member_id'],
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
                              'Customer: ${customer['fullname']}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text('Engineer: ${engineer['fullname']}'),
                            Text('Champion: ${champion['fullname']}'),
                            Text('Member: ${member['fullname']}'),
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
                                        _editingSupport = supportTeam;
                                        _currentView = SupportView.edit;
                                        _customerId =
                                            supportTeam['customer_id'];
                                        _engineerId =
                                            supportTeam['engineer_id'];
                                        _championId =
                                            supportTeam['champion_id'];
                                        _memberId = supportTeam['member_id'];
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () {
                                      _deleteSupportTeam(supportTeam[
                                          'id']!); // Use _deleteSupportTeam
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

  @override
  Widget _buildCreateContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Create New Support Team',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _customerId,
            decoration: const InputDecoration(
              labelText: 'Customer',
              border: OutlineInputBorder(),
            ),
            items: _customerIDs.map((Map<String, String> user) {
              return DropdownMenuItem<String>(
                value: user['id'],
                child: Text(user['fullname'] ?? user['username'] ?? 'N/A'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _customerId = newValue;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a customer';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _engineerId,
            decoration: const InputDecoration(
              labelText: 'Engineer',
              border: OutlineInputBorder(),
            ),
            items: _engineerIDs.map((Map<String, String> user) {
              return DropdownMenuItem<String>(
                value: user['id'],
                child: Text(user['fullname'] ?? user['username'] ?? 'N/A'),
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
          DropdownButtonFormField<String>(
            initialValue: _championId,
            decoration: const InputDecoration(
              labelText: 'Champion',
              border: OutlineInputBorder(),
            ),
            items: _championIDs.map((Map<String, String> user) {
              return DropdownMenuItem<String>(
                value: user['id'],
                child: Text(user['fullname'] ?? user['username'] ?? 'N/A'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _championId = newValue;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a champion';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _memberId,
            decoration: const InputDecoration(
              labelText: 'Member',
              border: OutlineInputBorder(),
            ),
            items: _memberIDs.map((Map<String, String> user) {
              return DropdownMenuItem<String>(
                value: user['id'],
                child: Text(user['fullname'] ?? user['username'] ?? 'N/A'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _memberId = newValue;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a member';
              }
              return null;
            },
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _createSupportTeam,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Create Support Team',
                style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _customerId = null;
                _engineerId = null;
                _championId = null;
                _memberId = null;
                _currentView = SupportView.list;
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
  Widget _buildEditContent(Map<String, String> supportTeam) {
    // Populate dropdowns with existing data when the form is opened
    // Ensure you set _customerId, _engineerId, _championId, _memberId from the supportTeam object
    // when _editingSupport is set and _currentView is changed to SupportView.edit.
    // This part should be handled in the setState block where _editingSupport is assigned.

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit Support Team: ${supportTeam['id']}',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _customerId,
            decoration: const InputDecoration(
              labelText: 'Customer',
              border: OutlineInputBorder(),
            ),
            items: _customerIDs.map((Map<String, String> user) {
              return DropdownMenuItem<String>(
                value: user['id'],
                child: Text(user['fullname'] ?? user['username'] ?? 'N/A'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _customerId = newValue;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _engineerId,
            decoration: const InputDecoration(
              labelText: 'Engineer',
              border: OutlineInputBorder(),
            ),
            items: _engineerIDs.map((Map<String, String> user) {
              return DropdownMenuItem<String>(
                value: user['id'],
                child: Text(user['fullname'] ?? user['username'] ?? 'N/A'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _engineerId = newValue;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _championId,
            decoration: const InputDecoration(
              labelText: 'Champion',
              border: OutlineInputBorder(),
            ),
            items: _championIDs.map((Map<String, String> user) {
              return DropdownMenuItem<String>(
                value: user['id'],
                child: Text(user['fullname'] ?? user['username'] ?? 'N/A'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _championId = newValue;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _memberId,
            decoration: const InputDecoration(
              labelText: 'Member',
              border: OutlineInputBorder(),
            ),
            items: _memberIDs.map((Map<String, String> user) {
              return DropdownMenuItem<String>(
                value: user['id'],
                child: Text(user['fullname'] ?? user['username'] ?? 'N/A'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _memberId = newValue;
              });
            },
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => _updateSupport(supportTeam['id']!),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Update Support Team',
                style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _customerId = null;
                _engineerId = null;
                _championId = null;
                _memberId = null;
                _currentView = SupportView.list;
                _editingSupport = null;
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
        title: const Text('Support Team Management'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentView) {
      case SupportView.list:
        return _buildListContent();
      case SupportView.create:
        return _buildCreateContent();
      case SupportView.edit:
        return _buildEditContent(_editingSupport!);
      default:
        return _buildListContent(); // Fallback to list view
    }
  }
}
