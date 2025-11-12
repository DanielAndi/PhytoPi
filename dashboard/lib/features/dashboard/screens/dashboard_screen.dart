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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Kiosk Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.eco,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'PhytoPi Kiosk',
                      style: TextStyle(
                        fontSize: 48,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
                      const Text(
                        'Plant Monitoring Dashboard',
                        style: TextStyle(
                          fontSize: 32,
                          color: Colors.white,
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
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 24),
                          _buildKioskCard(
                            context,
                            icon: Icons.thermostat,
                            label: 'Temperature',
                            value: '22°C',
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 24),
                          _buildKioskCard(
                            context,
                            icon: Icons.light_mode,
                            label: 'Light',
                            value: '85%',
                            color: Colors.yellow,
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Last updated: ${DateTime.now().toString().substring(11, 19)}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              color: Colors.white,
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
      appBar: AppBar(
        title: const Text('PhytoPi'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              try {
                if (authProvider.isAuthenticated) {
                  return IconButton(
                    icon: const Icon(Icons.person),
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
      body: IndexedStack(
        index: _mobileSelectedIndex,
        children: [
          _buildMobileDashboard(context),
          _buildMobileDevices(context),
          _buildMobileSettings(context),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
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
    );
  }

  Widget _buildMobileDashboard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to PhytoPi',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.eco,
                    size: 64,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your IoT Plant Monitoring System',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Quick Stats',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.water_drop, color: Colors.blue),
                        const SizedBox(height: 8),
                        const Text('65%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const Text('Humidity', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.thermostat, color: Colors.orange),
                        const SizedBox(height: 8),
                        const Text('22°C', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const Text('Temperature', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDevices(BuildContext context) {
    return const Center(
      child: Text('Devices Screen'),
    );
  }

  Widget _buildMobileSettings(BuildContext context) {
    return const Center(
      child: Text('Settings Screen'),
    );
  }

  void _showMobileMenu(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                authProvider.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Web-specific layout: sidebar navigation, multi-column
  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PhytoPi Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              try {
                if (authProvider.isAuthenticated) {
                  return PopupMenuButton<String>(
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
                        child: Text('Profile'),
                      ),
                      const PopupMenuItem(
                        value: 'settings',
                        child: Text('Settings'),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Text('Logout'),
                      ),
                    ],
                    child: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Colors.green),
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
      body: Row(
        children: [
          // Sidebar for web
          NavigationRail(
            selectedIndex: _webSelectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _webSelectedIndex = index;
              });
            },
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
          const VerticalDivider(thickness: 1, width: 1),
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
    );
  }

  Widget _buildWebDashboard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to PhytoPi Dashboard',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.eco,
                          size: 64,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your IoT Plant Monitoring System',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '🌱 Hello World! Dashboard is ready! 🌱',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Stats grid
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.water_drop, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Humidity', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('65%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.thermostat, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Temperature', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('22°C', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.light_mode, color: Colors.yellow),
                            SizedBox(width: 8),
                            Text('Light', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('85%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebDevices(BuildContext context) {
    return const Center(
      child: Text('Devices Screen'),
    );
  }

  Widget _buildWebAnalytics(BuildContext context) {
    return const Center(
      child: Text('Analytics Screen'),
    );
  }
}
