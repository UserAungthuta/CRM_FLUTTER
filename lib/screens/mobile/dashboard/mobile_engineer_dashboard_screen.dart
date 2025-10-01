// lib/screens/engineer/mobile_engineer_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding
import 'dart:async'; // Import for TimeoutException
import 'dart:io'; // Import for SocketException

import '../../../models/user_model.dart';
import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart'; // Ensure ApiConfig is correctly imported

class MobileEngineerDashboardScreen extends StatefulWidget {
  const MobileEngineerDashboardScreen({super.key});

  @override
  _MobileEngineerDashboardScreenState createState() =>
      _MobileEngineerDashboardScreenState();
}

class _MobileEngineerDashboardScreenState
    extends State<MobileEngineerDashboardScreen> {
  int _selectedIndex = 0; // State to manage the selected tab index

  // Use a Future variable to hold the quick stats data
  late Future<Map<String, dynamic>> _quickStatsFuture;

  // List of widgets for each tab in the BottomNavigationBar
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _quickStatsFuture = _fetchQuickStats(); // Initialize the future
    _widgetOptions = <Widget>[
      _buildHomeContent(), // Index 0: Home (Engineer Quick Stats)
      _buildProductsContent(),
      _buildReportsContent(), // Index 1: Products (Assigned Products relevant to engineer)
    ];
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

  // Method to handle user logout
  Future<void> _logout(BuildContext context) async {
    await SharedPrefs.clearAll(); // Clear user data and token
    // Navigate back to the login screen, removing all previous routes
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    _showSnackBar(context, 'Logged out successfully!', color: Colors.green);
  }

  // Method to handle tap on BottomNavigationBar items
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Update snackbar messages for each specific tab
    switch (index) {
      case 0: // Home
        _quickStatsFuture =
            _fetchQuickStats(); // Re-fetch quick stats for Home tab
        break;
      case 1: // Products (Assigned Products relevant to engineer)
        _showSnackBar(
            context, 'Products tab selected!'); // Navigate to assigned products
        break;
      case 2: // Reports
        _showSnackBar(
            context, 'Reports tab selected!'); // Navigate to engineer reports
        break;
    }
  }

  /// Fetches quick statistics data from the backend API for an Engineer.
  Future<Map<String, dynamic>> _fetchQuickStats() async {
    try {
      final String? token =
          await SharedPrefs.getToken(); // Retrieve authentication token
      final int? userId = await SharedPrefs.getUserId(); // Retrieve user ID

      if (token == null || token.isEmpty || userId == null) {
        throw Exception(
            'Authentication token or User ID missing. Please log in again.');
      }

      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/quickstats/engineer'), // Engineer-specific endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Add Authorization header
        },
      ).timeout(
        const Duration(seconds: 5), // Reduced timeout to 5 seconds
        onTimeout: () {
          throw TimeoutException(
              'Request timeout - Server not responding for quick stats');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(data['data']);
        } else {
          throw Exception(data['message'] ??
              'Failed to load quick stats. Invalid data format.');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ??
            'Failed to load quick stats. Server error.');
      }
    } on SocketException {
      throw Exception(
          'Network error while fetching quick stats. Check your internet connection.');
    } on TimeoutException {
      throw Exception(
          'Quick stats request timed out. Server is not responding.');
    } on FormatException {
      throw Exception('Invalid response format for quick stats from server.');
    } catch (e) {
      throw Exception(
          'An unexpected error occurred while fetching quick stats: ${e.toString()}');
    }
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, VoidCallback onTap) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = (screenWidth - 50.0) / 2; // For 2 cards per row

    return SizedBox(
      width: cardWidth,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 30, color: Colors.blueAccent),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build the main content of the Home dashboard for engineer
  Widget _buildHomeContent() {
    return FutureBuilder<User?>(
      future: SharedPrefs.getUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data == null) {
          return const Center(
              child: Text('Please log in to access the dashboard.'));
        } else {
          final user = snapshot.data!;
          final DateTime nowUtc = DateTime.now().toUtc();
          final DateTime singaporeTime = nowUtc.add(const Duration(hours: 8));

          final String formattedDate =
              '${singaporeTime.day.toString().padLeft(2, '0')}/${singaporeTime.month.toString().padLeft(2, '0')}/${singaporeTime.year}';
          final String formattedTime =
              '${singaporeTime.hour.toString().padLeft(2, '0')}:${singaporeTime.minute.toString().padLeft(2, '0')}';

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  margin: const EdgeInsets.only(bottom: 20.0),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${user.fullname}!',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 13, 13, 14)),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'It\'s $formattedTime on $formattedDate in Singapore.',
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Quick Stats',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FutureBuilder<Map<String, dynamic>>(
                  future: _quickStatsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.hasData) {
                      final quickStatsData = snapshot.data!;
                      return Wrap(
                        spacing: 10.0,
                        runSpacing: 10.0,
                        children: [
                          _buildStatCard(
                              context,
                              'Total Customers',
                              quickStatsData['totalCustomers']?.toString() ??
                                  'N/A',
                              Icons.people_alt, () {
                            _showSnackBar(
                                context, 'Total Customers stat tapped!');
                          }),
                          _buildStatCard(
                              context,
                              'Total Reports',
                              quickStatsData['totalReports']?.toString() ??
                                  'N/A',
                              Icons.assignment, () {
                            Navigator.pushNamed(
                                context, '/mobile_engineer_reports');
                          }),
                          _buildStatCard(
                              context,
                              'Solved Reports',
                              quickStatsData['solvedReports']?.toString() ??
                                  'N/A',
                              Icons.check_circle_outline, () {
                            Navigator.pushNamed(
                                context, '/mobile_engineer_solved_reports');
                          }),
                          _buildStatCard(
                              context,
                              'Unsolved Reports',
                              quickStatsData['unsolvedReports']?.toString() ??
                                  'N/A',
                              Icons.pending_actions, () {
                            Navigator.pushNamed(
                                context, '/mobile_engineer_unsolved_reports');
                          }),
                          _buildStatCard(
                              context,
                              'Total Maintenance',
                              quickStatsData['totalMaintenance']?.toString() ??
                                  'N/A',
                              Icons.build, () {
                            Navigator.pushNamed(context, '/mobile_maintenance');
                          }),
                          _buildStatCard(
                              context,
                              'Customer Products',
                              quickStatsData['customerProducts']?.toString() ??
                                  'N/A',
                              Icons.shopping_bag, () {
                            Navigator.pushNamed(
                                context, '/mobile_assigned_products');
                          }),
                        ],
                      );
                    } else {
                      return const Center(
                          child: Text('No quick stats data available.'));
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildProductsContent() {
    return FutureBuilder<User?>(
      future: SharedPrefs.getUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data == null) {
          return const Center(
              child: Text(
                  'Please log in to access the dashboard.')); // More descriptive message
        } else {
          final user = snapshot.data!;
          final DateTime nowUtc = DateTime.now().toUtc();
          final DateTime singaporeTime = nowUtc.add(const Duration(hours: 8));

          final String formattedDate =
              '${singaporeTime.day.toString().padLeft(2, '0')}/${singaporeTime.month.toString().padLeft(2, '0')}/${singaporeTime.year}';
          final String formattedTime =
              '${singaporeTime.hour.toString().padLeft(2, '0')}:${singaporeTime.minute.toString().padLeft(2, '0')}';

          return Padding(
            padding: const EdgeInsets.all(20.0), // Padding around the content
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.start, // Align content to the top
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // Make children take full width
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment
                      .spaceBetween, // Align text left, icon right
                  children: [
                    Text(
                      'Product Management',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10.0, // Horizontal spacing between cards
                  runSpacing: 10.0, // Vertical spacing between rows of cards
                  children: [
                    _buildSettingCard(
                        context, 'Assigned Products', Icons.shopping_bag, () {
                      Navigator.pushNamed(context, '/mobile_assigned_products');
                    }),
                    _buildSettingCard(
                        context, 'Maintenance Products', Icons.build, () {
                      Navigator.pushNamed(context, '/mobile_maintenance');
                    }),
                  ],
                ),
                const SizedBox(height: 20), // Spacing at the bottom
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildSettingCard(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    // Calculate a width that allows 4 cards per row.
    // The padding around the Column is 20.0 on each side (total 40.0).
    // The Wrap widget has spacing of 10.0 between cards. For 4 cards, there are 3 spacings (30.0).
    // Total horizontal space consumed: 40.0 (padding) + 30.0 (spacing) = 70.0
    final double screenWidth = MediaQuery.of(context).size.width;
    // Adjusted for 4 cards in one row
    final double cardWidth = (screenWidth - 50.0) / 2;

    return SizedBox(
      width: cardWidth,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          // Added InkWell for tap functionality and ripple effect
          onTap: onTap, // Assign the provided onTap callback
          borderRadius: BorderRadius.circular(10), // Match card border radius
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 30, color: Colors.blueAccent),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  maxLines: 1, // Ensure title doesn't wrap excessively
                  overflow: TextOverflow
                      .ellipsis, // Add ellipsis if title is too long
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportsContent() {
    return FutureBuilder<User?>(
      future: SharedPrefs.getUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data == null) {
          return const Center(
              child: Text(
                  'Please log in to access the dashboard.')); // More descriptive message
        } else {
          final user = snapshot.data!;
          final DateTime nowUtc = DateTime.now().toUtc();
          final DateTime singaporeTime = nowUtc.add(const Duration(hours: 8));

          final String formattedDate =
              '${singaporeTime.day.toString().padLeft(2, '0')}/${singaporeTime.month.toString().padLeft(2, '0')}/${singaporeTime.year}';
          final String formattedTime =
              '${singaporeTime.hour.toString().padLeft(2, '0')}:${singaporeTime.minute.toString().padLeft(2, '0')}';

          return Padding(
            padding: const EdgeInsets.all(20.0), // Padding around the content
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.start, // Align content to the top
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // Make children take full width
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment
                      .spaceBetween, // Align text left, icon right
                  children: [
                    Text(
                      'Reports Management',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10.0, // Horizontal spacing between cards
                  runSpacing: 10.0, // Vertical spacing between rows of cards
                  children: [
                    _buildSettingCard(
                        context, 'Total Reports', Icons.assignment, () {
                      Navigator.pushNamed(context, '/mobile_engineer_reports');
                    }),
                    _buildSettingCard(
                        context, 'Solved Reports', Icons.check_circle_outline,
                        () {
                      Navigator.pushNamed(
                          context, '/mobile_engineer_solved_reports');
                    }),
                    _buildSettingCard(
                        context, 'UnSolved Reports', Icons.pending_actions, () {
                      Navigator.pushNamed(
                          context, '/mobile_engineer_unsolved_reports');
                    }),
                  ],
                ),
                const SizedBox(height: 20), // Spacing at the bottom
              ],
            ),
          );
        }
      },
    );
  }

  // Helper method to build placeholder content for other tabs
  static Widget _buildPlaceholderContent(String contentText) {
    return Center(
      child: Text(
        contentText,
        style: const TextStyle(fontSize: 24, color: Colors.black54),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF336EE5),
          ),
        ),
        title: Image.network(
          '${ApiConfig.baseUrl}/public/logo/logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        titleSpacing: 10.0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              _showSnackBar(context, 'Notifications tapped!');
              Navigator.pushNamed(context, '/mobile_notifications');
            },
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              _showSnackBar(context, 'Navigating to Profile...');
              Navigator.pushNamed(context, '/mobile_profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          setState(() {
            _quickStatsFuture = _fetchQuickStats();
          });
          return _quickStatsFuture.then((value) => value);
        },
        child: SingleChildScrollView(
          child: _widgetOptions.elementAt(_selectedIndex),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category), // Products relevant to engineer
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment), // Reports relevant to engineer
            label: 'Reports',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF336EE5),
        onTap: _onItemTapped,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
