// lib/screens/admin/web_superadmin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding
import 'dart:async'; // Import for TimeoutException
import 'dart:io'; // Import for SocketException
import '../../../models/user_model.dart';
import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

class WebSuperAdminDashboardScreen extends StatefulWidget {
  const WebSuperAdminDashboardScreen({super.key});

  @override
  State<WebSuperAdminDashboardScreen> createState() =>
      _WebSuperAdminDashboardScreenState();
}

class _WebSuperAdminDashboardScreenState
    extends State<WebSuperAdminDashboardScreen> {
  // Constants for layout
  static const double _kSidebarWidth = 256.0; // Width of the persistent sidebar
  static const double _kContentHorizontalPadding =
      20.0; // Padding around main content sections
  static const double _kWrapSpacing = 16.0; // Spacing between cards in Wrap

  // State variables for Quick Stats data
  Map<String, dynamic> _quickStatsData = {
    'totalUsers': 'N/A',
    'totalReports': 'N/A',
    'solvedReports': 'N/A',
    'unsolvedReports': 'N/A',
    'totalProducts': 'N/A',
    'totalMaintenance': 'N/A',
    'customerProducts': 'N/A',
  };
  bool _quickStatsLoading = true;

  // State variables for Recent Reports data
  List<dynamic> _recentReportsData = []; // Initialized as an empty list
  bool _recentReportsLoading = true;

  // State variable for Warning Config loading
  bool _WarningConfigLoading = false;

  // Placeholder for user details (will be fetched)
  User? _currentUser;

  // Key for Scaffold to control the Drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variable to control the visibility of the persistent sidebar on large screens
  bool _isSidebarOpen = true; // Initial state: sidebar is open

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Fetch user data on init
    _fetchQuickStats(); // Fetch quick stats data on init
    _fetchRecentReports(); // Fetch recent reports on init
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

  /// Fetches quick statistics data from the backend API.
  Future<void> _fetchQuickStats() async {
    setState(() {
      _quickStatsLoading = true;
    });

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        if (mounted) {
          setState(() {
            _quickStatsLoading = false;
          });
        }
        return;
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
          throw TimeoutException('Request timeout - Server not responding.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              _quickStatsData = data['data'];
            });
          }
        } else {
          _showSnackBar(
              context, data['message'] ?? 'Failed to load quick stats.',
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
          _quickStatsLoading = false;
        });
      }
    }
  }

  Future<void> _fetchWarningConfigs() async {
    setState(() {
      _WarningConfigLoading = true;
    });

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        if (mounted) {
          setState(() {
            _recentReportsLoading = false;
            _recentReportsData = []; // Clear data if no token
          });
        }
        return;
      }

      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/warning-config/readall'); // Your reports API endpoint

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException(
              'Request timeout - Server not responding for reports.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          if (mounted) {
            setState(() {
              _recentReportsData = data['data'];
            });
          }
        } else {
          _showSnackBar(
              context,
              data['message'] ??
                  'Failed to load recent reports. Invalid data format.',
              color: Colors.red);
          if (mounted) {
            setState(() {
              _recentReportsData =
                  []; // Set to empty list if data is not as expected
            });
          }
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to load recent reports. Server error.',
            color: Colors.red);
        if (mounted) {
          setState(() {
            _recentReportsData = []; // Set to empty list on server error
          });
        }
      }
    } on SocketException {
      _showSnackBar(
          context, 'Network error. Check your internet connection for reports.',
          color: Colors.red);
      if (mounted) {
        setState(() {
          _recentReportsData = []; // Set to empty list on network error
        });
      }
    } on TimeoutException {
      _showSnackBar(context,
          'Recent reports request timed out. Server is not responding.',
          color: Colors.red);
      if (mounted) {
        setState(() {
          _recentReportsData = []; // Set to empty list on timeout
        });
      }
    } on FormatException {
      _showSnackBar(
          context, 'Invalid response format for recent reports from server.',
          color: Colors.red);
      if (mounted) {
        setState(() {
          _recentReportsData = []; // Set to empty list on format error
        });
      }
    } catch (e) {
      _showSnackBar(context,
          'An unexpected error occurred while fetching recent reports: ${e.toString()}',
          color: Colors.red);
      if (mounted) {
        setState(() {
          _recentReportsData = []; // Set to empty list on general error
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _recentReportsLoading = false;
        });
      }
    }
  }

  /// Fetches recent reports data from the backend API.
  Future<void> _fetchRecentReports() async {
    setState(() {
      _recentReportsLoading = true;
    });

    try {
      final String? token = await SharedPrefs.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        if (mounted) {
          setState(() {
            _recentReportsLoading = false;
            _recentReportsData = []; // Clear data if no token
          });
        }
        return;
      }

      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/reports/recents')
          .replace(queryParameters: {
        '_limit': '5', // This limits the results to 5
        '_sort':
            'modified_datetime:desc', // This orders by modified_datetime in descending order
      }); // Your reports API endpoint

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException(
              'Request timeout - Server not responding for reports.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          if (mounted) {
            setState(() {
              _recentReportsData = data['data'];
            });
          }
        } else {
          _showSnackBar(
              context,
              data['message'] ??
                  'Failed to load recent reports. Invalid data format.',
              color: Colors.red);
          if (mounted) {
            setState(() {
              _recentReportsData =
                  []; // Set to empty list if data is not as expected
            });
          }
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to load recent reports. Server error.',
            color: Colors.red);
        if (mounted) {
          setState(() {
            _recentReportsData = []; // Set to empty list on server error
          });
        }
      }
    } on SocketException {
      _showSnackBar(
          context, 'Network error. Check your internet connection for reports.',
          color: Colors.red);
      if (mounted) {
        setState(() {
          _recentReportsData = []; // Set to empty list on network error
        });
      }
    } on TimeoutException {
      _showSnackBar(context,
          'Recent reports request timed out. Server is not responding.',
          color: Colors.red);
      if (mounted) {
        setState(() {
          _recentReportsData = []; // Set to empty list on timeout
        });
      }
    } on FormatException {
      _showSnackBar(
          context, 'Invalid response format for recent reports from server.',
          color: Colors.red);
      if (mounted) {
        setState(() {
          _recentReportsData = []; // Set to empty list on format error
        });
      }
    } catch (e) {
      _showSnackBar(context,
          'An unexpected error occurred while fetching recent reports: ${e.toString()}',
          color: Colors.red);
      if (mounted) {
        setState(() {
          _recentReportsData = []; // Set to empty list on general error
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _recentReportsLoading = false;
        });
      }
    }
  }

  /// Calculates the appropriate width for each stat card based on screen size.
  double _calculateCardWidth(bool isLargeScreen, double screenWidth) {
    // Calculate available content width:
    // Total screen width
    // MINUS sidebar width (if present and open, i.e., on large screen)
    // MINUS total horizontal padding of the main content column
    double availableWidth = screenWidth;
    if (isLargeScreen && _isSidebarOpen) {
      availableWidth -= _kSidebarWidth;
    }
    availableWidth -= (_kContentHorizontalPadding * 2);

    int columns = isLargeScreen ? 4 : 2;
    double totalSpacing = (columns - 1) * _kWrapSpacing;
    // Ensure availableWidth is not negative or zero before division
    if (availableWidth <= 0) return 0;
    return (availableWidth - totalSpacing) / columns;
  }

  // Helper method to build a single statistic card
  Widget _buildStatCard(
      String title, String value, IconData icon, double cardWidth) {
    return SizedBox(
      width: cardWidth,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Adjusted padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 32,
                color: Colors.blueAccent, // Adjusted icon size and color
              ),
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
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Determine if it's a large screen (desktop/tablet) or small (mobile)
    final bool isLargeScreen = screenWidth > 768; // md:breakpoint in Tailwind

    // Calculate card width once for all stat cards
    final double statCardWidth =
        _calculateCardWidth(isLargeScreen, screenWidth);

    return Scaffold(
      key: _scaffoldKey, // Assign the Scaffold key for drawer control
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF336EE5), // Equivalent to bg-blue-800
          ),
        ),
        title: Image.asset(
          'images/logo.png', // Path to your logo image, assuming logo.png from previous context
          height: 40, // Adjust height as needed
          fit: BoxFit.contain, // Ensures the entire logo is visible
        ),
        // Conditionally show hamburger icon for drawer on small screens
        // or a toggle for the persistent sidebar on large screens.
        // This also ensures no default back button is present.
        leading: isLargeScreen
            ? IconButton(
                icon: Icon(_isSidebarOpen ? Icons.chevron_left : Icons.menu,
                    color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSidebarOpen = !_isSidebarOpen;
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
        actions: [
          // Navigation Links for large screens in AppBar
          if (isLargeScreen) ...[
            TextButton(
              onPressed: () {
                // Navigate to Dashboard screen
                Navigator.of(context).pushNamed('/web_superadmin-dashboard');
              },
              style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: const Text('Dashboard'),
            ),
            TextButton(
              onPressed: () {
                // Navigate to Users screen
                Navigator.of(context).pushNamed('/users');
              },
              style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: const Text('Users'),
            ),
            TextButton(
              onPressed: () {
                // Navigate to Reports screen
                Navigator.of(context).pushNamed('/reports');
              },
              style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: const Text('Reports'),
            ),
            TextButton(
              onPressed: () {
                // Navigate to Products screen
                Navigator.of(context).pushNamed('/products');
              },
              style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: const Text('Products'),
            ),
            // Settings Dropdown for large screens
            PopupMenuButton<String>(
              offset: const Offset(0, 40), // Position dropdown below button
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
                // Handle navigation based on selected settings option
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
          ],
          // User Profile/Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 40), // Position dropdown below button
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Text('Profile'),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Text('Settings'),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('Logout', style: TextStyle(color: Colors.red)),
                ),
              ],
              onSelected: (String value) {
                if (value == 'logout') {
                  _logout();
                } else if (value == 'profile') {
                  // Navigate to Profile screen
                  Navigator.of(context).pushNamed('/profile');
                } else if (value == 'settings') {
                  // Navigate to Settings screen (if different from main settings)
                  Navigator.of(context).pushNamed('/web_settings');
                }
              },
              child: Row(
                children: [
                  // Replaced CircleAvatar with Icon for the profile in AppBar
                  const Icon(Icons.account_circle,
                      color: Colors.white, size: 32),
                  if (isLargeScreen)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        _currentUser?.fullname ??
                            'Admin', // Default to 'Admin' if null
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
      // Mobile Navigation Drawer
      drawer: isLargeScreen
          ? null // No drawer on large screens as sidebar is visible
          : Drawer(
              child: Container(
                color: const Color(0xFF1E293B), // Equivalent to bg-gray-800
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    DrawerHeader(
                      decoration: const BoxDecoration(
                        color: Color(0xFF1D4ED8), // Equivalent to bg-blue-800
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Replaced CircleAvatar with Icon for the profile in DrawerHeader
                          const Icon(Icons.account_circle,
                              color: Colors.white, size: 60),
                          const SizedBox(height: 10),
                          Text(
                            _currentUser?.fullname ??
                                'Admin', // Default to 'Admin' if null
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18),
                          ),
                          Text(
                            _currentUser?.email ??
                                'admin@example.com', // Default email
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    _buildDrawerItem(Icons.dashboard, 'Dashboard', () {
                      Navigator.pop(context); // Close drawer
                      Navigator.of(context)
                          .pushNamed('/web_superadmin-dashboard');
                    }),
                    _buildDrawerItem(Icons.people, 'Users', () {
                      Navigator.pop(context); // Close drawer
                      Navigator.of(context).pushNamed('/users');
                    }),
                    _buildDrawerItem(Icons.category, 'Products', () {
                      Navigator.pop(context); // Close drawer
                      Navigator.of(context).pushNamed('/products');
                    }),
                    _buildDrawerItem(Icons.bar_chart, 'Reports', () {
                      Navigator.pop(context); // Close drawer
                      Navigator.of(context).pushNamed('/reports');
                    }),
                    _buildDrawerItem(Icons.build, 'Maintenance', () {
                      Navigator.pop(context); // Close drawer
                      Navigator.of(context).pushNamed(
                          '/maintenance'); // Assuming a /maintenance route
                    }),
                    // Settings ExpansionTile for small screens
                    ExpansionTile(
                      leading: const Icon(Icons.settings, color: Colors.white),
                      title: const Text('Settings',
                          style: TextStyle(color: Colors.white)),
                      collapsedIconColor: Colors.white,
                      iconColor: Colors.white,
                      children: <Widget>[
                        _buildDrawerItem(Icons.flag, 'Country', () {
                          Navigator.pop(context); // Close drawer
                          Navigator.of(context)
                              .pushNamed('/web_settings/country');
                        }, isSubItem: true),
                        _buildDrawerItem(Icons.warning, 'Report Warning', () {
                          Navigator.pop(context); // Close drawer
                          Navigator.of(context)
                              .pushNamed('/web_settings/report_warning');
                        }, isSubItem: true),
                        _buildDrawerItem(Icons.description, 'Terms', () {
                          Navigator.pop(context); // Close drawer
                          Navigator.of(context)
                              .pushNamed('/web_settings/terms');
                        }, isSubItem: true),
                      ],
                    ),
                    const Divider(color: Colors.white54),
                    _buildDrawerItem(Icons.logout, 'Logout', () {
                      Navigator.pop(context); // Close drawer
                      _logout();
                    }, textColor: Colors.red),
                  ],
                ),
              ),
            ),
      body: Row(
        children: [
          // Persistent Sidebar for large screens, now with toggle functionality
          if (isLargeScreen)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300), // Smooth animation
              width: _isSidebarOpen ? _kSidebarWidth : 0.0, // Toggle width
              color: const Color(0xFF1E293B), // Equivalent to bg-gray-800
              padding: const EdgeInsets.all(16.0),
              child: _isSidebarOpen // Only render content if sidebar is open
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              _buildSidebarItem(Icons.dashboard, 'Dashboard',
                                  () {
                                Navigator.of(context)
                                    .pushNamed('/web_superadmin-dashboard');
                              }),
                              _buildSidebarItem(Icons.people, 'Users', () {
                                Navigator.of(context).pushNamed('/users');
                              }),
                              _buildSidebarItem(Icons.category, 'Products', () {
                                Navigator.of(context).pushNamed('/products');
                              }),
                              _buildSidebarItem(Icons.bar_chart, 'Reports', () {
                                Navigator.of(context).pushNamed('/reports');
                              }),
                              _buildSidebarItem(Icons.build, 'Maintenance', () {
                                Navigator.of(context).pushNamed('/maintenance');
                              }),
                              // Settings ExpansionTile for sidebar
                              ExpansionTile(
                                leading: const Icon(Icons.settings,
                                    color: Colors.white),
                                title: const Text('Settings',
                                    style: TextStyle(color: Colors.white)),
                                collapsedIconColor: Colors.white,
                                iconColor: Colors.white,
                                children: <Widget>[
                                  _buildSidebarItem(Icons.flag, 'Country', () {
                                    Navigator.of(context)
                                        .pushNamed('/web_settings/country');
                                  }, isSubItem: true),
                                  _buildSidebarItem(
                                      Icons.warning, 'Report Warning', () {
                                    Navigator.of(context).pushNamed(
                                        '/web_settings/report_warning');
                                  }, isSubItem: true),
                                  _buildSidebarItem(Icons.description, 'Terms',
                                      () {
                                    Navigator.of(context)
                                        .pushNamed('/web_settings/terms');
                                  }, isSubItem: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox
                      .shrink(), // Hide content when sidebar is closed
            ),
          // Main Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(
                  0), // Removed top/bottom padding here, added to specific sections
              child: Column(
                crossAxisAlignment: CrossAxisAlignment
                    .stretch, // Stretch children to fill width
                children: [
                  // Welcome Card
                  Card(
                    margin: const EdgeInsets.all(
                        20.0), // Card itself has internal padding
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(
                          20.0), // Internal padding of the card
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${_currentUser?.fullname ?? 'Admin'}!',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 13, 13, 14)),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Here’s an overview of your dashboard.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Quick Stats Section
                  Padding(
                    // Added padding specifically for Quick Stats
                    padding: const EdgeInsets.symmetric(
                        horizontal: _kContentHorizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment
                          .stretch, // Stretch children to fill width
                      children: [
                        const Text(
                          'Quick Stats',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                        const SizedBox(height: 10),
                        _quickStatsLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _quickStatsData.isEmpty
                                ? const Center(
                                    child: Text(
                                        'No quick stats data available.',
                                        style: TextStyle(color: Colors.red)))
                                : Wrap(
                                    spacing:
                                        _kWrapSpacing, // Horizontal spacing
                                    runSpacing:
                                        _kWrapSpacing, // Vertical spacing
                                    children: [
                                      _buildStatCard(
                                          'Total Users',
                                          _quickStatsData['totalUsers']
                                              .toString(),
                                          Icons.people_alt,
                                          statCardWidth),
                                      _buildStatCard(
                                          'Total Reports',
                                          _quickStatsData['totalReports']
                                              .toString(),
                                          Icons.assignment,
                                          statCardWidth),
                                      _buildStatCard(
                                          'Solved Reports',
                                          _quickStatsData['solvedReports']
                                              .toString(),
                                          Icons.check_circle_outline,
                                          statCardWidth),
                                      _buildStatCard(
                                          'Unsolved Reports',
                                          _quickStatsData['unsolvedReports']
                                              .toString(),
                                          Icons.pending_actions,
                                          statCardWidth),
                                      _buildStatCard(
                                          'Total Products',
                                          _quickStatsData['totalProducts']
                                              .toString(),
                                          Icons.category,
                                          statCardWidth),
                                      _buildStatCard(
                                          'Total Maintenance',
                                          _quickStatsData['totalMaintenance']
                                              .toString(),
                                          Icons.build,
                                          statCardWidth),
                                      _buildStatCard(
                                          'Customer Products',
                                          _quickStatsData['customerProducts']
                                              .toString(),
                                          Icons.shopping_bag,
                                          statCardWidth),
                                    ],
                                  ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Recent Reports Section
                  Padding(
                    // Added padding specifically for Recent Activities
                    padding: const EdgeInsets.symmetric(
                        horizontal: _kContentHorizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Reports', // Changed title from Recent Activities to Recent Reports
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                        const SizedBox(height: 10),
                        _recentReportsLoading
                            ? const Center(child: CircularProgressIndicator())
                            : (_recentReportsData
                                    .isEmpty) // Check for empty list
                                ? const Center(
                                    child: Text('No recent reports available.',
                                        style: TextStyle(color: Colors.red)))
                                : Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(15.0),
                                      child: Column(
                                        children: _recentReportsData
                                            .map<Widget>((report) =>
                                                _buildReportItem(report))
                                            .toList(),
                                      ),
                                    ),
                                  ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for building sidebar items
  Widget _buildSidebarItem(IconData icon, String title, VoidCallback onTap,
      {Color textColor = Colors.white, bool isSubItem = false}) {
    return ListTile(
      contentPadding:
          EdgeInsets.only(left: isSubItem ? 32.0 : 8.0), // Indent sub-items
      minLeadingWidth: 0, // Set minimum leading width to 0
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      onTap: onTap,
      selectedTileColor: const Color(0xFF2563EB), // Equivalent to blue-600
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
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

  // Helper method to build a single report item
  Widget _buildReportItem(Map<String, dynamic> report) {
    // Assuming report structure: {'report_index': 'REP001', 'problem_issue': '...', 'status': 'Open', 'created_datetime': '...'}
    IconData statusIcon;
    Color statusColor;

    switch (report['status']) {
      case 'pending':
        statusIcon = Icons.warning_amber;
        statusColor = Colors.orange;
        break;
      case 'solving':
        statusIcon = Icons.hourglass_empty;
        statusColor = Colors.orangeAccent;
        break;
      case 'checking':
        statusIcon = Icons.check_circle;
        statusColor = Colors.blue;
        break;
      case 'completed':
        statusIcon = Icons.check_circle_rounded;
        statusColor = Colors.green;
        break;
      default:
        statusIcon = Icons.info_outline;
        statusColor = Colors.grey;
    }

    return Container(
      // Added Container for margin and border
      margin: const EdgeInsets.only(
          bottom: 10.0), // Margin at the bottom of each item
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300), // Light grey border
        borderRadius:
            BorderRadius.circular(8), // Rounded corners for the border
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report ID: ${report['report_index'] ?? 'N/A'}', // Updated key
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Problem Issue: ${report['problem_issue'] ?? 'No description'}', // Updated key
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Serial No: ${report['generator_serial_number'] ?? 'No description'}', // Updated key
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Status: ${report['status'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 12, color: statusColor),
                  ),
                  Text(
                    'Created: ${report['created_datetime'] ?? 'N/A'}', // Updated key
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
