// lib/screens/mobile/splash_screen.dart
import 'package:flutter/material.dart';
import '../../utils/shared_prefs.dart';
import '../../utils/api_config.dart';
// Ensure this utility is available if used elsewhere

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Ensure the splash screen is visible for at least 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    // Retrieve user data from shared preferences
    final user = await SharedPrefs.getUser();

    // Check if the widget is still mounted before attempting navigation
    if (!mounted) return;

    if (user != null) {
      // Define a map for role-based route navigation
      final Map<String, String> roleRoutes = {
        'superadmin': '/mobile_superadmin-dashboard',
        'admin': '/mobile_admin-dashboard',
        'supervisor': '/mobile_admin-dashboard',
        'engineer': '/mobile_engineer-dashboard',
        'member': '/mobile_member-dashboard',
        'champion': '/mobile_member-dashboard',
        'localcustomer': '/mobile_customer-dashboard',
        'globalcustomer': '/mobile_customer-dashboard',
      };

      // Get the route based on the user's role
      String? route = roleRoutes[user.role];

      // Navigate to the determined route or to the login screen if the role is unknown
      if (route != null) {
        Navigator.pushReplacementNamed(context, route);
      } else {
        // Unknown or unhandled role, direct to login
        Navigator.pushReplacementNamed(context, '/mobile_login');
      }
    } else {
      // User not logged in, direct to login screen
      Navigator.pushReplacementNamed(context, '/mobile_login');
    }
  }

  @override
  void dispose() {
    // Dispose the animation controller to prevent memory leaks
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(
          255, 66, 126, 230), // Light blue background for a fresh look
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255,
                            1), // Deeper blue for the icon background
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            spreadRadius: 5,
                            blurRadius: 15,
                            offset: const Offset(0, 5), // Soft shadow for depth
                          ),
                        ],
                      ),
                      child: ClipOval(
                        // Use ClipOval to ensure the image is circular
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Image.network(
                            '${ApiConfig.baseUrl}/public/logo/icon.png', // Path to your local asset image
                            fit: BoxFit.contain,
                            width: 80,
                            height: 80,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback if the asset image cannot be loaded
                              return const Icon(
                                Icons.error,
                                size: 50,
                                color: Colors.white,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30), // Spacing between icon and text
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Text(
                'Rehlko Customer Care App',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(
                      255, 246, 247, 247), // Darker blue for the main title
                ),
              ),
            ),
            const SizedBox(
                height: 10), // Spacing between main title and subtitle
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Text(
                'The Ultimate Customer Companion',
                style: TextStyle(
                    fontSize: 16,
                    color: Color.fromARGB(
                        255, 254, 255, 255)), // Matching subtitle color
              ),
            ),
            const SizedBox(height: 50), // Spacing before the progress indicator
            FadeTransition(
              opacity: _fadeAnimation,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.blue[600]!), // Blue progress indicator
              ),
            ),
          ],
        ),
      ),
    );
  }
}
