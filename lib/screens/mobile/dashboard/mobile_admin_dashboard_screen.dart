import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../models/user_model.dart';
import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

class MobileAdminDashboardScreen extends StatefulWidget {
  const MobileAdminDashboardScreen({super.key});

  @override
  _MobileAdminDashboardScreenState createState() =>
      _MobileAdminDashboardScreenState();
}

class _MobileAdminDashboardScreenState
    extends State<MobileAdminDashboardScreen> {
  int _selectedIndex = 0;
  User? _userData; // New state variable to hold user data
  bool _quickStatsLoading = true;

  Map<String, dynamic> _quickStatsData = {}; // Initialize as an empty map
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    // Initialize _widgetOptions with all 6 corresponding contents
    _widgetOptions = <Widget>[
      _buildHomeContent(), // Index 0: Home
      _buildUsersContent(),
      _buildProductsContent(), // Index 2: Products
      _buildSettingContent(), // Index 3: Settings
    ];
    _initializeData(); // Fetch user data and quick stats once
  }

  // A new method to handle all initial data fetching
  Future<void> _initializeData() async {
    final user = await SharedPrefs.getUser();
    setState(() {
      _userData = user;
    });
    if (_userData != null) {
      _fetchQuickStats(); // Only fetch stats if user is logged in
    }
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

  Future<void> _logout(BuildContext context) async {
    await SharedPrefs.clearAll();
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    _showSnackBar(context, 'Logged out successfully!', color: Colors.green);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        _fetchQuickStats(); // Re-fetch on home tab tap
        break;
      case 1:
        _showSnackBar(context, 'Users tab selected!');
        break;
      case 2:
        _showSnackBar(context, 'Products tab selected!');
        break;
      case 3:
        _showSnackBar(context, 'Settings tab selected!');
        break;
    }
  }

  Future<void> _fetchQuickStats() async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    setState(() {
      _quickStatsLoading = true;
    });

    try {
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
              'Quick stats request timed out. Server not responding.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is Map<String, dynamic>) {
          setState(() {
            _quickStatsData = data['data'];
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
    } on SocketException {
      _showSnackBar(context, 'Network error. Check your internet connection.',
          color: Colors.red);
    } on TimeoutException {
      _showSnackBar(
          context, 'Quick stats request timed out. Server not responding.',
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
          _quickStatsLoading = false;
        });
      }
    }
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, VoidCallback onTap) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = (screenWidth - 50.0) / 2;

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

  Widget _buildHomeContent() {
    if (_userData == null) {
      // Show a loading spinner or login message if user data is not yet available
      return const Center(child: CircularProgressIndicator());
    }

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
                    'Welcome, ${_userData!.fullname}!',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 13, 13, 14)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'It\'s $formattedTime on $formattedDate in Singapore.',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                'Quick Stats',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _quickStatsLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Wrap(
                  spacing: 10.0,
                  runSpacing: 10.0,
                  children: [
                    _buildStatCard(
                        context,
                        'Total Users',
                        _quickStatsData['totalUsers']?.toString() ?? 'N/A',
                        Icons.people_alt, () {
                      Navigator.pushNamed(context, '/mobile_users');
                    }),
                    _buildStatCard(
                        context,
                        'Total Reports',
                        _quickStatsData['totalReports']?.toString() ?? 'N/A',
                        Icons.assignment, () {
                      Navigator.pushNamed(context, '/mobile_reports');
                    }),
                    _buildStatCard(
                        context,
                        'Solved Reports',
                        _quickStatsData['solvedReports']?.toString() ?? 'N/A',
                        Icons.check_circle_outline, () {
                      Navigator.pushNamed(
                          context, '/mobile_admin_solved_reports');
                    }),
                    _buildStatCard(
                        context,
                        'Unsolved Reports',
                        _quickStatsData['unsolvedReports']?.toString() ?? 'N/A',
                        Icons.pending_actions, () {
                      Navigator.pushNamed(
                          context, '/mobile_admin_unsolved_reports');
                    }),
                    _buildStatCard(
                        context,
                        'Total Products',
                        _quickStatsData['totalProducts']?.toString() ?? 'N/A',
                        Icons.category, () {
                      Navigator.pushNamed(context, '/mobile_products');
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
                        'Customer Products',
                        _quickStatsData['customerProducts']?.toString() ??
                            'N/A',
                        Icons.shopping_bag, () {
                      Navigator.pushNamed(context, '/mobile_assigned_products');
                    }),
                  ],
                ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUsersContent() {
    if (_userData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Users Management',
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
              _buildSettingCard(context, 'Users', Icons.people, () {
                Navigator.pushNamed(context, '/mobile_users');
              }),
              _buildSettingCard(
                  context, 'Assign Engineers', Icons.support_agent, () {
                Navigator.pushNamed(context, '/mobile_support_team');
              }),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProductsContent() {
    if (_userData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            spacing: 10.0,
            runSpacing: 10.0,
            children: [
              _buildSettingCard(context, 'Products', Icons.category, () {
                Navigator.pushNamed(context, '/mobile_products');
              }),
              _buildSettingCard(
                  context, 'Assigned Products', Icons.shopping_bag, () {
                Navigator.pushNamed(context, '/mobile_assigned_products');
              }),
              _buildSettingCard(context, 'Maintenance Products', Icons.build,
                  () {
                Navigator.pushNamed(context, '/mobile_maintenance');
              }),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingContent() {
    if (_userData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'General Settings',
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
              _buildSettingCard(context, 'Country Settings', Icons.public, () {
                Navigator.pushNamed(context, '/mobile_settings/country');
              }),
              _buildSettingCard(context, 'Warning Time', Icons.warning, () {
                Navigator.pushNamed(context, '/mobile_settings/warning');
              }),
              _buildSettingCard(context, 'Terms & Conditions', Icons.policy,
                  () {
                Navigator.pushNamed(context, '/mobile_settings/policy');
              }),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingCard(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = (screenWidth - 50.0) / 2;

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
              ],
            ),
          ),
        ),
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
            icon: Icon(Icons.people_alt),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
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
