import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemChrome
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io'; // For SocketException, TimeoutException

// No dart:html import here
// Still needed for conditional logic

// Assuming these utility and model classes exist at these paths
import '../../../utils/api_config.dart';
import '../../../utils/device_utils.dart'; // For ResponsiveBuilder

class WebForgotPasswordScreen extends StatefulWidget {
  const WebForgotPasswordScreen({super.key});

  @override
  _WebForgotPasswordScreenState createState() =>
      _WebForgotPasswordScreenState();
}

class _WebForgotPasswordScreenState extends State<WebForgotPasswordScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false; // To show success message

  // Animation controllers, similar to WebLoginScreen
  late AnimationController _animationController;
  late AnimationController _formAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _formFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    // _setWebPageTitle(); // Removed as it relied on dart:html
    _startAnimations();
  }

  // Initialize animations
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _formAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _formFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _formAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  // Start animations
  void _startAnimations() async {
    _animationController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _formAnimationController.forward();
  }

  // _setWebPageTitle() method removed as it directly uses dart:html.
  // For web, the title is usually set in web/index.html or via MaterialApp title.

  @override
  void dispose() {
    _animationController.dispose();
    _formAnimationController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSuccess = false;
    });

    try {
      final response = await http
          .post(
        Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': _emailController.text.trim()}),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Server not responding');
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // If API returns 200, it might still have an error message in the body
        if (data['message'] != null &&
            data['message'].contains('sent to your email')) {
          _showSuccessSnackBar(data['message']);
          setState(() {
            _isSuccess = true;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ??
                'Failed to send temporary password: Unknown response.';
          });
          _showErrorSnackBar(_errorMessage!);
        }
      } else {
        setState(() {
          _errorMessage = data['message'] ??
              'Failed to send temporary password. Please try again.';
        });
        _showErrorSnackBar(_errorMessage!);
      }
    } on SocketException {
      setState(() {
        _errorMessage = 'No internet connection. Please check your network.';
      });
      _showErrorSnackBar(_errorMessage!);
    } on TimeoutException {
      setState(() {
        _errorMessage = 'Request timed out. Server might be slow to respond.';
      });
      _showErrorSnackBar(_errorMessage!);
    } on FormatException {
      setState(() {
        _errorMessage = 'Invalid response format from server.';
      });
      _showErrorSnackBar(_errorMessage!);
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
      _showErrorSnackBar(_errorMessage!);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // The core Forgot Password form
  Widget _buildForgotPasswordForm() {
    return FadeTransition(
      opacity: _formFadeAnimation,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header for the form

            const Text(
              'Reset Your Password',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter your email address to receive new update password.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              cursorColor: Colors.blue[600],
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter your registered email',
                labelStyle: TextStyle(color: Colors.grey[700]),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.email, color: Colors.blue[600]),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.blue[200]!,
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.blue[600]!,
                    width: 2.0,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.red,
                    width: 1.0,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.red,
                    width: 2.0,
                  ),
                ),
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 30),

            // Send Reset Link Button
            ElevatedButton(
              onPressed: _isLoading ? null : _sendResetLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF336EE5),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
                shadowColor: Colors.black.withOpacity(0.2),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Send Temporary Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // Back to Login Link
            TextButton(
              onPressed: () {
                Navigator.pop(
                    context); // Go back to the previous screen (Login)
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[700],
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: const Text('Back to Login'),
            ),

            // Success message (only shown on success)
            if (_isSuccess)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  'A password reset link has been sent to your email. Please check your inbox.',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Header for marketing panel on desktop
  Widget _buildMarketingHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('images/logo.png',
              height: 120, width: 180, fit: BoxFit.contain),
          const SizedBox(height: 30),
          const Text(
            'Need Help Logging In?',
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(2, 2),
                  blurRadius: 4,
                  color: Color.fromRGBO(0, 0, 0, 0.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'We understand. Let us help you regain access to your account quickly and securely.',
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          // You can add more specific features/steps here if needed
          _buildFeaturesList(), // Reusing for consistent look
        ],
      ),
    );
  }

  // Features list (reused from login screen for consistency)
  Widget _buildFeaturesList() {
    final features = [
      'Simple password reset',
      'Secure email verification',
      'Dedicated support',
      '24/7 assistance',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features
          .map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    feature,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // Desktop layout with two columns
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left Panel - Branding/Marketing
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(60),
            child: _buildMarketingHeader(),
          ),
        ),
        // Right Panel - Forgot Password Form
        Expanded(
          flex: 2,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              margin: const EdgeInsets.all(40),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 5,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: _buildForgotPasswordForm(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Tablet layout (single column, centered form)
  Widget _buildTabletLayout() {
    return Center(
      child: Container(
        width: 600,
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 5,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildForgotPasswordForm(), // Form directly
            ],
          ),
        ),
      ),
    );
  }

  // Mobile layout (single column, centered form with scroll)
  Widget _buildMobileLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 20),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 5,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildForgotPasswordForm(), // Form directly
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 51, 110, 229),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF336EE5), Color(0xFF517DD8)],
          ),
        ),
        child: ResponsiveBuilder(
          builder: (context, deviceType) {
            switch (deviceType) {
              case DeviceType.desktop:
                return _buildDesktopLayout();
              case DeviceType.tablet:
                return _buildTabletLayout();
              case DeviceType.mobile:
              default:
                return _buildMobileLayout();
            }
          },
        ),
      ),
    );
  }
}
