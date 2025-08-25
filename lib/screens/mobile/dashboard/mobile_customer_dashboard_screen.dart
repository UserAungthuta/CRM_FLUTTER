// lib/screens/customer/mobile_customer_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding
import 'dart:async'; // Import for TimeoutException
import 'dart:io'; // Import for SocketException

import '../../../models/user_model.dart';
import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart'; // Ensure ApiConfig is correctly imported

class MobileCustomerDashboardScreen extends StatefulWidget {
  const MobileCustomerDashboardScreen({super.key});

  @override
  _MobileCustomerDashboardScreenState createState() =>
      _MobileCustomerDashboardScreenState();
}

class _MobileCustomerDashboardScreenState
    extends State<MobileCustomerDashboardScreen> {
  int _selectedIndex = 0; // State to manage the selected tab index

  // State variables for Quick Stats data
  // Initialize with default values so UI can render immediately
  Map<String, dynamic> _quickStatsData = {
    'myReports': 'N/A',
    'activeProducts': 'N/A',
    'serviceRequests': 'N/A',
  };
  bool _quickStatsLoading = true; // Still used internally for fetch logic

  // List of widgets for each tab in the BottomNavigationBar
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      _buildHomeContent(), // Index 0: Home (Customer Quick Stats)
      _buildHomeContent(), // Index 1: Customer's Products (Assigned Products)
      _buildHomeContent(), // Index 4: Profile
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
      case 1: // Products (Assigned Products for customer)
        Navigator.pushNamed(context,
            '/mobile_assigned_products'); // Navigate to assigned products
        break;
      case 2: // Reports
        Navigator.pushNamed(context,
            '/mobile_customer_reports'); // Navigate to customer reports
        break;
      case 3: // Settings
        Navigator.pushNamed(context,
            '/mobile_customer_settings'); // Navigate to customer settings
        break;
      case 4: // Profile
        Navigator.pushNamed(context, '/mobile_profile'); // Navigate to profile
        break;
    }
  }

  /// Fetches quick statistics data from the backend API for a customer.
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
            '${ApiConfig.baseUrl}/quickstats/customer'), // Customer-specific endpoint
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

  // Helper method to build the main content of the Home dashboard for customer,
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
                        'Total Reports',
                        _quickStatsData['myReports']?.toString() ?? 'N/A',
                        Icons.assignment, () {
                      Navigator.pushNamed(context, '/mobile_customer_reports');
                    }),
                    _buildStatCard(
                        context,
                        'My Products',
                        _quickStatsData['activeProducts']?.toString() ?? 'N/A',
                        Icons.category, () {
                      Navigator.pushNamed(context, '/mobile_assigned_products');
                    }),
                    _buildStatCard(
                        context,
                        'Total Maintenance',
                        _quickStatsData['totalMaintenance']?.toString() ??
                            'N/A',
                        Icons.build, () {
                      Navigator.pushNamed(context, '/mobile_maintenance');
                    }),
                    _buildStatCard(
                        context,
                        'Service Requests',
                        _quickStatsData['serviceRequests']?.toString() ?? 'N/A',
                        Icons.build, () {
                      // Assuming service requests are part of reports, navigate to reports or a filtered view
                      Navigator.pushNamed(
                          context, '/mobile_customer_unsolved_reports');
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

  // Placeholder for customer's products content (assigned products)
  Widget _buildProductsContent() {
    return const Center(
      child: Text(
        'Your Assigned Products will be listed here!',
        style: TextStyle(fontSize: 20, color: Colors.black54),
        textAlign: TextAlign.center,
      ),
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
            icon: Icon(Icons
                .category), // Changed from people_alt to category for products
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons
                .assignment), // Changed from bar_chart to assignment for reports
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
