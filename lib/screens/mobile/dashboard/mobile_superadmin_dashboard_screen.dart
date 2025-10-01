// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding
import 'dart:async'; // Import for TimeoutException
import 'dart:io'; // Import for SocketException

import '../../../models/user_model.dart';
import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart'; // Ensure ApiConfig is correctly imported

class MobileSuperAdminDashboardScreen extends StatefulWidget {
  const MobileSuperAdminDashboardScreen({super.key});

  @override
  _MobileSuperAdminDashboardScreenState createState() =>
      _MobileSuperAdminDashboardScreenState();
}

class _MobileSuperAdminDashboardScreenState
    extends State<MobileSuperAdminDashboardScreen> {
  int _selectedIndex = 0; // State to manage the selected tab index

  // Use a Future variable to hold the quick stats data
  late Future<Map<String, dynamic>> _quickStatsFuture;

  // List of widgets for each tab in the BottomNavigationBar
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    // Initialize the future when the widget is first created
    _quickStatsFuture = _fetchQuickStats();
    // Initialize _widgetOptions with all 6 corresponding contents
    _widgetOptions = <Widget>[
      _buildHomeContent(), // Index 0: Home
      _buildUsersContent(),
      _buildProductsContent(), // Index 2: Products
      _buildReportsContent(), // Index 3: Reports
      _buildSettingContent(), // Index 4: Settings
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
      case 0:
        // Re-fetch quick stats on refresh for the home screen
        _quickStatsFuture = _fetchQuickStats();
        _showSnackBar(context, 'Home tab selected!');
        break;
      case 1:
        _showSnackBar(context, 'Users tab selected!');
        break;
      case 2:
        _showSnackBar(context, 'Products tab selected!');
        break;
      case 3:
        Navigator.pushNamed(context, '/mobile_reports');
        _showSnackBar(context, 'Reports tab selected!');
        break;
      case 4:
        _showSnackBar(context, 'Settings tab selected!');
        break;
    }
  }

  /// Fetches quick statistics data from the backend API.
  /// Returns a Future<Map<String, dynamic>>
  Future<Map<String, dynamic>> _fetchQuickStats() async {
    try {
      final String? token = await SharedPrefs.getToken();

      // Retrieve authentication token
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token missing. Please log in again.');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/quickstats/admin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 5),
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

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, VoidCallback onTap) {
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

  // Helper method to build the main content of the Home dashboard,
  // including welcome message, date, and Singapore time, and quick stats.
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
              child: Text(
                  'Please log in to access the dashboard.')); // More descriptive message
        } else {
          final user = snapshot.data!;
          // Calculate Singapore time (UTC+8)
          final DateTime nowUtc = DateTime.now().toUtc();
          final DateTime singaporeTime = nowUtc.add(const Duration(hours: 8));

          // Format date and time manually (e.g., "DD/MM/YYYY HH:MM")
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
                // Welcome text and date/time inside a Card
                Card(
                  margin: const EdgeInsets.only(
                      bottom: 20.0), // Margin below the card
                  elevation:
                      6, // Increased elevation for a more pronounced shadow
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(15), // More rounded corners
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(20.0), // Padding inside the card
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
                const SizedBox(height: 20), // Spacing after welcome card
                const Row(
                  // Removed the settings IconButton
                  mainAxisAlignment: MainAxisAlignment
                      .spaceBetween, // Align text left, icon right
                  children: [
                    Text(
                      'Quick Stats',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    // The IconButton for settings has been removed from here
                  ],
                ),
                const SizedBox(height: 10),
                // Quick Stats cards using FutureBuilder
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
                        spacing: 10.0, // Horizontal spacing between cards
                        runSpacing:
                            10.0, // Vertical spacing between rows of cards
                        children: [
                          _buildStatCard(
                              context,
                              'Total Users',
                              quickStatsData['totalUsers']?.toString() ?? 'N/A',
                              Icons.people_alt, () {
                            Navigator.pushNamed(context, '/mobile_users');
                          }),
                          _buildStatCard(
                              context,
                              'Total Reports',
                              quickStatsData['totalReports']?.toString() ??
                                  'N/A',
                              Icons.assignment, () {
                            Navigator.pushNamed(context, '/mobile_reports');
                          }),
                          _buildStatCard(
                              context,
                              'Solved Reports',
                              quickStatsData['solvedReports']?.toString() ??
                                  'N/A',
                              Icons.check_circle_outline, () {
                            Navigator.pushNamed(
                                context, '/mobile_admin_solved_reports');
                          }),
                          _buildStatCard(
                              context,
                              'Unsolved Reports',
                              quickStatsData['unsolvedReports']?.toString() ??
                                  'N/A',
                              Icons.pending_actions, () {
                            Navigator.pushNamed(
                                context, '/mobile_admin_unsolved_reports');
                          }),
                          _buildStatCard(
                              context,
                              'Total Products',
                              quickStatsData['totalProducts']?.toString() ??
                                  'N/A',
                              Icons.category, () {
                            Navigator.pushNamed(context, '/mobile_products');
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
                const SizedBox(height: 20), // Spacing at the bottom
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildSettingContent() {
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
          // Calculate Singapore time (UTC+8)
          final DateTime nowUtc = DateTime.now().toUtc();
          final DateTime singaporeTime = nowUtc.add(const Duration(hours: 8));

          // Format date and time manually (e.g., "DD/MM/YYYY HH:MM")
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
                  // Removed the settings IconButton
                  mainAxisAlignment: MainAxisAlignment
                      .spaceBetween, // Align text left, icon right
                  children: [
                    Text(
                      'General Settings',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    // The IconButton for settings has been removed from here
                  ],
                ),
                const SizedBox(height: 10),
                // Quick Stats cards using Wrap, always rendered
                Wrap(
                  spacing: 10.0, // Horizontal spacing between cards
                  runSpacing: 10.0, // Vertical spacing between rows of cards
                  children: [
                    _buildSettingCard(context, 'Country Settings', Icons.public,
                        () {
                      Navigator.pushNamed(context, '/mobile_settings/country');
                    }),
                    _buildSettingCard(context, 'Warning Time', Icons.warning,
                        () {
                      Navigator.pushNamed(context, '/mobile_settings/warning');
                    }),
                    _buildSettingCard(
                        context, 'Terms & Conditions', Icons.policy, () {
                      Navigator.pushNamed(context, '/mobile_settings/policy');
                    }),
                    // The 'Config Warning Time' stat card has been removed as per previous request
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

  Widget _buildUsersContent() {
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
          // Calculate Singapore time (UTC+8)
          final DateTime nowUtc = DateTime.now().toUtc();
          final DateTime singaporeTime = nowUtc.add(const Duration(hours: 8));

          // Format date and time manually (e.g., "DD/MM/YYYY HH:MM")
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
                  // Removed the settings IconButton
                  mainAxisAlignment: MainAxisAlignment
                      .spaceBetween, // Align text left, icon right
                  children: [
                    Text(
                      'Users Management',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    // The IconButton for settings has been removed from here
                  ],
                ),
                const SizedBox(height: 10),
                // Quick Stats cards using Wrap, always rendered
                Wrap(
                  spacing: 10.0, // Horizontal spacing between cards
                  runSpacing: 10.0, // Vertical spacing between rows of cards
                  children: [
                    _buildSettingCard(context, 'Users', Icons.people, () {
                      Navigator.pushNamed(context, '/mobile_users');
                    }),
                    _buildSettingCard(
                        context, 'Assign Engineers', Icons.support_agent, () {
                      Navigator.pushNamed(context, '/mobile_support_team');
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
          // Calculate Singapore time (UTC+8)
          final DateTime nowUtc = DateTime.now().toUtc();
          final DateTime singaporeTime = nowUtc.add(const Duration(hours: 8));

          // Format date and time manually (e.g., "DD/MM/YYYY HH:MM")
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
                  // Removed the settings IconButton
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
                    // The IconButton for settings has been removed from here
                  ],
                ),
                const SizedBox(height: 10),
                // Quick Stats cards using Wrap, always rendered
                Wrap(
                  spacing: 10.0, // Horizontal spacing between cards
                  runSpacing: 10.0, // Vertical spacing between rows of cards
                  children: [
                    _buildSettingCard(context, 'Products', Icons.category, () {
                      Navigator.pushNamed(context, '/mobile_products');
                    }),
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
          // Calculate Singapore time (UTC+8)
          final DateTime nowUtc = DateTime.now().toUtc();
          final DateTime singaporeTime = nowUtc.add(const Duration(hours: 8));

          // Format date and time manually (e.g., "DD/MM/YYYY HH:MM")
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
                  // Removed the settings IconButton
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
                    // The IconButton for settings has been removed from here
                  ],
                ),
                const SizedBox(height: 10),
                // Quick Stats cards using Wrap, always rendered
                Wrap(
                  spacing: 10.0, // Horizontal spacing between cards
                  runSpacing: 10.0, // Vertical spacing between rows of cards
                  children: [
                    _buildSettingCard(
                        context, 'Total Reports', Icons.assignment, () {
                      Navigator.pushNamed(context, '/mobile_reports');
                    }),
                    _buildSettingCard(
                        context, 'Solved Reports', Icons.check_circle_outline,
                        () {
                      Navigator.pushNamed(
                          context, '/mobile_admin_solved_reports');
                    }),
                    _buildSettingCard(
                        context, 'UnSolved Reports', Icons.pending_actions, () {
                      Navigator.pushNamed(
                          context, '/mobile_admin_unsolved_reports');
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
        // Set a custom blue background color for the AppBar
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(
                0xFF336EE5), // Custom blue color for the AppBar background
          ),
        ),
        // Set the title as a logo image, aligned to the left
        title: Image.network(
          '${ApiConfig.baseUrl}/public/logo/logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        // Add a small titleSpacing to push the logo slightly to the right from the very edge
        titleSpacing: 10.0,
        // No back button needed if this is a main dashboard.
        automaticallyImplyLeading: false,
        actions: [
          // Notifications Icon
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              _showSnackBar(context, 'Notifications tapped!');
              Navigator.pushNamed(context, '/mobile_notifications');
              // Implement navigation to notifications screen or show a notification list
            },
          ),
          // Profile Icon
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              _showSnackBar(context, 'Navigating to Profile...');
              // Implement navigation to user profile screen
              Navigator.pushNamed(context, '/mobile_profile');
            },
          ),

          // Logout Icon
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context), // Call the logout method
          ),
        ],
      ),
      body: RefreshIndicator(
        // Added RefreshIndicator here
        onRefresh: () async {
          // Re-fetch the data when the user pulls down to refresh
          setState(() {
            _quickStatsFuture = _fetchQuickStats();
          });
        },
        child: SingleChildScrollView(
          child: _widgetOptions.elementAt(
              _selectedIndex), // Display content based on selected index
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt), // Using people_alt for users
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category), // Using category for products
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings), // Using settings for settings
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex, // Current selected item
        selectedItemColor:
            const Color(0xFF336EE5), // Color for the selected item
        onTap: _onItemTapped, // Callback when an item is tapped
        unselectedItemColor: Colors.grey, // Color for unselected items
        backgroundColor: Colors.white, // Background color of the navigation bar
        type: BottomNavigationBarType.fixed, // Ensures all labels are shown
      ),
    );
  }
}
