import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
// Import necessary models if they are used in other methods of SharedPrefs
// import '../models/admin_stats.dart';
// import '../models/engineer_stats.dart';
// import '../models/customer_stats.dart';

class SharedPrefs {
  static Future<void> saveUser(User user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user.toJson()));
    await prefs.setString('token', token);
    await prefs.setInt('userId', user.id);
    await prefs.setString('userRole', user.role);
  }

  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user');
    if (userData != null) {
      try {
        return User.fromJson(jsonDecode(userData));
      } catch (e) {
        print('Error decoding user data from SharedPreferences: $e');
        return null;
      }
    }
    return null;
  }

  static Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', userId);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', role);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userRole');
  }

  // --- Added: Method to set a String value ---
  static Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  // --- Added: Method to get a String value ---
  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('userRole');
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
