// lib/widgets/header_widget.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart'; // Adjust path if necessary for your project structure

class HeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final User? currentUser;
  final VoidCallback onLogout;

  const HeaderWidget({
    super.key,
    required this.title,
    this.currentUser,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Use AppBar to get its inherent behaviors (like leading menu icon for drawer)
      backgroundColor: const Color(0xFF336EE5), // Use your desired header color
      elevation: 4, // Add shadow
      titleSpacing:
          0.0, // Remove default spacing if you want title closer to menu icon
      automaticallyImplyLeading:
          true, // Let AppBar decide if it needs a leading button (e.g., drawer or back button)
      title: Padding(
        // Wrap title in Padding to align it properly if needed
        padding: const EdgeInsets.only(left: 8.0), // Adjust padding as needed
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      actions: [
        // Remove the manual IconButton for menu here, AppBar handles it.
        // The logo and user info
        Image.asset(
          'images/logo.png', // Path to your logo image
          height: 40, // Adjust height as needed
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 16.0), // Space between logo and user menu
        PopupMenuButton<String>(
          offset: const Offset(0, 45), // Position dropdown below button
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'profile',
              child: Text('Profile'),
            ),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Text('Logout'),
            ),
          ],
          onSelected: (String value) {
            if (value == 'profile') {
              Navigator.of(context).pushNamed('/profile');
            } else if (value == 'logout') {
              onLogout();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green, // Background color for the button area
              borderRadius: BorderRadius.circular(3.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                const Icon(Icons.account_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8.0),
                Text(
                  currentUser?.fullname ?? 'Admin',
                  style: const TextStyle(color: Colors.white),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16.0), // Padding on the right
      ],
    );
  }

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight); // Required for PreferredSizeWidget
}
