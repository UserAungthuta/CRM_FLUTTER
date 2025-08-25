// mobile_settings_users_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

// Enum to manage the current view state
enum UserView {
  list,
  create,
  edit,
}

class MobileUserScreen extends StatefulWidget {
  const MobileUserScreen({super.key});

  @override
  _MobileUserScreenState createState() => _MobileUserScreenState();
}

class _MobileUserScreenState extends State<MobileUserScreen> {
  late Future<List<Map<String, String>>> _usersFuture;
  UserView _currentView = UserView.list; // Default view is the list
  Map<String, String>? _editingUser; // Holds data of the user being edited
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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _selectedRole;
  String? _selectedCountryId; // Holds the selected country ID
  List<Map<String, String>> _countries = []; // To store fetched countries
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsersData();
    _fetchCountriesData(); // Fetch countries when the screen initializes
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

  void _fetchUsersData() {
    setState(() {
      _usersFuture = _fetchUsers();
    });
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

  Future<void> _fetchCountriesData() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(context,
            'Authentication token missing for countries. Please log in again.',
            color: Colors.red);
        return;
      }

      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/country/readall');

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
              'Country fetch timeout - Server not responding.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['data'] is List) {
          setState(() {
            _countries = [];
            for (var item in responseData['data']) {
              if (item is Map<String, dynamic>) {
                _countries.add({
                  'id': item['id']?.toString() ?? '',
                  'name': item['country_name'] as String? ?? 'Unknown',
                });
              }
            }
          });
        } else {
          _showSnackBar(
              context, 'Failed to load countries. Invalid data format.',
              color: Colors.red);
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to load countries. Server error.',
            color: Colors.red);
      }
    } on SocketException {
      _showSnackBar(context,
          'Network error while fetching countries. Check your internet connection.',
          color: Colors.red);
    } on TimeoutException {
      _showSnackBar(
          context, 'Request for countries timed out. Server not responding.',
          color: Colors.red);
    } on FormatException {
      _showSnackBar(
          context, 'Invalid response format from server for countries.',
          color: Colors.red);
    } catch (e) {
      _showSnackBar(context,
          'An unexpected error occurred while fetching countries: ${e.toString()}',
          color: Colors.red);
    }
  }

  // Function to handle Create User API Call
  Future<void> _createUser() async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    final String username = _usernameController.text.trim();
    final String fullname = _fullnameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String phone = _phoneController.text.trim();
    final String address = _addressController.text.trim();

    if (username.isEmpty ||
        fullname.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        phone.isEmpty ||
        address.isEmpty ||
        _selectedRole == null || // Validate role
        _selectedCountryId == null) {
      // Validate country
      _showSnackBar(context, 'All fields are required.', color: Colors.orange);
      return;
    }

    final int? countryIdInt = int.tryParse(_selectedCountryId!);
    if (countryIdInt == null) {
      _showSnackBar(context, 'Invalid Country ID selected.', color: Colors.red);
      return;
    }

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/users/create'); // Fixed: Changed /user/ to /users/
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'username': username,
              'fullname': fullname,
              'email': email,
              'password': password,
              'phone': phone,
              'address': address,
              'role': _selectedRole, // Include selected role
              'country_id': countryIdInt, // Include selected country ID
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        _showSnackBar(context, 'User created successfully!',
            color: Colors.green);
        _usernameController.clear();
        _fullnameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _phoneController.clear();
        _addressController.clear();
        setState(() {
          _selectedRole = null; // Clear selected role
          _selectedCountryId = null; // Clear selected country
          _currentView = UserView.list;
        });
        _fetchUsersData(); // Refresh list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to create user. Server error.',
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

  // Function to handle Update User API Call
  Future<void> _updateUser(String userId) async {
    if (userId.isEmpty) {
      _showSnackBar(context, 'User ID is missing for update.',
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
    final String username = _usernameController.text.trim();
    final String fullname = _fullnameController.text.trim();
    final String email = _emailController.text.trim();
    final String phone = _phoneController.text.trim();
    final String address = _addressController.text.trim();

    // Removed the null check for _selectedRole and _selectedCountryId to allow
    // sending existing (possibly null/empty) data for update.
    // Backend should handle validation of these fields.

    // Handle country_id for the request body: send null if _selectedCountryId is null
    final int? countryIdInt =
        _selectedCountryId != null ? int.tryParse(_selectedCountryId!) : null;

    // If parsing fails for a non-null _selectedCountryId, it's still an error.
    if (_selectedCountryId != null && countryIdInt == null) {
      _showSnackBar(context, 'Invalid Country ID selected.', color: Colors.red);
      return;
    }

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/users/update/$userId'); // Fixed: Changed /user/ to /users/
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'username': username,
              'fullname': fullname,
              'email': email,
              'phone': phone,
              'address': address,
              'role': _selectedRole, // _selectedRole can now be null
              'country_id': countryIdInt, // countryIdInt can now be null
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'User updated successfully!',
            color: Colors.green);
        _usernameController.clear();
        _fullnameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _addressController.clear();
        setState(() {
          _selectedRole = null; // Clear selected role
          _selectedCountryId = null; // Clear selected country
          _currentView = UserView.list;
          _editingUser = null; // Clear editing state
        });
        _fetchUsersData(); // Refresh list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to update user. Server error.',
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

  // Function to handle Delete User API Call
  Future<void> _deleteUser(String userId) async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/users/delete/$userId'); // Fixed: Changed /user/ to /users/
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'User deleted successfully!',
            color: Colors.green);
        _fetchUsersData(); // Refresh list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to delete user. Server error.',
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
                'Users',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Clear controllers for new creation
                  _usernameController.clear();
                  _fullnameController.clear();
                  _emailController.clear();
                  _passwordController.clear();
                  _phoneController.clear();
                  _addressController.clear();
                  setState(() {
                    _selectedRole = null; // Clear selected role for new user
                    _selectedCountryId =
                        null; // Clear selected country for new user
                    _currentView = UserView.create;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add New User'),
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
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No users available.'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final user = snapshot.data![index];
                    final countryName = _countries.firstWhere(
                      (country) => country['id'] == user['country_id'],
                      orElse: () => {'name': 'N/A'},
                    )['name'];

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
                              'Username: ${user['username']}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text('Full Name: ${user['fullname']}'),
                            Text('Email: ${user['email']}'),
                            Text('Phone: ${user['phone']}'),
                            Text('Address: ${user['address']}'),
                            Text('Role: ${user['role']}'),
                            Text('Country: $countryName'),
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
                                        _editingUser = user;
                                        _currentView = UserView.edit;
                                        // Set controllers for editing
                                        _usernameController.text =
                                            user['username'] ?? '';
                                        _fullnameController.text =
                                            user['fullname'] ?? '';
                                        _emailController.text =
                                            user['email'] ?? '';
                                        _phoneController.text =
                                            user['phone'] ?? '';
                                        _addressController.text =
                                            user['address'] ?? '';
                                        _selectedRole = user['role'];
                                        // Ensure _selectedCountryId is a valid ID from the fetched countries
                                        final String? userCountryId =
                                            user['country_id'];
                                        if (userCountryId != null &&
                                            _countries.any((country) =>
                                                country['id'] ==
                                                userCountryId)) {
                                          _selectedCountryId = userCountryId;
                                        } else {
                                          // If the user's country_id is not found in the fetched list, default to null
                                          _selectedCountryId = null;
                                        }
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () {
                                      _deleteUser(user['id']!);
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

  Widget _buildCreateContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Create New User',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _fullnameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: _userRoles.map((String role) {
              return DropdownMenuItem<String>(
                value: role,
                child: Text(role),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedRole = newValue;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a role';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCountryId,
            decoration: const InputDecoration(
              labelText: 'Country',
              border: OutlineInputBorder(),
            ),
            items: _countries.map<DropdownMenuItem<String>>((country) {
              return DropdownMenuItem<String>(
                value: country['id'],
                child: Text(country['name'] ?? 'Unknown'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedCountryId = newValue;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a country';
              }
              return null;
            },
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _createUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Create User', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              // Clear controllers and return to list view
              _usernameController.clear();
              _fullnameController.clear();
              _emailController.clear();
              _passwordController.clear();
              _phoneController.clear();
              _addressController.clear();
              setState(() {
                _selectedRole = null; // Clear selected role
                _selectedCountryId = null; // Clear selected country
                _currentView = UserView.list;
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

  Widget _buildEditContent(Map<String, String> user) {
    //print('--- Entering _buildEditContent for User ID: ${user['id']} ---');
    //print('Initial User Data: $user');
    // Populate controllers with existing data when the form is opened

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit User: ${user['username']}',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
            readOnly: true, // Username usually not editable
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _fullnameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: _userRoles.map((String role) {
              return DropdownMenuItem<String>(
                value: role,
                child: Text(role),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedRole = newValue;
                print('Dropdown: Selected Role changed to: $_selectedRole');
              });
            },
            // Removed validator property for edit mode
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCountryId,
            decoration: const InputDecoration(
              labelText: 'Country',
              border: OutlineInputBorder(),
            ),
            items: _countries.map<DropdownMenuItem<String>>((country) {
              return DropdownMenuItem<String>(
                value: country['id'],
                child: Text(country['name'] ?? 'Unknown'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedCountryId = newValue;
                print(
                    'Dropdown: Selected Country changed to: $_selectedCountryId');
              });
            },
            // Removed validator property for edit mode
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => _updateUser(user['id']!),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Update User', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              // Clear controllers and return to list view
              _usernameController.clear();
              _fullnameController.clear();
              _emailController.clear();
              _phoneController.clear();
              _addressController.clear();
              setState(() {
                _selectedRole = null; // Clear selected role
                _selectedCountryId = null; // Clear selected country
                _currentView = UserView.list;
                _editingUser = null; // Clear editing state
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
        title: const Text('User Management'),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentView) {
      case UserView.list:
        return _buildListContent();
      case UserView.create:
        return _buildCreateContent();
      case UserView.edit:
        return _buildEditContent(_editingUser!);
      default:
        return _buildListContent(); // Fallback to list view
    }
  }
}
