import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding
import 'dart:async'; // Import for TimeoutException
import 'dart:io'; // Import for SocketException

import '../../../models/user_model.dart';
import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

class MobileSettingsScreen extends StatefulWidget {
  const MobileSettingsScreen({super.key});

  @override
  _MobileSettingsScreenState createState() => _MobileSettingsScreenState();
}

class _MobileSettingsScreenState extends State<MobileSettingsScreen> {
  int _selectedIndex = 5;
  User? user;
  bool isLoading = true;

  Map<String, dynamic> _quickStatsData = {
    'totalUsers': 'N/A',
    'totalReports': 'N/A',
    'solvedReports': 'N/A',
    'unsolvedReports': 'N/A',
    'totalProducts': 'N/A',
    'totalMaintenance': 'N/A',
    'customerProducts': 'N/A',
    'configWarningTime': 'N/A', // Keep this in data even if not displayed
  };
  bool _quickStatsLoading = true;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    // Initialize _widgetOptions with all 6 corresponding contents
    _widgetOptions = <Widget>[
      _buildHomeContent(), // Index 0: Home
      _buildPlaceholderContent(
          'Users Management content coming soon!'), // Index 1: Users
      _buildPlaceholderContent(
          'Products content coming soon!'), // Index 2: Products
      _buildPlaceholderContent(
          'Reports tab content coming soon!'), // Index 3: Reports
      _buildPlaceholderContent(
          'Maintenance logs and schedules coming soon!'), // Index 4: Maintenance
      _buildSettingContent(), // Index 5: Settings
    ];
    _fetchQuickStats();
  }

  Future<void> _loadUserData() async {
    try {
      user = await SharedPrefs.getUser();
      if (user == null) {
        throw Exception('User data not found');
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Update snackbar messages for each specific tab
    switch (index) {
      case 0:
        // When Home tab is selected, re-fetch quick stats to ensure data is fresh
        _fetchQuickStats();
        break;
      case 1:
        _showSnackBar(context, 'Users tab selected!');
        break;
      case 2:
        _showSnackBar(context, 'Products tab selected!');
        break;
      case 3:
        _showSnackBar(context, 'Reports tab selected!');
        break;
      case 4:
        _showSnackBar(context, 'Maintenance tab selected!');
        break;
      case 5:
        _showSnackBar(context, 'Settings tab selected!');
        break;
    }
  }

  Future<void> _logout(BuildContext context) async {
    await SharedPrefs.clearAll(); // Clear user data and token
    // Navigate back to the login screen, removing all previous routes
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    _showSnackBar(context, 'Logged out successfully!', color: Colors.green);
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

  Future<void> _fetchQuickStats() async {
    setState(() {
      _quickStatsLoading = true; // Set loading state to true
      // No longer explicitly clearing _quickStatsData to prevent "N/A" flicker
    });

    try {
      final String? token =
          await SharedPrefs.getToken(); // Retrieve authentication token
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        setState(() {
          _quickStatsLoading = false;
        });
        return;
      }

      //print(
      //  'Attempting to fetch quick stats from: ${ApiConfig.baseUrl}/quickstats/admin');

      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/quickstats/admin'), // Corrected endpoint based on backend routing
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer $token', // Add Authorization header for authenticated requests
        },
      ).timeout(
        const Duration(seconds: 5), // Reduced timeout to 5 seconds
        onTimeout: () {
          throw TimeoutException(
              'Request timeout - Server not responding for quick stats');
        },
      );

      //print('Quick Stats Response status: ${response.statusCode}');
      // print('Quick Stats Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is Map<String, dynamic>) {
          setState(() {
            _quickStatsData = data['data']; // Update quick stats data
          });
        } else {
          // Handle cases where API returns success: false or data in unexpected format
          _showSnackBar(
              context,
              data['message'] ??
                  'Failed to load quick stats. Invalid data format.',
              color: Colors.red);
          // Only update relevant part, not entire map to 'N/A'
        }
      } else {
        // Handle non-200 status codes
        final errorData = json.decode(response.body);
        _showSnackBar(context,
            errorData['message'] ?? 'Failed to load quick stats. Server error.',
            color: Colors.red);
        // Only update relevant part, not entire map to 'N/A'
      }
    } on SocketException catch (e) {
      print('SocketException (Quick Stats): $e');
      _showSnackBar(context,
          'Network error while fetching quick stats. Check your internet connection.',
          color: Colors.red);
      // Only update relevant part, not entire map to 'N/A'
    } on TimeoutException catch (e) {
      print('TimeoutException (Quick Stats): $e');
      _showSnackBar(
          context, 'Quick stats request timed out. Server is not responding.',
          color: Colors.red);
      // Only update relevant part, not entire map to 'N/A'
    } on FormatException catch (e) {
      print('FormatException (Quick Stats): $e');
      _showSnackBar(
          context, 'Invalid response format for quick stats from server.',
          color: Colors.red);
      // Only update relevant part, not entire map to 'N/A'
    } catch (e) {
      print('General Exception (Quick Stats): $e');
      _showSnackBar(context,
          'An unexpected error occurred while fetching quick stats: ${e.toString()}',
          color: Colors.red);
      // Only update relevant part, not entire map to 'N/A'
    } finally {
      setState(() {
        _quickStatsLoading =
            false; // Always set loading to false after request completes
      });
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
          onTap: onTap, // Call the provided onTap function when tapped
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

  Widget _buildStatCard(
      BuildContext context, String title, String value, IconData icon) {
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
                overflow:
                    TextOverflow.ellipsis, // Add ellipsis if title is too long
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                // Quick Stats cards using Wrap, always rendered
                Wrap(
                  spacing: 10.0, // Horizontal spacing between cards
                  runSpacing: 10.0, // Vertical spacing between rows of cards
                  children: [
                    _buildStatCard(
                        context,
                        'Total Users',
                        _quickStatsData['totalUsers']?.toString() ?? 'N/A',
                        Icons.people_alt),
                    _buildStatCard(
                        context,
                        'Total Reports',
                        _quickStatsData['totalReports']?.toString() ?? 'N/A',
                        Icons.assignment),
                    _buildStatCard(
                        context,
                        'Solved Reports',
                        _quickStatsData['solvedReports']?.toString() ?? 'N/A',
                        Icons.check_circle_outline),
                    _buildStatCard(
                        context,
                        'Unsolved Reports',
                        _quickStatsData['unsolvedReports']?.toString() ?? 'N/A',
                        Icons.pending_actions),
                    _buildStatCard(
                        context,
                        'Total Products',
                        _quickStatsData['totalProducts']?.toString() ?? 'N/A',
                        Icons.category),
                    _buildStatCard(
                        context,
                        'Total Maintenance',
                        _quickStatsData['totalMaintenance']?.toString() ??
                            'N/A',
                        Icons.build),
                    _buildStatCard(
                        context,
                        'Customer Products',
                        _quickStatsData['customerProducts']?.toString() ??
                            'N/A',
                        Icons.shopping_bag),
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
                    _buildSettingCard(
                      context,
                      'Country Settings',
                      Icons.public,
                      () {
                        // Example navigation for Terms & Conditions
                        Navigator.of(context)
                            .pushNamed('/mobile_settings/country');
                      },
                    ),
                    _buildSettingCard(
                      context,
                      'Warning Time Settings',
                      Icons.warning,
                      () {
                        // Example navigation for Terms & Conditions
                        Navigator.of(context)
                            .pushNamed('/mobile_settings/warning');
                      },
                    ),
                    _buildSettingCard(
                      context,
                      'Terms & Conditions',
                      Icons.policy,
                      () {
                        // Example navigation for Terms & Conditions
                        Navigator.of(context)
                            .pushNamed('/mobile_settings/policy');
                      },
                    ),
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
        title: Image.asset(
          'images/logo.png', // Path to your logo image, assuming logo.png from previous context
          height: 40, // Adjust height as needed
          fit: BoxFit.contain, // Ensures the entire logo is visible
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
        onRefresh: _fetchQuickStats, // Call _fetchQuickStats when pulled down
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
            icon: Icon(Icons.build), // Using build for maintenance
            label: 'Maintenance',
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
