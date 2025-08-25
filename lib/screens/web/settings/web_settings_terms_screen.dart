// lib/screens/admin/web_settings_terms_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding
import 'dart:async'; // Import for TimeoutException
import 'dart:io'; // Import for SocketException
import '../../../models/user_model.dart';
import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';
// Import the new sidebar widget
import '../../../widgets/sidebar_widget.dart';

enum TermsView {
  list,
  create,
  edit,
}

class WebSettingsTermsScreen extends StatefulWidget {
  const WebSettingsTermsScreen({super.key});

  @override
  State<WebSettingsTermsScreen> createState() => _WebSettingsTermsScreenState();
}

class _WebSettingsTermsScreenState extends State<WebSettingsTermsScreen> {
  // Constants for layout
  static const double _kSidebarWidth = 256.0; // Width of the persistent sidebar
  static const double _kContentHorizontalPadding =
      20.0; // Padding around main content sections
  static const double _kWrapSpacing = 16.0; // Spacing between cards in Wrap
  static const double _kAppBarHeight = kToolbarHeight; // Standard AppBar height
  late Future<List<Map<String, String>>> _termsFuture;
  TermsView _currentView = TermsView.list; // Default view is the list
  Map<String, String>? _editingTerms; // Holds data of the terms being edited

  // Controllers for the forms (add/edit)
  String? _selectedCategory; // For the dropdown
  final TextEditingController _termsTitleController = TextEditingController();
  final TextEditingController _termsContentController = TextEditingController();

  final List<String> _termsCategories = [
    'service',
    'privacy',
    'support',
    'security',
    'disclaimer'
  ];

  // Placeholder for user details (will be fetched)
  User? _currentUser;

  // Key for Scaffold to control the Drawer (only used for small screens)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variable to control the visibility of the persistent sidebar on large screens
  bool _isSidebarOpen = true; // Initial state: sidebar is open

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Fetch user data on init
    _fetchTermsData(); // Fetch terms data on init
  }

  @override
  void dispose() {
    _termsTitleController.dispose();
    _termsContentController.dispose();
    super.dispose();
  }

  void _fetchTermsData() {
    setState(() {
      _termsFuture = _fetchTerms();
    });
  }

  // Helper method to show a SnackBar message (can still be used for other alerts)
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

  Future<List<Map<String, String>>> _fetchTerms() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        return [];
      }

      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/terms/readall');

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
          List<Map<String, String>> terms = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              terms.add({
                'id': item['id']?.toString() ?? 'N/A',
                'terms_category': item['terms_category'] as String,
                'terms_title': item['terms_title'] as String,
                'terms_content': item['terms_content'] as String,
              });
            }
          }
          return terms;
        } else {
          _showSnackBar(context, 'Failed to load terms. Invalid data format.',
              color: Colors.red);
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to load terms. Server error.',
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

  // Method to handle user logout
  Future<void> _logout() async {
    await SharedPrefs.clearAll(); // Clear user data and token
    // Navigate back to the login screen, removing all previous routes
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
    _showSnackBar(context, 'Logged out successfully!', color: Colors.green);
  }

  // Fetches current user data from SharedPrefs
  Future<void> _fetchUserData() async {
    final user = await SharedPrefs.getUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _createTerm() async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    final String? termsCategory = _selectedCategory;
    final String termsTitle = _termsTitleController.text.trim();
    final String termsContent = _termsContentController.text.trim();

    if (termsCategory == null || termsTitle.isEmpty || termsContent.isEmpty) {
      _showSnackBar(context, 'All fields are required.', color: Colors.orange);
      return;
    }

    try {
      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/terms/create');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'terms_category': termsCategory,
              'terms_title': termsTitle,
              'terms_content': termsContent,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSnackBar(context, 'Term created successfully!',
            color: Colors.green);
        _selectedCategory = null;
        _termsTitleController.clear();
        _termsContentController.clear();
        setState(() {
          _currentView = TermsView.list;
        });
        _fetchTermsData(); // Refresh list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to create term. Server error.',
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

  // Function to handle Update Term API Call
  Future<void> _updateTerm(String termId) async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    final String? termsCategory = _selectedCategory;
    final String termsTitle = _termsTitleController.text.trim();
    final String termsContent = _termsContentController.text.trim();

    if (termsCategory == null || termsTitle.isEmpty || termsContent.isEmpty) {
      _showSnackBar(context, 'All fields are required.', color: Colors.orange);
      return;
    }

    try {
      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/terms/update/$termId');
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'terms_category': termsCategory,
              'terms_title': termsTitle,
              'terms_content': termsContent,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Term updated successfully!',
            color: Colors.green);
        _selectedCategory = null;
        _termsTitleController.clear();
        _termsContentController.clear();
        setState(() {
          _currentView = TermsView.list;
          _editingTerms = null;
        });
        _fetchTermsData(); // Refresh list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to update term. Server error.',
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

  Future<void> _deleteTerm(String termId) async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    // Show a confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
              'Are you sure you want to delete this term? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (!confirmDelete) {
      return; // User cancelled the deletion
    }

    try {
      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/terms/delete/$termId');
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Term deleted successfully!',
            color: Colors.green);
        _fetchTermsData(); // Refresh list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to delete term. Server error.',
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: _kContentHorizontalPadding)
                  .copyWith(top: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Terms Settings',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _selectedCategory = null;
                  _termsTitleController.clear();
                  _termsContentController.clear();
                  setState(() {
                    _currentView = TermsView.create;
                  });
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add New Term',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: FutureBuilder<List<Map<String, String>>>(
            future: _termsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No terms available.'));
              } else {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: _kContentHorizontalPadding),
                  child: ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final term = snapshot.data![index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: ListTile(
                          title: Text(term['terms_title'] ?? 'N/A'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Category: ${term['terms_category'] ?? 'N/A'}'),
                              Text('Content: ${term['terms_content'] ?? 'N/A'}',
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  setState(() {
                                    _editingTerms = term;
                                    _currentView = TermsView.edit;
                                  });
                                },
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTerm(term['id']!),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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
          const Text('Add New Term',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: _termsCategories.map((String category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedCategory = newValue;
              });
            },
            validator: (value) =>
                value == null ? 'Please select a category' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _termsTitleController,
            decoration: const InputDecoration(
              labelText: 'Term Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _termsContentController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Term Content',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _createTerm, // Call the new _createTerm function
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Save Term', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              // Clear controllers and return to list view
              _selectedCategory = null;
              _termsTitleController.clear();
              _termsContentController.clear();
              setState(() {
                _currentView = TermsView.list;
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

  // Method to build the "Edit Term" form content
  Widget _buildEditContent(Map<String, String> term) {
    // Populate controllers with existing data when the form is opened
    _selectedCategory = term['terms_category'];
    _termsTitleController.text = term['terms_title'] ?? '';
    _termsContentController.text = term['terms_content'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit Term: ${term['terms_title']}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: _termsCategories.map((String category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedCategory = newValue;
              });
            },
            validator: (value) =>
                value == null ? 'Please select a category' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _termsTitleController,
            decoration: const InputDecoration(
              labelText: 'Term Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _termsContentController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Term Content',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () =>
                _updateTerm(term['id']!), // Call the new _updateTerm function
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Update Term', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              // Clear controllers and return to list view
              _selectedCategory = null;
              _termsTitleController.clear();
              _termsContentController.clear();
              setState(() {
                _currentView = TermsView.list;
                _editingTerms = null; // Clear editing state
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

  // Custom AppBar/Header content for large screens
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

  // A single method to return the appropriate content based on _currentView
  Widget _buildBodyContent() {
    switch (_currentView) {
      case TermsView.list:
        return _buildListContent();
      case TermsView.create:
        return _buildCreateContent();
      case TermsView.edit:
        return _buildEditContent(_editingTerms!);
      default:
        return _buildListContent(); // Fallback to list view
    }
  }

  // Helper method for building drawer items (similar to sidebar but separate for clarity)
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
