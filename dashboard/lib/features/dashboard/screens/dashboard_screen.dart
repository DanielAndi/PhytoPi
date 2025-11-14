import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _autoRefreshTimer;
  int _mobileSelectedIndex = 0;
  int _webSelectedIndex = 0;

  // Theme colors matching landing page
  static const Color _accentColor = Color(0xFF00FF88); // Bright neon green
  static const Color _purpleAccent = Color(0xFFFF81FF); // Bright pink/purple
  static const Color _darkPurple = Color(0xFF211F36);
  static const Color _mutedPurple = Color(0xFF616083);
  static const Color _darkBackground = Color(0xFF0A0A0A);
  static const Color _lightBackground = Color(0xFF1A1A1A);
  static const Color _cardBackground = Color(0xFF0C0E1D);

  @override
  void initState() {
    super.initState();
    // Setup auto-refresh for kiosk mode
    if (AppConfig.enableAutoRefresh) {
      _setupAutoRefresh();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(
      Duration(seconds: AppConfig.autoRefreshInterval),
      (timer) {
        // Refresh data
        setState(() {
          // Trigger rebuild to refresh data
          // In a real app, you would call a method to refresh data from providers
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      debugPrint('DashboardScreen: Building... isKiosk=${PlatformDetector.isKiosk}, isMobile=${PlatformDetector.isMobile}, isWeb=${PlatformDetector.isWeb}');
      
      // Platform-specific rendering
      if (PlatformDetector.isKiosk) {
        debugPrint('DashboardScreen: Building kiosk layout');
        return _buildKioskLayout(context);
      } else if (PlatformDetector.isMobile) {
        debugPrint('DashboardScreen: Building mobile layout');
        return _buildMobileLayout(context);
      } else {
        debugPrint('DashboardScreen: Building web layout');
        return _buildWebLayout(context);
      }
    } catch (e, stack) {
      debugPrint('DashboardScreen: Error in build - $e');
      debugPrint('Stack: $stack');
      // Return a simple error widget
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error building dashboard: $e'),
            ],
          ),
        ),
      );
    }
  }

  /// Kiosk-specific layout: fullscreen, auto-refresh, large displays
  Widget _buildKioskLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.3, -0.3),
            radius: 1.5,
            colors: [
              _purpleAccent.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Kiosk Header
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.eco,
                        size: 48,
                        color: _accentColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'PhytoPi Kiosk',
                      style: TextStyle(
                        fontSize: 48,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              // Main Content Area
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Plant Monitoring Dashboard',
                        style: TextStyle(
                          fontSize: 32,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Status indicators (placeholder for real data)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildKioskCard(
                            context,
                            icon: Icons.water_drop,
                            label: 'Humidity',
                            value: '65%',
                            color: _accentColor,
                          ),
                          const SizedBox(width: 24),
                          _buildKioskCard(
                            context,
                            icon: Icons.thermostat,
                            label: 'Temperature',
                            value: '22°C',
                            color: _purpleAccent,
                          ),
                          const SizedBox(width: 24),
                          _buildKioskCard(
                            context,
                            icon: Icons.light_mode,
                            label: 'Light',
                            value: '85%',
                            color: _accentColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Last updated: ${DateTime.now().toString().substring(11, 19)}',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKioskCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 64, color: color),
          ),
          const SizedBox(height: 24),
          Text(
            label,
            style: TextStyle(
              fontSize: 20,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 36,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Mobile-specific layout: bottom navigation, swipe gestures
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco, color: _accentColor),
            SizedBox(width: 8),
            Text('PhytoPi'),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: _lightBackground.withOpacity(0.95),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
        ),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              try {
                if (authProvider.isAuthenticated) {
                  return IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person, color: _accentColor),
                    ),
                    onPressed: () {
                      _showMobileMenu(context, authProvider);
                    },
                  );
                }
              } catch (e) {
                debugPrint('Error in mobile auth consumer: $e');
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.3, -0.3),
            radius: 1.5,
            colors: [
              _purpleAccent.withOpacity(0.05),
              Colors.transparent,
            ],
          ),
        ),
        child: IndexedStack(
          index: _mobileSelectedIndex,
          children: [
            _buildMobileDashboard(context),
            _buildMobileDevices(context),
            _buildMobileSettings(context),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _lightBackground,
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          selectedItemColor: _accentColor,
          unselectedItemColor: Colors.white.withOpacity(0.6),
          currentIndex: _mobileSelectedIndex,
          onTap: (index) {
            setState(() {
              _mobileSelectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.devices),
              label: 'Devices',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDashboard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to PhytoPi',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your IoT Plant Monitoring System',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          _buildStatCard(
            context,
            icon: Icons.eco,
            title: 'System Status',
            subtitle: 'All systems operational',
            color: _accentColor,
            isMobile: true,
          ),
          const SizedBox(height: 16),
          const Text(
            'Quick Stats',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMobileStatCard(
                  icon: Icons.water_drop,
                  value: '65%',
                  label: 'Humidity',
                  color: _accentColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMobileStatCard(
                  icon: Icons.thermostat,
                  value: '22°C',
                  label: 'Temperature',
                  color: _purpleAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMobileStatCard(
            icon: Icons.light_mode,
            value: '85%',
            label: 'Light',
            color: _accentColor,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool isMobile = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDevices(BuildContext context) {
    return Center(
      child: Text(
        'Devices Screen',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildMobileSettings(BuildContext context) {
    return Center(
      child: Text(
        'Settings Screen',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 18,
        ),
      ),
    );
  }

  void _showMobileMenu(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _lightBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: _accentColor),
              ),
              title: const Text('Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _purpleAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.settings, color: _purpleAccent),
              ),
              title: const Text('Settings', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Navigate to settings
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout, color: Colors.red),
              ),
              title: const Text('Logout', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                authProvider.signOut();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Web-specific layout: sidebar navigation, multi-column
  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco, color: _accentColor),
            SizedBox(width: 12),
            Text('PhytoPi Dashboard'),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: _lightBackground.withOpacity(0.95),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
        ),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              try {
                if (authProvider.isAuthenticated) {
                  return PopupMenuButton<String>(
                    color: _lightBackground,
                    onSelected: (value) {
                      try {
                        if (value == 'logout') {
                          authProvider.signOut();
                        } else if (value == 'profile') {
                          // Navigate to profile
                        } else if (value == 'settings') {
                          // Navigate to settings
                        }
                      } catch (e) {
                        debugPrint('Error in menu action: $e');
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'profile',
                        child: Text('Profile', style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem(
                        value: 'settings',
                        child: Text('Settings', style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Text('Logout', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person, color: _accentColor),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error in web auth consumer: $e');
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.3, -0.3),
            radius: 1.5,
            colors: [
              _purpleAccent.withOpacity(0.05),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            // Sidebar for web
            Container(
              color: _lightBackground,
              child: NavigationRail(
                backgroundColor: Colors.transparent,
                selectedIndex: _webSelectedIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _webSelectedIndex = index;
                  });
                },
                selectedIconTheme: const IconThemeData(color: _accentColor),
                selectedLabelTextStyle: const TextStyle(color: _accentColor),
                unselectedIconTheme: IconThemeData(color: Colors.white.withOpacity(0.6)),
                unselectedLabelTextStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: Text('Dashboard'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.devices_outlined),
                    selectedIcon: Icon(Icons.devices),
                    label: Text('Devices'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.analytics_outlined),
                    selectedIcon: Icon(Icons.analytics),
                    label: Text('Analytics'),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              color: Colors.white.withOpacity(0.1),
            ),
            // Main content
            Expanded(
              child: IndexedStack(
                index: _webSelectedIndex,
                children: [
                  _buildWebDashboard(context),
                  _buildWebDevices(context),
                  _buildWebAnalytics(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebDashboard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to PhytoPi Dashboard',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your IoT Plant Monitoring System',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          // System Status Card
          _buildStatCard(
            context,
            icon: Icons.eco,
            title: 'System Status',
            subtitle: 'All systems operational',
            color: _accentColor,
          ),
          const SizedBox(height: 24),
          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildWebStatCard(
                  icon: Icons.water_drop,
                  label: 'Humidity',
                  value: '65%',
                  color: _accentColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildWebStatCard(
                  icon: Icons.thermostat,
                  label: 'Temperature',
                  value: '22°C',
                  color: _purpleAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildWebStatCard(
                  icon: Icons.light_mode,
                  label: 'Light',
                  value: '85%',
                  color: _accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Additional metrics row
          Row(
            children: [
              Expanded(
                child: _buildWebStatCard(
                  icon: Icons.air,
                  label: 'Air Quality',
                  value: 'Good',
                  color: _purpleAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildWebStatCard(
                  icon: Icons.water,
                  label: 'Soil Moisture',
                  value: '72%',
                  color: _accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDevices(BuildContext context) {
    return Center(
      child: Text(
        'Devices Screen',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildWebAnalytics(BuildContext context) {
    return Center(
      child: Text(
        'Analytics Screen',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 18,
        ),
      ),
    );
  }
}


