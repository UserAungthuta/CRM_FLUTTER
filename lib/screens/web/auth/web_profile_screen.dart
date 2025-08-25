// lib/screens/admin/web_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
import '../../../widgets/sidebar_widget.dart';
import '../../../models/user_model.dart'; // Import the user model

// Enum to manage the current view state for the profile
enum ProfileView {
  view,
  edit,
}

class WebProfileScreen extends StatefulWidget {
  const WebProfileScreen({super.key});

  @override
  State<WebProfileScreen> createState() => _WebProfileScreenState();
}

class _WebProfileScreenState extends State<WebProfileScreen> {
  // Constants for layout
  static const double _kSidebarWidth = 256.0; // Width of the persistent sidebar
  static const double _kContentHorizontalPadding = 20.0;
  static const double _kAppBarHeight = kToolbarHeight; // Height of the app bar

  User? _currentUser;
  bool _isLoading = true;
  ProfileView _currentView = ProfileView.view;
  bool _isSidebarOpen = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // TextEditingControllers for profile editing
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String? _countryName; // To display country name
  int? _countryId;
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();

  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
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

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final User? storedUser = await SharedPrefs.getUser();
      if (storedUser == null) {
        _showSnackBar(context, 'User data missing. Please log in again.',
            color: Colors.red);
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      _currentUser = storedUser;
      final int currentUserId = _currentUser!.id;

      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/users/read/$currentUserId');

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
        setState(() {
          _currentUser = User.fromJson(responseData);
          _usernameController.text =
              _currentUser!.username; // Initialize username controller
          _fullnameController.text = _currentUser!.fullname;
          _emailController.text = _currentUser!.email;
          _phoneController.text = _currentUser!.phone ?? '';
          _addressController.text = _currentUser!.address ?? '';
          _countryId = _currentUser!.countryId;
          _countryName = _currentUser!.countryName ?? 'N/A';

          _isLoading = false;
        });
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to load profile. Server error.',
            color: Colors.red);
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } on SocketException {
      _showSnackBar(context, 'Network error. Check your internet connection.',
          color: Colors.red);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } on TimeoutException {
      _showSnackBar(context, 'Request timed out. Server not responding.',
          color: Colors.red);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } on FormatException {
      _showSnackBar(context, 'Invalid response format from server.',
          color: Colors.red);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
          color: Colors.red);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateUserProfile() async {
    if (_currentUser == null) {
      _showSnackBar(context, 'No user data to update.', color: Colors.orange);
      return;
    }

    // Validation for profile fields
    if (_usernameController.text.trim().isEmpty || // Added username validation
        _fullnameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      _showSnackBar(context, 'Username, Full name and email are required.',
          color: Colors.orange);
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
        .hasMatch(_emailController.text.trim())) {
      _showSnackBar(context, 'Please enter a valid email address.',
          color: Colors.orange);
      return;
    }

    // Password update validation
    final String currentPassword = _currentPasswordController.text.trim();
    final String newPassword = _newPasswordController.text.trim();
    final String confirmNewPassword = _confirmNewPasswordController.text.trim();

    bool passwordChangeAttempted = newPassword.isNotEmpty ||
        confirmNewPassword.isNotEmpty ||
        currentPassword.isNotEmpty;

    if (passwordChangeAttempted) {
      if (currentPassword.isEmpty) {
        _showSnackBar(
            context, 'Current password is required to change password.',
            color: Colors.orange);
        return;
      }
      if (newPassword.isEmpty) {
        _showSnackBar(context, 'New password cannot be empty.',
            color: Colors.orange);
        return;
      }
      if (newPassword != confirmNewPassword) {
        _showSnackBar(context, 'New password and confirmation do not match.',
            color: Colors.orange);
        return;
      }
      if (newPassword.length < 6) {
        // Example: Minimum password length
        _showSnackBar(
            context, 'New password must be at least 6 characters long.',
            color: Colors.orange);
        return;
      }
    }

    setState(() {
      _isLoading = true; // Show loading indicator during update
    });

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/users/profile/${_currentUser!.id}');

      final Map<String, dynamic> requestBody = {
        'username':
            _usernameController.text.trim(), // Added username to request body
        'fullname': _fullnameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'country_id': _countryId,
      };

      if (passwordChangeAttempted && newPassword.isNotEmpty) {
        requestBody['current_password'] = currentPassword;
        requestBody['new_password'] = newPassword; // This is the new password
      }

      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Profile updated successfully!',
            color: Colors.green);
        // Clear password fields after successful update
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmNewPasswordController.clear();
        await _fetchUserProfile(); // Re-fetch to get latest data and clear dirty state
        if (mounted) {
          setState(() {
            _currentView = ProfileView.view; // Switch back to view mode
          });
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to update profile. Server error.',
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await SharedPrefs.clearAll(); // Clear user data and token
    // Navigate back to the login screen, removing all previous routes
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
    _showSnackBar(context, 'Logged out successfully!', color: Colors.green);
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    if (_newPasswordController.text != _confirmNewPasswordController.text) {
      _showSnackBar(context, 'New password and confirm password do not match.',
          color: Colors.orange);
      return;
    }

    try {
      final String? token = await SharedPrefs.getToken();
      final String userId = SharedPrefs.getUserId().toString();

      if (token == null || token.isEmpty || userId.isEmpty) {
        _showSnackBar(context,
            'Authentication token or User ID missing. Please log in again.',
            color: Colors.red);
        return;
      }

      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/users/updateprofile/$userId');
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'current_password': _currentPasswordController.text,
              'new_password': _newPasswordController.text,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Password updated successfully!',
            color: Colors.green);
        // Clear password fields
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmNewPasswordController.clear();
        setState(() {
          _currentView = ProfileView.view; // Switch back to view mode
        });
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to change password. Server error.',
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

  Widget _buildViewContent() {
    if (_currentUser == null) {
      return const Center(child: Text('User data not available.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: _kContentHorizontalPadding, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Profile',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildProfileInfoRow('Username', _currentUser!.username),
          _buildProfileInfoRow('Full Name', _currentUser!.fullname ?? 'N/A'),
          _buildProfileInfoRow('Email', _currentUser!.email),
          _buildProfileInfoRow('Role', _currentUser!.role),
          _buildProfileInfoRow(
              'Country ID', _currentUser!.countryId?.toString() ?? 'N/A'),
          _buildProfileInfoRow('Phone', _currentUser!.phone ?? 'N/A'),
          _buildProfileInfoRow('Address', _currentUser!.address ?? 'N/A'),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _currentView = ProfileView.edit;
              });
            },
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text('Edit Profile',
                style: TextStyle(fontSize: 18, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 30),
          _buildChangePasswordSection(),
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150, // Adjust width as needed for labels
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditContent() {
    if (_currentUser == null) {
      return const Center(child: Text('User data not available for editing.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: _kContentHorizontalPadding, vertical: 16.0),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Profile',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a username';
                }
                return null;
              },
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
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an email';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _updateUserProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 25),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save Changes',
                      style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentView =
                          ProfileView.view; // Cancel and go back to view
                      _fetchUserProfile(); // Re-fetch to discard local changes
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 25),
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 30),
            _buildChangePasswordSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePasswordSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _passwordFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change Password',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmNewPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Change Password',
                    style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
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

  Widget _buildBodyContent() {
    switch (_currentView) {
      case ProfileView.view:
        return _buildViewContent();
      case ProfileView.edit:
        return _buildEditContent();
      default:
        return _buildViewContent(); // Fallback
    }
  }
}
