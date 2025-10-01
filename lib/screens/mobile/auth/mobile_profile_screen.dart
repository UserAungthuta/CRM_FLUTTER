// lib/screens/mobile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../models/user_model.dart';
import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

// Enum to manage the current view state for the profile screen
enum ProfileView {
  view,
  edit,
}

class MobileProfileScreen extends StatefulWidget {
  const MobileProfileScreen({super.key});

  @override
  _MobileProfileScreenState createState() => _MobileProfileScreenState();
}

class _MobileProfileScreenState extends State<MobileProfileScreen> {
  User? _user;
  bool _isLoading = true;
  ProfileView _currentView =
      ProfileView.view; // Default view is to display profile

  // Text editing controllers for the profile fields
  final TextEditingController _usernameController =
      TextEditingController(); // Added username controller
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String? _countryName; // To display country name
  int? _countryId; // To send country ID in update payload

  // New controllers for password update
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();

  // State variables to toggle password visibility
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmNewPassword = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose(); // Dispose username controller
    _fullnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    // Dispose new password controllers
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

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

  /// Fetches the current user's profile data from the API.
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
      _user = storedUser;
      final int currentUserId = _user!.id;

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
          _user = User.fromJson(responseData);
          _usernameController.text =
              _user!.username; // Initialize username controller
          _fullnameController.text = _user!.fullname;
          _emailController.text = _user!.email;
          _phoneController.text = _user!.phone ?? '';
          _addressController.text = _user!.address ?? '';
          _countryId = _user!.countryId;
          _countryName = _user!.countryName ?? 'N/A';

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

  /// Updates the current user's profile data.
  Future<void> _updateUserProfile() async {
    if (_user == null) {
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
          Uri.parse('${ApiConfig.baseUrl}/users/profile/${_user!.id}');

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
      //print(requestBody);
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

  Widget _buildProfileView() {
    if (_user == null) {
      return const Center(child: Text('No user data available.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileInfoRow('Username', _user!.username, Icons.person),
          _buildProfileInfoRow('Full Name', _user!.fullname, Icons.badge),
          _buildProfileInfoRow('Email', _user!.email, Icons.email),
          _buildProfileInfoRow('Role', _user!.role, Icons.security),
          _buildProfileInfoRow('Phone', _user!.phone ?? 'N/A', Icons.phone),
          _buildProfileInfoRow('Address', _user!.address ?? 'N/A', Icons.home),
          _buildProfileInfoRow('Country', _countryName ?? 'N/A', Icons.flag),
          const SizedBox(height: 30),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentView = ProfileView.edit;
                });
              },
              icon: const Icon(Icons.edit, color: Colors.white),
              label: const Text('Edit Profile',
                  style: TextStyle(fontSize: 18, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF336EE5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blueGrey, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditProfileView() {
    if (_user == null) {
      return const Center(child: Text('Error: No user data for editing.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Edit Profile',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            // Username is now editable
            controller: _usernameController,
            decoration: _inputDecoration('Username', Icons.person),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _fullnameController,
            decoration: _inputDecoration('Full Name', Icons.badge),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: _inputDecoration('Email', Icons.email),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildReadOnlyField('Role', _user!.role, Icons.security),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: _inputDecoration('Phone', Icons.phone),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: _inputDecoration('Address', Icons.home),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          // Country field: Display only. Updating country might require a separate selection flow.
          _buildReadOnlyField('Country', _countryName ?? 'N/A', Icons.flag),

          const SizedBox(height: 30),
          const Text('Change Password (Optional)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _currentPasswordController,
            decoration:
                _inputDecoration('Current Password', Icons.lock).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrentPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscureCurrentPassword = !_obscureCurrentPassword;
                  });
                },
              ),
            ),
            obscureText: _obscureCurrentPassword,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _newPasswordController,
            decoration:
                _inputDecoration('New Password', Icons.lock_open).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscureNewPassword = !_obscureNewPassword;
                  });
                },
              ),
            ),
            obscureText: _obscureNewPassword,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmNewPasswordController,
            decoration:
                _inputDecoration('Confirm New Password', Icons.lock_outline)
                    .copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmNewPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmNewPassword = !_obscureConfirmNewPassword;
                  });
                },
              ),
            ),
            obscureText: _obscureConfirmNewPassword,
          ),

          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _updateUserProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save Changes', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              // Re-populate controllers with current _user data if cancelled
              _usernameController.text = _user!.username; // Reset username
              _fullnameController.text = _user!.fullname;
              _emailController.text = _user!.email;
              _phoneController.text = _user!.phone ?? '';
              _addressController.text = _user!.address ?? '';
              // Clear password fields on cancel
              _currentPasswordController.clear();
              _newPasswordController.clear();
              _confirmNewPasswordController.clear();
              // Reset password visibility toggles
              setState(() {
                _obscureCurrentPassword = true;
                _obscureNewPassword = true;
                _obscureConfirmNewPassword = true;
                _currentView = ProfileView.view;
              });
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: Colors.blueGrey),
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey, width: 1.0),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF336EE5), width: 2.0),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: _inputDecoration(label, icon).copyWith(
        filled: true,
        fillColor: Colors.grey[100],
      ),
      style: const TextStyle(color: Colors.black54),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentView == ProfileView.view ? 'My Profile' : 'Edit Profile',
        ),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
        leading: _currentView == ProfileView.edit
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // Re-populate controllers with current _user data if cancelled
                  _usernameController.text = _user!.username; // Reset username
                  _fullnameController.text = _user!.fullname;
                  _emailController.text = _user!.email;
                  _phoneController.text = _user!.phone ?? '';
                  _addressController.text = _user!.address ?? '';
                  // Clear password fields on back press
                  _currentPasswordController.clear();
                  _newPasswordController.clear();
                  _confirmNewPasswordController.clear();
                  // Reset password visibility toggles
                  setState(() {
                    _obscureCurrentPassword = true;
                    _obscureNewPassword = true;
                    _obscureConfirmNewPassword = true;
                    _currentView = ProfileView.view;
                  });
                },
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_currentView == ProfileView.view
              ? _buildProfileView()
              : _buildEditProfileView()),
    );
  }
}
