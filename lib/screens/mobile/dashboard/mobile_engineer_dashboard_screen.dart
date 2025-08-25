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

  // State variables for Quick Stats data for an Engineer
  Map<String, dynamic> _quickStatsData = {
    'totalCustomers': 'N/A',
    'totalReports': 'N/A',
    'solvedReports': 'N/A',
    'unsolvedReports': 'N/A',
    'totalMaintenance': 'N/A',
    'customerProducts': 'N/A',
  };
  bool _quickStatsLoading = true; // Still used internally for fetch logic

  // List of widgets for each tab in the BottomNavigationBar
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      _buildHomeContent(), // Index 0: Home (Engineer Quick Stats)
      _buildProductsContent(),
      _buildReportsContent(), // Index 1: Products (Assigned Products relevant to engineer)
      //_buildPlaceholderContent(
      //'Engineer Reports tab content coming soon!'), // Index 2: Reports
    ];
    _fetchQuickStats(); // Call to fetch quick stats when the widget initializes
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
  Future<void> _fetchQuickStats() async {
    setState(() {
      _quickStatsLoading = true; // Set loading state to true
    });

    try {
      final String? token =
          await SharedPrefs.getToken(); // Retrieve authentication token
      final int? userId = await SharedPrefs.getUserId(); // Retrieve user ID

      if (token == null || token.isEmpty || userId == null) {
        _showSnackBar(context,
            'Authentication token or User ID missing. Please log in again.',
            color: Colors.red);
        setState(() {
          _quickStatsLoading = false;
        });
        return;
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
          setState(() {
            _quickStatsData = data['data']; // Update quick stats data
          });
        } else {
          _showSnackBar(
              context,
              data['message'] ??
                  'Failed to load quick stats. Invalid data format.',
              color: Colors.red);
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to load quick stats. Server error.',
            color: Colors.red);
      }
    } on SocketException catch (e) {
      print('SocketException (Quick Stats): $e');
      _showSnackBar(context,
          'Network error while fetching quick stats. Check your internet connection.',
          color: Colors.red);
    } on TimeoutException catch (e) {
      print('TimeoutException (Quick Stats): $e');
      _showSnackBar(
          context, 'Quick stats request timed out. Server is not responding.',
          color: Colors.red);
    } on FormatException catch (e) {
      print('FormatException (Quick Stats): $e');
      _showSnackBar(
          context, 'Invalid response format for quick stats from server.',
          color: Colors.red);
    } catch (e) {
      print('General Exception (Quick Stats): $e');
      _showSnackBar(context,
          'An unexpected error occurred while fetching quick stats: ${e.toString()}',
          color: Colors.red);
    } finally {
      setState(() {
        _quickStatsLoading = false; // Always set loading to false
      });
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
                Wrap(
                  spacing: 10.0,
                  runSpacing: 10.0,
                  children: [
                    _buildStatCard(
                        context,
                        'Total Customers',
                        _quickStatsData['totalCustomers']?.toString() ?? 'N/A',
                        Icons.people_alt, () {
                      // No direct navigation to a 'customers' list for engineer, maybe a filtered reports list
                      _showSnackBar(context, 'Total Customers stat tapped!');
                    }),
                    _buildStatCard(
                        context,
                        'Total Reports',
                        _quickStatsData['totalReports']?.toString() ?? 'N/A',
                        Icons.assignment, () {
                      Navigator.pushNamed(context, '/mobile_engineer_reports');
                    }),
                    _buildStatCard(
                        context,
                        'Solved Reports',
                        _quickStatsData['solvedReports']?.toString() ?? 'N/A',
                        Icons.check_circle_outline, () {
                      Navigator.pushNamed(context,
                          '/mobile_engineer_solved_reports'); // Can navigate to filtered reports
                    }),
                    _buildStatCard(
                        context,
                        'Unsolved Reports',
                        _quickStatsData['unsolvedReports']?.toString() ?? 'N/A',
                        Icons.pending_actions, () {
                      Navigator.pushNamed(context,
                          '/mobile_engineer_unsolved_reports'); // Can navigate to filtered reports
                    }),
                    _buildStatCard(
                        context,
                        'Total Maintenance',
                        _quickStatsData['totalMaintenance']?.toString() ??
                            'N/A',
                        Icons.build, () {
                      Navigator.pushNamed(context,
                          '/mobile_maintenance'); // Assuming this is general maintenance
                    }),
                    _buildStatCard(
                        context,
                        'Customer Products',
                        _quickStatsData['customerProducts']?.toString() ??
                            'N/A',
                        Icons.shopping_bag, () {
                      Navigator.pushNamed(context,
                          '/mobile_assigned_products'); // Engineer can see assigned products
                    }),
                  ],
                ),
                const SizedBox(height: 20),
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

  // Placeholder for engineer's products content (assigned products)
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
        onRefresh: _fetchQuickStats,
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
