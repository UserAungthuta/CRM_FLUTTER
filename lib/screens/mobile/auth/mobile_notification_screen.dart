import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../../utils/shared_prefs.dart';
import '../../../utils/api_config.dart';

// Enum to manage the current view state for Notifications
enum NoticationView {
  list,
  read,
}

class MobileNotificationScreen extends StatefulWidget {
  const MobileNotificationScreen({super.key});

  @override
  _MobileNotificationScreenState createState() =>
      _MobileNotificationScreenState();
}

class _MobileNotificationScreenState extends State<MobileNotificationScreen> {
  // Future type to hold Notification data
  late Future<List<Map<String, String>>> _notificationFuture;
  NoticationView _currentView = NoticationView.list; // Default view is the list
  Map<String, String>?
      _readingNotification; // Holds data of the notification being read

  @override
  void initState() {
    super.initState();
    _fetchNotificationsData(); // Fetch notifications on init
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Refreshes the notification list data
  void _fetchNotificationsData() {
    setState(() {
      _notificationFuture = _fetchNotifications();
    });
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

  /// Fetches the list of user notifications from the API.
  Future<List<Map<String, String>>> _fetchNotifications() async {
    try {
      final String? token = await SharedPrefs.getToken();
      final int? userID = await SharedPrefs.getUserId();
      //print(userID);
      if (token == null || token.isEmpty) {
        _showSnackBar(
            context, 'Authentication token missing. Please log in again.',
            color: Colors.red);
        return [];
      }
      if (userID == null) {
        _showSnackBar(context, 'User ID missing. Please log in again.',
            color: Colors.red);
        return [];
      }

      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/notifications/read-user-notifications/$userID');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timeout - Server not responding.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['data'] is List) {
          List<Map<String, String>> notifications = [];
          for (var item in responseData['data']) {
            if (item is Map<String, dynamic>) {
              notifications.add({
                'id': item['id']?.toString() ?? 'N/A',
                'notifications_title':
                    item['notifications_title']?.toString() ?? 'N/A',
                'notifications_content':
                    item['notifications_content']?.toString() ?? 'N/A',
                'notifications_category':
                    item['notifications_category']?.toString() ?? 'N/A',
                // Fix: Correctly parse 'is_read' from 1/0 to 'true'/'false' string
                'is_read': (item['is_read'] == 1 || item['is_read'] == true)
                    ? 'true'
                    : 'false',
                'created_time': item['created_time']?.toString() ?? 'N/A',
              });
            }
          }
          return notifications;
        } else {
          _showSnackBar(
              context, 'Failed to load notifications. Invalid data format.',
              color: Colors.red);
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to load notifications. Server error.',
            color: Colors.red);
        return [];
      }
    } on SocketException {
      _showSnackBar(context, 'Network error. Check your internet connection.',
          color: Colors.red);
      return [];
    } on TimeoutException {
      _showSnackBar(context, 'Request timed out. Server not responding.',
          color: Colors.red);
      return [];
    } on FormatException {
      _showSnackBar(context, 'Invalid response format from server.',
          color: Colors.red);
      return [];
    } catch (e) {
      _showSnackBar(context, 'An unexpected error occurred: ${e.toString()}',
          color: Colors.red);
      return [];
    }
  }

  /// Marks a notification as read via API.
  Future<void> _markNotificationAsRead(String notificationId) async {
    final String? token = await SharedPrefs.getToken();
    if (token == null || token.isEmpty) {
      _showSnackBar(
          context, 'Authentication token missing. Please log in again.',
          color: Colors.red);
      return;
    }

    try {
      final Uri uri = Uri.parse(
          '${ApiConfig.baseUrl}/notifications/mark-as-read/$notificationId');
      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar(context, 'Notification marked as read!',
            color: Colors.green);
        _fetchNotificationsData(); // Refresh list to reflect the change
        // Update the local _readingNotification to reflect the change immediately
        if (_readingNotification != null &&
            _readingNotification!['id'] == notificationId) {
          setState(() {
            _readingNotification!['is_read'] = 'true';
          });
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(
            context,
            errorData['message'] ??
                'Failed to mark notification as read. Server error.',
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
    }
  }

  // Method to build the "Read Notification" content
  Widget _buildReadContent(Map<String, String> notification) {
    bool isRead = notification['is_read'] == 'true';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            notification['notifications_title'] ?? 'No Title',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Category: ${notification['notifications_category'] ?? 'N/A'}',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 5),
          Text(
            'Received: ${notification['created_time'] ?? 'N/A'}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Text(
            notification['notifications_content'] ?? 'No Content',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 30),
          if (!isRead)
            ElevatedButton(
              onPressed: () => _markNotificationAsRead(notification['id']!),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Mark as Read', style: TextStyle(fontSize: 18)),
            ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _currentView = NoticationView.list;
                _readingNotification = null;
              });
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Back to List',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentView == NoticationView.list
              ? 'Notifications'
              : 'Notification Details', // Adjusted title
        ),
        backgroundColor: const Color(0xFF336EE5),
        foregroundColor: Colors.white,
        leading: _currentView != NoticationView.list
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentView = NoticationView.list;
                    _readingNotification = null;
                  });
                },
              )
            : null,
      ),
      body: _currentView == NoticationView.list
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Your Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[700],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: FutureBuilder<List<Map<String, String>>>(
                      future: _notificationFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(
                              child: Text('No notifications available.'));
                        } else {
                          final notifications = snapshot.data!;
                          return ListView.builder(
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notification = notifications[index];
                              final bool isRead =
                                  notification['is_read'] == 'true';
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    setState(() {
                                      _readingNotification = notification;
                                      _currentView = NoticationView.read;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isRead
                                              ? Icons
                                                  .mark_email_read // Changed icon for read
                                              : Icons.mail_outline,
                                          color: isRead
                                              ? Colors.green
                                              : Colors.blue,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                notification[
                                                        'notifications_title'] ??
                                                    'N/A',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: isRead
                                                        ? Colors.grey
                                                        : Colors.black),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                notification[
                                                        'notifications_content'] ??
                                                    'N/A',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    color: isRead
                                                        ? Colors.grey[600]
                                                        : Colors.grey[700]),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Category: ${notification['notifications_category'] ?? 'N/A'} - ${notification['created_time'] ?? 'N/A'}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Fix: Only show "Mark as Read" if not already read, otherwise show disabled icon
                                        if (!isRead)
                                          IconButton(
                                            icon: const Icon(
                                                Icons.check_circle_outline,
                                                color: Colors.green),
                                            tooltip: 'Mark as Read',
                                            onPressed: () {
                                              _markNotificationAsRead(
                                                  notification['id']!);
                                            },
                                          ),
                                        if (isRead)
                                          const IconButton(
                                            icon: Icon(
                                                Icons.check_circle_rounded,
                                                color: Colors.green),
                                            tooltip:
                                                'Already Read', // Tooltip for read state
                                            onPressed:
                                                null, // Disable onPressed when already read
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            )
          : _buildReadContent(_readingNotification!),
    );
  }
}
