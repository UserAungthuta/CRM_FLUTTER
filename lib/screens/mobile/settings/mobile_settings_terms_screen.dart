import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

// Enum to manage the current view state for Terms Config
enum TermsView {
  list,
  create,
  edit,
}

class MobileSettingsTermsScreen extends StatefulWidget {
  const MobileSettingsTermsScreen({super.key});

  @override
  _MobileSettingsTermsScreenState createState() =>
      _MobileSettingsTermsScreenState();
}

class _MobileSettingsTermsScreenState extends State<MobileSettingsTermsScreen> {
  late Future<List<Map<String, String>>> _termsFuture;
  TermsView _currentView = TermsView.list; // Default view is the list
  Map<String, String>? _editingTerm; // Holds data of the term being edited

  // Controllers for the forms (add/edit)
  String? _selectedCategory; // For the dropdown
  final TextEditingController _termsTitleController = TextEditingController();
  final TextEditingController _termsContentController = TextEditingController();

  // Predefined categories for the dropdown
  final List<String> _termsCategories = [
    'service',
    'privacy',
    'support',
    'security',
    'disclaimer'
  ];

  @override
  void initState() {
    super.initState();
    _fetchTermsData();
  }

  @override
  void dispose() {
    _termsTitleController.dispose();
    _termsContentController.dispose();
    super.dispose();
  }

  // Refreshes the terms list data
  void _fetchTermsData() {
    setState(() {
      _termsFuture = _fetchTerms();
    });
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

  /// Fetches the list of terms from the API and parses the new JSON structure.
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
    // Fallback return to ensure all code paths return a value
    return [];
  }

  // Function to handle Create Term API Call
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
          _editingTerm = null;
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

  // Method to build the "Create Term" form content
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
              labelText: 'Terms Category',
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
              labelText: 'Terms Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _termsContentController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Terms Content',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _createTerm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save Term', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
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
                  borderRadius: BorderRadius.circular(8)),
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
    // Note: _selectedCategory and controllers are now initialized in the onPressed of the edit button
    // to prevent re-initialization on subsequent widget rebuilds.
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
              labelText: 'Terms Category',
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
              labelText: 'Terms Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _termsContentController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Terms Content',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => _updateTerm(term['id']!),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Update Term', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              _selectedCategory = null;
              _termsTitleController.clear();
              _termsContentController.clear();
              setState(() {
                _currentView = TermsView.list;
                _editingTerm = null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentView == TermsView.list
              ? 'Terms & Conditions'
              : (_currentView == TermsView.create
                  ? 'Add New Term'
                  : 'Edit Term'),
        ),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
        leading: _currentView != TermsView.list
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _selectedCategory = null;
                  _termsTitleController.clear();
                  _termsContentController.clear();
                  setState(() {
                    _currentView = TermsView.list;
                    _editingTerm = null;
                  });
                },
              )
            : null,
      ),
      body: _currentView == TermsView.list
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _selectedCategory = null; // Clear for new creation
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
                        backgroundColor: const Color(0xFF336EE5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[700],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: FutureBuilder<List<Map<String, String>>>(
                      future: _termsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(
                              child: Text('No terms available.'));
                        } else {
                          final terms = snapshot.data!;
                          return ListView.builder(
                            itemCount: terms.length,
                            itemBuilder: (context, index) {
                              final term = terms[index];
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    // Optionally navigate to a detail screen or handle tap
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                term['terms_title'] ?? 'N/A',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Category: ${term['terms_category'] ?? 'N/A'}',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey),
                                              ),
                                              Text(
                                                term['terms_content'] ?? 'N/A',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          onPressed: () {
                                            setState(() {
                                              _editingTerm = term;
                                              // Initialize controllers and selected category here
                                              _selectedCategory =
                                                  term['terms_category'];
                                              _termsTitleController.text =
                                                  term['terms_title'] ?? '';
                                              _termsContentController.text =
                                                  term['terms_content'] ?? '';
                                              _currentView = TermsView.edit;
                                            });
                                          },
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
                ),
              ],
            )
          : (_currentView == TermsView.create
              ? _buildCreateContent()
              : _buildEditContent(_editingTerm!)),
    );
  }
}
