// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import '../../../models/user_model.dart';
import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('Attempting login to: ${ApiConfig.baseUrl}/auth/login');

      final response = await http
          .post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'unique': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Server not responding');
        },
      );

      final data = json.decode(response.body);

      final Map<String, String> roleRoutes = {
        'superadmin': '/mobile_superadmin-dashboard',
        'engineer': '/mobile_engineer-dashboard',
        'localcustomer': '/mobile_customer-dashboard',
        'globalcustomer': '/mobile_customer-dashboard',
      };

      if (response.statusCode == 200 && data['success'] == true) {
        //print(data['token']);
        final user = User.fromJson(data['user']);
        final String token = data['token']?.toString() ?? '';

        await SharedPrefs.saveUser(user, token);
        await SharedPrefs.saveToken(token);

        await fetchandSaveQuickStats(user.role, token);
        _showSnackBar(
          'Login successful! Welcome ${user.fullname ?? user.username}',
          Colors.green[600]!,
          Icons.check_circle,
        );

        String? route = roleRoutes[user.role];
        if (route != null) {
          Navigator.pushReplacementNamed(context, route);
        } else {
          _showSnackBar(
            'Login successful, but no dashboard found for your role: ${user.role}. Please contact support.',
            Colors.orange[600]!,
            Icons.warning_amber,
          );
        }
      } else {
        _showSnackBar(
          data['message'] ?? 'Login failed. Please try again.',
          Colors.red[600]!,
          Icons.error_outline,
        );
      }
    } on SocketException catch (e) {
      print('SocketException: $e');
      _showSnackBar(
        'Cannot connect to server. Check your internet connection.',
        Colors.red[600]!,
        Icons.wifi_off,
      );
    } on TimeoutException catch (e) {
      print('TimeoutException: $e');
      _showSnackBar(
        'Request timeout. Server is not responding.',
        Colors.red[600]!,
        Icons.timer_off,
      );
    } on FormatException catch (e) {
      print('FormatException: $e');
      _showSnackBar(
        'Invalid response from server.',
        Colors.red[600]!,
        Icons.error_outline,
      );
    } catch (e) {
      print('General Exception: $e');
      _showSnackBar(
        'An unexpected error occurred: ${e.toString()}',
        Colors.red[600]!,
        Icons.error,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> fetchandSaveQuickStats(String? userRole, String token) async {
    String? statsUrl;
    String? prefsKey;

    switch (userRole) {
      case 'superadmin':
      case 'admin':
        statsUrl = '${ApiConfig.baseUrl}/quickstats/admin';
        prefsKey = 'adminQuickStats';
        break;
      case 'engineer':
        statsUrl = '${ApiConfig.baseUrl}/quickstats/engineer';
        prefsKey = 'engineerQuickStats';
        break;
      case 'localcustomer':
      case 'globalcustomer':
        statsUrl = '${ApiConfig.baseUrl}/quickstats/customer';
        prefsKey = 'customerQuickStats';
        break;
      default:
        print('No specific quick stats endpoint for role: $userRole');
        return; // Do nothing for other roles
    }

    try {
      final response = await http.get(
        Uri.parse(statsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['success'] == true && responseBody['data'] != null) {
          // Save the raw JSON string of the 'data' field to shared preferences
          SharedPrefs.setString(prefsKey, json.encode(responseBody['data']));
          print(
              'Quick stats for $userRole saved to local storage under key "$prefsKey".');
        } else {
          print(
              'Failed to load quick stats for $userRole: ${responseBody['message'] ?? 'Invalid data format.'}');
        }
      } else {
        print(
            'Failed to fetch quick stats for $userRole. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or saving quick stats for $userRole: $e');
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email or username is required';
    }
    // Simple validation for either email or username
    if (value.contains('@')) {
      if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
          .hasMatch(value.trim())) {
        return 'Please enter a valid email address';
      }
    } else {
      if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value.trim())) {
        return 'Please enter a valid username';
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: [
                      Image.network(
                        '${ApiConfig.baseUrl}/public/logo/icon.png',
                        fit: BoxFit.contain,
                        width: 80,
                        height: 80,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.error,
                            size: 50,
                            color: Colors.red,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Rehlko Customer Care',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sign in to your account',
                  style: TextStyle(fontSize: 14, color: Colors.blueAccent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  cursorColor: Colors.blue,
                  decoration: InputDecoration(
                    labelText: 'Email or Username',
                    hintText: 'Enter your email or username',
                    prefixIcon: const Icon(Icons.email_outlined),
                    prefixIconColor: Colors.blue[600],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: _validatePassword,
                  cursorColor: Colors.blue,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    labelStyle: TextStyle(color: Colors.grey[700]),
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    prefixIconColor: Colors.blue[600],
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.blue[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue[600]!),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/mobile_forgot_password');
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
