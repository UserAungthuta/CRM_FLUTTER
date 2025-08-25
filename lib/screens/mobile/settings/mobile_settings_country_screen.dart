import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

// Enum to manage the current view state
enum CountryView {
  list,
  create,
  edit,
}

class MobileSettingsCountryScreen extends StatefulWidget {
  const MobileSettingsCountryScreen({super.key});

  @override
  _MobileSettingsCountryScreenState createState() =>
      _MobileSettingsCountryScreenState();
}

class _MobileSettingsCountryScreenState
    extends State<MobileSettingsCountryScreen> {
  late Future<List<Map<String, String>>> _countriesFuture;
  CountryView _currentView = CountryView.list; // Default view is the list
  Map<String, String>?
      _editingCountry; // Holds data of the country being edited

  // Controllers for the forms (add/edit)
  final TextEditingController _countryNameController = TextEditingController();
  final TextEditingController _countryCodeController = TextEditingController();
  final TextEditingController _phoneCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCountriesData(); // Renamed to clearly indicate it fetches data
  }

  @override
  void dispose() {
    _countryNameController.dispose();
    _countryCodeController.dispose();
    _phoneCodeController.dispose();
    super.dispose();
  }

  // Refreshes the country list data
  void _fetchCountriesData() {
    setState(() {
      _countriesFuture = _fetchCountries();
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

  /// Fetches the list of countries from the API and parses the new JSON structure.
  Future<List<Map<String, String>>> _fetchCountries() async {
    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        return [];
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
          throw TimeoutException('Request timeout - Server not responding.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['data'] is List) {
          List<Map<String, String>> countries = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              countries.add({
                'id': item['id']?.toString() ?? 'N/A',
                'country_name': item['country_name'] as String,
                'country_name_code': item['country_name_code'] as String,
                'country_phone_code': item['country_phone_code'] as String,
              });
            }
          }
          return countries;
        } else {
          _showSnackBar(
              context, 'Failed to load countries. Invalid data format.',
              color: Colors.red);
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to load countries. Server error.',
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

  // --- NEW: Function to handle Create Country API Call ---
  Future<void> _createCountry() async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    final String countryName = _countryNameController.text.trim();
    final String countryCode = _countryCodeController.text.trim();
    final String phoneCode = _phoneCodeController.text.trim();

    if (countryName.isEmpty || countryCode.isEmpty || phoneCode.isEmpty) {
      _showSnackBar(context, 'All fields are required.', color: Colors.orange);
      return;
    }

    try {
      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/country/create');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'country_name': countryName,
              'country_name_code': countryCode,
              'country_phone_code': phoneCode,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSnackBar(context, 'Country created successfully!',
            color: Colors.green);
        _countryNameController.clear();
        _countryCodeController.clear();
        _phoneCodeController.clear();
        setState(() {
          _currentView = CountryView.list;
        });
        _fetchCountriesData(); // Refresh list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to create country. Server error.',
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

  // --- NEW: Function to handle Update Country API Call ---
  Future<void> _updateCountry(String countryId) async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    final String countryName = _countryNameController.text.trim();
    final String countryCode = _countryCodeController.text.trim();
    final String phoneCode = _phoneCodeController.text.trim();

    if (countryName.isEmpty || countryCode.isEmpty || phoneCode.isEmpty) {
      _showSnackBar(context, 'All fields are required.', color: Colors.orange);
      return;
    }

    try {
      final Uri uri =
          Uri.parse('${ApiConfig.baseUrl}/country/update/$countryId');
      final response = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'country_name': countryName,
              'country_name_code': countryCode,
              'country_phone_code': phoneCode,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Country updated successfully!',
            color: Colors.green);
        _countryNameController.clear();
        _countryCodeController.clear();
        _phoneCodeController.clear();
        setState(() {
          _currentView = CountryView.list;
          _editingCountry = null;
        });
        _fetchCountriesData(); // Refresh list
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to update country. Server error.',
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

  // Method to build the "Create Country" form content
  Widget _buildCreateContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add New Country',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _countryNameController,
            decoration: const InputDecoration(
              labelText: 'Country Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _countryCodeController,
            decoration: const InputDecoration(
              labelText: 'Country Code (e.g., SG, TH)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneCodeController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Code (e.g., +65, +66)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _createCountry, // Call the new _createCountry function
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save Country', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              // Clear controllers and return to list view
              _countryNameController.clear();
              _countryCodeController.clear();
              _phoneCodeController.clear();
              setState(() {
                _currentView = CountryView.list;
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

  // Method to build the "Edit Country" form content
  Widget _buildEditContent(Map<String, String> country) {
    // Populate controllers with existing data when the form is opened
    _countryNameController.text = country['country_name'] ?? '';
    _countryCodeController.text = country['country_name_code'] ?? '';
    _phoneCodeController.text = country['country_phone_code'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit Country: ${country['country_name']}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _countryNameController,
            decoration: const InputDecoration(
              labelText: 'Country Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _countryCodeController,
            decoration: const InputDecoration(
              labelText: 'Country Code (e.g., SG, TH)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneCodeController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Code (e.g., +65, +66)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => _updateCountry(
                country['id']!), // Call the new _updateCountry function
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Update Country', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              // Clear controllers and return to list view
              _countryNameController.clear();
              _countryCodeController.clear();
              _phoneCodeController.clear();
              setState(() {
                _currentView = CountryView.list;
                _editingCountry = null; // Clear editing state
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
          _currentView == CountryView.list
              ? 'Select Country'
              : (_currentView == CountryView.create
                  ? 'Add Country'
                  : 'Edit Country'),
        ),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
        leading: _currentView != CountryView.list
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _countryNameController.clear();
                  _countryCodeController.clear();
                  _phoneCodeController.clear();
                  setState(() {
                    _currentView = CountryView.list;
                    _editingCountry = null;
                  });
                },
              )
            : null,
      ),
      body: _currentView == CountryView.list
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _countryNameController.clear();
                        _countryCodeController.clear();
                        _phoneCodeController.clear();
                        setState(() {
                          _currentView = CountryView.create;
                        });
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Add New Country',
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
                // Country List Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Country List',
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
                      future: _countriesFuture,
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
                              child: Text('No countries available.'));
                        } else {
                          final countries = snapshot.data!;
                          return ListView.builder(
                            itemCount: countries.length,
                            itemBuilder: (context, index) {
                              final country = countries[index];
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    Navigator.of(context)
                                        .pop(country['country_name']);
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
                                                country['country_name'] ??
                                                    'N/A',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Code: ${country['country_name_code'] ?? 'N/A'}',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey),
                                              ),
                                              Text(
                                                'Phone: ${country['country_phone_code'] ?? 'N/A'}',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          onPressed: () {
                                            setState(() {
                                              _editingCountry = country;
                                              _currentView = CountryView.edit;
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
          : (_currentView == CountryView.create
              ? _buildCreateContent()
              : _buildEditContent(_editingCountry!)),
    );
  }
}
