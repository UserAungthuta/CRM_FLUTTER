// lib/screens/admin/web_support_team_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
import '../../../models/user_model.dart';
import '../../../widgets/sidebar_widget.dart'; // Import the SidebarWidget

// Enum to manage the current view state
enum SupportView {
  list,
  create,
  edit,
}

class WebSupportTeamScreen extends StatefulWidget {
  const WebSupportTeamScreen({super.key});

  @override
  _WebSupportTeamScreenState createState() => _WebSupportTeamScreenState();
}

class _WebSupportTeamScreenState extends State<WebSupportTeamScreen> {
  // Constants for layout
  static const double _kSidebarWidth = 256.0; // Width of the persistent sidebar
  static const double _kContentHorizontalPadding =
      20.0; // Padding around main content sections
  static const double _kWrapSpacing = 16.0; // Spacing between cards in Wrap
  static const double _kAppBarHeight = kToolbarHeight;
  User? _currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSidebarOpen = true;

  late Future<List<Map<String, String>>> _supportFuture;
  SupportView _currentView = SupportView.list; // Default view is the list
  Map<String, String>?
      _editingSupport; // Holds data of the support being edited

  // Controllers for the forms (add/edit)
  String? _customerId; // Holds the customer ID for editing
  String? _engineerId; // Holds the selected engineer ID
  String? _championId; // Holds the selected role
  String? _memberId; // Holds the selected member ID
  List<Map<String, String>> _customerIDs = []; // To store fetched customer IDs
  List<Map<String, String>> _engineerIDs = []; // To store fetched engineer IDs
  List<Map<String, String>> _championIDs = []; // To store fetched champion IDs
  List<Map<String, String>> _memberIDs = []; // To store fetched member IDs

  @override
  void initState() {
    super.initState();
    _supportFuture = Future.value([]); // Initialize with an empty future
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchAndCategorizeUsers();
    setState(() {
      _supportFuture = _fetchSupportTeamData();
    });
  }

  // No need to dispose of TextEditingControllers as they are not used here
  Future<void> _logout() async {
    await SharedPrefs.clearAll(); // Clear user data and token
    // Navigate back to the login screen, removing all previous routes
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
    _showSnackBar(context, 'Logged out successfully!', color: Colors.green);
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

      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/support-team/readall');
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

      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/users/readall');

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
      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/support-team/create');
      final response = await http
          .post(
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

      if (response.statusCode == 201) {
        _showSnackBar(context, 'Support team created successfully!',
            color: Colors.green);
        setState(() {
          _customerId = null;
          _engineerId = null;
          _championId = null;
          _memberId = null;
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
      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/support-team/update/$teamId');
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
      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/support-team/delete/$teamId');
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
          padding: const EdgeInsets.symmetric(
              horizontal: _kContentHorizontalPadding, vertical: 16.0),
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
                    _customerId = null;
                    _engineerId = null;
                    _championId = null;
                    _memberId = null;
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
        // Table Header
        Container(
          margin: const EdgeInsets.symmetric(
              horizontal: _kContentHorizontalPadding),
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          decoration: const BoxDecoration(
            color: Color(0xFF336EE5), // Header background color
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 2,
                child: Text('Customer',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Expanded(
                flex: 2,
                child: Text('Engineer',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Expanded(
                flex: 2,
                child: Text('Champion',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Expanded(
                flex: 2,
                child: Text('Member',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Expanded(
                flex: 1,
                child: Text('Actions',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
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

                    // Determine row color
                    final Color rowColor =
                        index % 2 == 0 ? Colors.white : Colors.grey.shade100;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: _kContentHorizontalPadding),
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 8.0),
                      decoration: BoxDecoration(
                        color: rowColor,
                        border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300)),
                        // Apply rounded corners to the last row
                        borderRadius: index == snapshot.data!.length - 1
                            ? const BorderRadius.vertical(
                                bottom: Radius.circular(0))
                            : BorderRadius.zero,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(customer['fullname'] ?? 'N/A'),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(engineer['fullname'] ?? 'N/A'),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(champion['fullname'] ?? 'N/A'),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(member['fullname'] ?? 'N/A'),
                          ),
                          Expanded(
                            flex: 1,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _editingSupport = supportTeam;
                                      _currentView = SupportView.edit;
                                      _customerId = supportTeam['customer_id'];
                                      _engineerId = supportTeam['engineer_id'];
                                      _championId = supportTeam['champion_id'];
                                      _memberId = supportTeam['member_id'];
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red, size: 20),
                                  onPressed: () {
                                    _deleteSupportTeam(supportTeam['id']!);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
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
      padding: const EdgeInsets.symmetric(
          horizontal: _kContentHorizontalPadding, vertical: 16.0),
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

  Widget _buildEditContent(Map<String, String> supportTeam) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: _kContentHorizontalPadding, vertical: 16.0),
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

  Widget _buildCustomHeader(bool isLargeScreen) {
    return Container(
      height: _kAppBarHeight, // Standard AppBar height
      decoration: const BoxDecoration(
        color: Color(0xFF336EE5), // Equivalent to bg-blue-800
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isSidebarOpen
                      ? CupertinoIcons.arrow_left_to_line
                      : CupertinoIcons.arrow_right_to_line,
                  color: Colors.white,
                  size: 18.0,
                ),
                onPressed: () {
                  if (!mounted) return; // Check mounted before setState
                  setState(() {
                    _isSidebarOpen = !_isSidebarOpen;
                  });
                },
              ),
              const SizedBox(width: 8),
              Image.asset(
                'images/logo.png', // Path to your logo image
                height: 40,
                fit: BoxFit.contain,
              ),
            ],
          ),
          // Navigation Links for large screens in Header
          Row(
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/web_superadmin-dashboard');
                },
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16)),
                child: const Text('Dashboard'),
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 40),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'users',
                    child: Text('Users'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'support_team',
                    child: Text('Support Team'),
                  ),
                ],
                onSelected: (String value) {
                  if (value == 'users') {
                    Navigator.of(context).pushNamed('/users');
                  } else if (value == 'support_team') {
                    Navigator.of(context).pushNamed('/support_team');
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        'Users',
                        style: TextStyle(color: Colors.white),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/reports');
                },
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16)),
                child: const Text('Reports'),
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 40),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'products',
                    child: Text('Products'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'assigned_products',
                    child: Text('Assigned Products'),
                  ),
                ],
                onSelected: (String value) {
                  if (value == 'products') {
                    Navigator.of(context).pushNamed('/products/products');
                  } else if (value == 'assigned_products') {
                    Navigator.of(context)
                        .pushNamed('/products/assigned_products');
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        'Products',
                        style: TextStyle(color: Colors.white),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),
              ),
              // Settings Dropdown for large screens
              PopupMenuButton<String>(
                offset: const Offset(0, 40),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'country_settings',
                    child: Text('Country'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'report_warning_settings',
                    child: Text('Report Warning'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'terms_settings',
                    child: Text('Terms'),
                  ),
                ],
                onSelected: (String value) {
                  if (value == 'country_settings') {
                    Navigator.of(context).pushNamed('/web_settings/country');
                  } else if (value == 'report_warning_settings') {
                    Navigator.of(context)
                        .pushNamed('/web_settings/report_warning');
                  } else if (value == 'terms_settings') {
                    Navigator.of(context).pushNamed('/web_settings/terms');
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(color: Colors.white),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),
              ),
              // User Profile/Dropdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'profile',
                      child: Text('Profile'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child:
                          Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  onSelected: (String value) {
                    if (value == 'logout') {
                      _logout();
                    } else if (value == 'profile') {
                      Navigator.of(context).pushNamed('/profile');
                    } else if (value == 'settings') {
                      Navigator.of(context).pushNamed('/web_settings');
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle,
                          color: Colors.white, size: 32),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          _currentUser?.fullname ?? 'Admin',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Determine if it's a large screen (desktop/tablet) or small (mobile)
    final bool isLargeScreen = screenWidth > 768; // md:breakpoint in Tailwind

    return Scaffold(
      key: _scaffoldKey, // Assign the Scaffold key for drawer control
      // Conditionally show AppBar only for small screens
      appBar: isLargeScreen
          ? null // No AppBar on large screens
          : AppBar(
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF336EE5),
                ),
              ),
              title: Image.asset(
                'images/logo.png',
                height: 40,
                fit: BoxFit.contain,
              ),
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ),
      // Mobile Navigation Drawer (only for small screens)
      drawer: isLargeScreen
          ? null
          : Drawer(
              child: Container(
                color: const Color(0xFF1E293B),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    DrawerHeader(
                      decoration: const BoxDecoration(
                        color: Color(0xFF1D4ED8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.account_circle,
                              color: Colors.white, size: 60),
                          const SizedBox(height: 10),
                          Text(
                            _currentUser?.fullname ?? 'Admin',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18),
                          ),
                          Text(
                            _currentUser?.email ?? 'admin@example.com',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    _buildDrawerItem(Icons.dashboard, 'Dashboard', () {
                      Navigator.pop(context);
                      Navigator.of(context)
                          .pushNamed('/web_superadmin-dashboard');
                    }),
                    ExpansionTile(
                      leading: const Icon(Icons.people, color: Colors.white),
                      title: const Text('Users',
                          style: TextStyle(color: Colors.white)),
                      collapsedIconColor: Colors.white,
                      iconColor: Colors.white,
                      children: <Widget>[
                        _buildDrawerItem(Icons.people, 'Users', () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/users');
                        }, isSubItem: true),
                        _buildDrawerItem(Icons.support_agent, 'Support Team',
                            () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/support_team');
                        }, isSubItem: true),
                      ],
                    ),
                    ExpansionTile(
                      leading: const Icon(Icons.category, color: Colors.white),
                      title: const Text('Products',
                          style: TextStyle(color: Colors.white)),
                      collapsedIconColor: Colors.white,
                      iconColor: Colors.white,
                      children: <Widget>[
                        _buildDrawerItem(Icons.category, 'Products', () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/products/products');
                        }, isSubItem: true),
                        _buildDrawerItem(
                            Icons.shopping_bag, 'Assigned Products', () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/products/assigned');
                        }, isSubItem: true),
                      ],
                    ),
                    _buildDrawerItem(Icons.bar_chart, 'Reports', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/reports');
                    }),
                    _buildDrawerItem(Icons.build, 'Maintenance', () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/maintenance');
                    }),
                    ExpansionTile(
                      leading: const Icon(Icons.settings, color: Colors.white),
                      title: const Text('Settings',
                          style: TextStyle(color: Colors.white)),
                      collapsedIconColor: Colors.white,
                      iconColor: Colors.white,
                      children: <Widget>[
                        _buildDrawerItem(Icons.flag, 'Country', () {
                          Navigator.pop(context);
                          Navigator.of(context)
                              .pushNamed('/web_settings/country');
                        }, isSubItem: true),
                        _buildDrawerItem(Icons.warning, 'Report Warning', () {
                          Navigator.pop(context);
                          Navigator.of(context)
                              .pushNamed('/web_settings/report_warning');
                        }, isSubItem: true),
                        _buildDrawerItem(Icons.description, 'Terms', () {
                          Navigator.pop(context);
                          Navigator.of(context)
                              .pushNamed('/web_settings/terms');
                        }, isSubItem: true),
                      ],
                    ),
                    const Divider(color: Colors.white54),
                    _buildDrawerItem(Icons.logout, 'Logout', () {
                      Navigator.pop(context);
                      _logout();
                    }, textColor: Colors.red),
                  ],
                ),
              ),
            ),
      body: isLargeScreen
          ? Row(
              children: [
                // Persistent Full-Height Sidebar for large screens
                WebSuperAdminSidebar(
                  isOpen: _isSidebarOpen,
                  width: _kSidebarWidth,
                  onDashboardTap: () {
                    Navigator.of(context)
                        .pushNamed('/web_superadmin-dashboard');
                  },
                  onUsersTap: () {
                    Navigator.of(context).pushNamed('/users');
                  },
                  onSupportTap: () {
                    Navigator.of(context).pushNamed('/support_team');
                  },
                  onProductsManageTap: () {
                    Navigator.of(context).pushNamed('/products/products');
                  },
                  onAssignedProductsTap: () {
                    Navigator.of(context)
                        .pushNamed('/products/assigned_products');
                  },
                  onReportsTap: () {
                    Navigator.of(context).pushNamed('/reports');
                  },
                  onMaintenanceTap: () {
                    Navigator.of(context).pushNamed('/maintenance');
                  },
                  onCountrySettingsTap: () {
                    Navigator.of(context).pushNamed('/web_settings/country');
                  },
                  onReportWarningSettingsTap: () {
                    Navigator.of(context)
                        .pushNamed('/web_settings/report_warning');
                  },
                  onTermsSettingsTap: () {
                    Navigator.of(context).pushNamed('/web_settings/terms');
                  },
                ),
                // Add a SizedBox for spacing only if the sidebar is open
                if (_isSidebarOpen) const SizedBox(width: 0.0),
                // Main Content Area with Custom Header
                Expanded(
                  child: Column(
                    children: [
                      // Custom Header
                      _buildCustomHeader(isLargeScreen),
                      // Main Scrollable Content
                      Expanded(
                        child:
                            _buildBodyContent(), // Delegates to the content builder
                      ),
                    ],
                  ),
                ),
              ],
            )
          : // Small Screen Layout (existing Scaffold with AppBar and Drawer)
          _buildBodyContent(), // Delegates to the content builder
    );
  }

  Widget _buildBodyContent() {
    switch (_currentView) {
      case SupportView.list:
        return _buildListContent();
      case SupportView.create:
        return _buildCreateContent();
      case SupportView.edit:
        // Ensure _editingSupport is not null when trying to edit
        if (_editingSupport != null) {
          return _buildEditContent(_editingSupport!);
        }
        return _buildListContent(); // Fallback if _editingSupport is null unexpectedly
      default:
        return _buildListContent(); // Fallback to list view
    }
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap,
      {Color textColor = Colors.white, bool isSubItem = false}) {
    return ListTile(
      contentPadding:
          EdgeInsets.only(left: isSubItem ? 32.0 : 8.0), // Indent sub-items
      minLeadingWidth: 0, // Set minimum leading width to 0
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      onTap: onTap,
      tileColor: const Color(0xFF1E293B), // Dark background for drawer items
      selectedTileColor: const Color(0xFF2563EB), // blue-600
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
