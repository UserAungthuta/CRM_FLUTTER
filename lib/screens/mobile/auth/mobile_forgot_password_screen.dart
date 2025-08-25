import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
// Ensure this model is correctly defined if used
// Ensure this utility is correctly defined if used
import '../../../utils/api_config.dart'; // Ensure this utility is correctly defined

class MobileForgotPasswordScreen extends StatefulWidget {
  const MobileForgotPasswordScreen({super.key});

  @override
  _MobileForgotPasswordScreenState createState() =>
      _MobileForgotPasswordScreenState();
}

class _MobileForgotPasswordScreenState
    extends State<MobileForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(
            {'email': _emailController.text.trim()}), // Trim email input
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] != null) {
          // Check for a 'message' key to indicate success or specific error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
          if (data['message'].contains('sent to your email')) {
            // Check for success message content
            Navigator.pop(
                context); // Pop if success message indicates email sent
          } else {
            setState(() {
              _errorMessage =
                  data['message']; // Display specific error message from API
            });
          }
        } else {
          setState(() {
            _errorMessage =
                'Failed to send reset link: Unknown response from server.';
          });
        }
      } else {
        final data = json.decode(response.body);
        setState(() {
          _errorMessage =
              data['message'] ?? 'Failed to send reset link. Please try again.';
        });
      }
    } on SocketException {
      setState(() {
        _errorMessage = 'No internet connection. Please check your network.';
      });
    } on TimeoutException {
      setState(() {
        _errorMessage = 'Request timed out. Server might be slow to respond.';
      });
    } on FormatException {
      setState(() {
        _errorMessage = 'Invalid response format from server.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: const Color.fromARGB(
            255, 51, 110, 229), // Consistent with LoginScreen
        foregroundColor: Colors.white, // Consistent with LoginScreen
      ),
      backgroundColor: Colors.white, // Consistent background
      body: Center(
        // Center the content
        child: SingleChildScrollView(
          // Allow scrolling if content overflows
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // Stretch children horizontally
              children: [
                Image.network(
                  '${ApiConfig.baseUrl}/public/logo/icon.png', // Path to your local asset image
                  fit: BoxFit.contain,
                  width: 50,
                  height: 50,
                  errorBuilder: (context, error, stackTrace) {
// Fallback if the asset image cannot be loaded
                    return const Icon(
                      Icons.error,
                      size: 50,
                      color: Colors.white,
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reset Your Password',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your email address to receive a password reset link.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your registered email',
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
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue[600]!),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    // Basic email regex for client-side validation
                    if (!RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                        .hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendResetLink,
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
                          'Send Reset Link',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
