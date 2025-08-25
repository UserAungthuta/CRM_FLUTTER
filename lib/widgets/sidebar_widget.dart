import 'package:flutter/material.dart';

class WebSuperAdminSidebar extends StatelessWidget {
  final bool isOpen;
  final double width;
  final VoidCallback onDashboardTap;
  final VoidCallback onUsersTap;
  final VoidCallback onSupportTap;
  final VoidCallback onProductsManageTap;
  final VoidCallback onAssignedProductsTap;
  final VoidCallback onReportsTap;
  final VoidCallback onMaintenanceTap;
  final VoidCallback onCountrySettingsTap;
  final VoidCallback onReportWarningSettingsTap;
  final VoidCallback onTermsSettingsTap;

  const WebSuperAdminSidebar({
    super.key,
    required this.isOpen,
    required this.width,
    required this.onDashboardTap,
    required this.onUsersTap,
    required this.onSupportTap,
    required this.onProductsManageTap,
    required this.onAssignedProductsTap,
    required this.onReportsTap,
    required this.onMaintenanceTap,
    required this.onCountrySettingsTap,
    required this.onReportWarningSettingsTap,
    required this.onTermsSettingsTap,
  });

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

  @override
  Widget build(BuildContext context) {
    // Standard AppBar height for the custom sidebar header
    const double kAppBarHeight = kToolbarHeight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300), // Smooth animation
      width: isOpen ? width : 0.0, // Toggle width
      color: const Color(0xFF1E293B), // Equivalent to bg-gray-800
      child: isOpen // Only render content if sidebar is open
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sidebar Header (can be customized if needed)
                Container(
                  height: kAppBarHeight, // Match custom header height
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  alignment: Alignment.centerLeft,
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildSidebarItem(
                          Icons.dashboard, 'Dashboard', onDashboardTap),
                      ExpansionTile(
                        leading:
                            const Icon(Icons.people, color: Colors.white),
                        title: const Text('Users',
                            style: TextStyle(color: Colors.white)),
                        collapsedIconColor: Colors.white,
                        iconColor: Colors.white,
                        children: <Widget>[
                          _buildSidebarItem(Icons.people,
                              'Users Management', onUsersTap,
                              isSubItem: true),
                          _buildSidebarItem(Icons.support_agent,
                              'Support Team', onSupportTap,
                              isSubItem: true),
                        ],
                      ),
                      ExpansionTile(
                        leading:
                            const Icon(Icons.category, color: Colors.white),
                        title: const Text('Products',
                            style: TextStyle(color: Colors.white)),
                        collapsedIconColor: Colors.white,
                        iconColor: Colors.white,
                        children: <Widget>[
                          _buildSidebarItem(Icons.category,
                              'Products Management', onProductsManageTap,
                              isSubItem: true),
                          _buildSidebarItem(Icons.shopping_bag,
                              'Assigned Products', onAssignedProductsTap,
                              isSubItem: true),
                        ],
                      ),
                      _buildSidebarItem(
                          Icons.bar_chart, 'Reports', onReportsTap),
                      _buildSidebarItem(
                          Icons.build, 'Maintenance', onMaintenanceTap),
                      // Settings ExpansionTile for sidebar
                      ExpansionTile(
                        leading:
                            const Icon(Icons.settings, color: Colors.white),
                        title: const Text('Settings',
                            style: TextStyle(color: Colors.white)),
                        collapsedIconColor: Colors.white,
                        iconColor: Colors.white,
                        children: <Widget>[
                          _buildSidebarItem(
                              Icons.flag, 'Country', onCountrySettingsTap,
                              isSubItem: true),
                          _buildSidebarItem(Icons.warning, 'Report Warning',
                              onReportWarningSettingsTap,
                              isSubItem: true),
                          _buildSidebarItem(
                              Icons.description, 'Terms', onTermsSettingsTap,
                              isSubItem: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(), // Hide content when sidebar is closed
    );
  }
}
