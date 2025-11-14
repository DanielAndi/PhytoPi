import 'package:flutter/material.dart';
import '../../dashboard/screens/dashboard_screen.dart';

/// Landing page with dark hero section that gradually lightens on scroll
/// Inspired by modern tech/DeFi landing pages with e-commerce functionality
class LandingPageScreen extends StatefulWidget {
  const LandingPageScreen({super.key});

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  
  // Neon green accent color (inspired by Vivosun screenshot)
  static const Color _accentColor = Color(0xFF00FF88); // Bright neon green
  static const Color _darkBackground = Color(0xFF0A0A0A);
  static const Color _lightBackground = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  /// Calculate background color based on scroll position
  /// Dark at top, gradually lightens as user scrolls
  Color _getBackgroundColor() {
    const maxScroll = 800.0; // Distance to fully transition
    final progress = (_scrollOffset / maxScroll).clamp(0.0, 1.0);
    
    return Color.lerp(_darkBackground, _lightBackground, progress) ?? _darkBackground;
  }

  /// Calculate hero section opacity based on scroll
  double _getHeroOpacity() {
    const fadeStart = 200.0;
    const fadeEnd = 600.0;
    
    if (_scrollOffset < fadeStart) return 1.0;
    if (_scrollOffset > fadeEnd) return 0.0;
    
    return 1.0 - ((_scrollOffset - fadeStart) / (fadeEnd - fadeStart));
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor();
    final heroOpacity = _getHeroOpacity();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Navigation Bar
          _buildNavigationBar(context),
          
          // Secondary Navigation Bar (Product Categories)
          _buildSecondaryNavBar(context),
          
          // Hero Section
          _buildHeroSection(context, heroOpacity),
          
          // Products Section (prepared for future functionality)
          _buildProductsSection(context),
          
          // Features Section
          _buildFeaturesSection(context),
          
          // Pricing Section (prepared for future functionality)
          _buildPricingSection(context),
          
          // Footer
          _buildFooter(context),
        ],
      ),
    );
  }

  /// Navigation bar with search, links, and user menu
  Widget _buildNavigationBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 80,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: _getBackgroundColor().withOpacity(0.95),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final isMedium = constraints.maxWidth > 600;
                
                return Row(
                  children: [
                    // Logo
                    const Icon(
                      Icons.eco,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    const Flexible(
                      child: Text(
                        'PhytoPi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isWide) const Spacer(),
                    
                    // Search Bar (center)
                    if (isMedium) ...[
                      Flexible(
                        flex: isWide ? 2 : 1,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search PhytoPi',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    // Navigation Links (Support, Guide, Community)
                    if (isMedium) ...[
                      Flexible(
                        flex: isWide ? 0 : 1,
                        child: _buildNavLink(context, 'Support', onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Support page coming soon!')),
                          );
                        }),
                      ),
                      if (isWide) const SizedBox(width: 16),
                      Flexible(
                        flex: isWide ? 0 : 1,
                        child: _buildNavLink(context, 'Guide', onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Guide page coming soon!')),
                          );
                        }),
                      ),
                      if (isWide) const SizedBox(width: 16),
                      Flexible(
                        flex: isWide ? 0 : 1,
                        child: _buildNavLink(context, 'Community', onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Community page coming soon!')),
                          );
                        }),
                      ),
                      if (isWide) const SizedBox(width: 16),
                    ],
                    
                    // Currency/Region Selector
                    if (isWide) ...[
                      InkWell(
                        onTap: () {
                          // TODO: Show currency selector
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Currency selector coming soon!')),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.flag,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'USD',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    
                    // User Account Icon with Dropdown
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.person_outline,
                        color: Colors.white.withOpacity(0.9),
                        size: 24,
                      ),
                      color: _getBackgroundColor().withOpacity(0.98),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onSelected: (value) {
                        if (value == 'dashboard') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DashboardScreen(),
                            ),
                          );
                        } else if (value == 'profile') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile page coming soon!')),
                          );
                        } else if (value == 'settings') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settings page coming soon!')),
                          );
                        } else if (value == 'logout') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logout functionality coming soon!')),
                          );
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'dashboard',
                          child: Row(
                            children: [
                              Icon(Icons.dashboard, size: 20, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'Dashboard',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'profile',
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 20, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'Profile',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings, size: 20, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'Settings',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<String>(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, size: 20, color: Colors.white),
                              SizedBox(width: 12),
                              Text(
                                'Logout',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    
                    // Shopping Cart Icon
                    Stack(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.white.withOpacity(0.9),
                            size: 24,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Shopping cart coming soon!')),
                            );
                          },
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: _accentColor,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: const Text(
                              '0',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Secondary navigation bar with product categories
  Widget _buildSecondaryNavBar(BuildContext context) {
    final categories = [
      'Smart Box',
      'Grow Tent Kits',
      'Controllers',
      'Grow Tents',
      'Grow Lights',
      'Ventilation',
      'Circulation',
      'Temperature & Humidity',
      'Accessories',
    ];

    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMedium = constraints.maxWidth > 600;
            
            if (!isMedium) {
              // On mobile, show a scrollable horizontal list
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: categories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: InkWell(
                        onTap: () {
                          _scrollController.animateTo(
                            MediaQuery.of(context).size.height * 0.8,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Text(
                          category,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }
            
            // On desktop/tablet, show all categories in a row
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Wrap(
                spacing: 24,
                runSpacing: 8,
                children: categories.map((category) {
                  return InkWell(
                    onTap: () {
                      _scrollController.animateTo(
                        MediaQuery.of(context).size.height * 0.8,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavLink(BuildContext context, String text, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }

  Widget _buildCTAButton(BuildContext context, String text, {required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentColor,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  /// Hero section with dark gradient background
  Widget _buildHeroSection(BuildContext context, double opacity) {
    return SliverToBoxAdapter(
      child: Opacity(
        opacity: opacity,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.3, -0.3),
              radius: 1.5,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Animated background particles/effects
              Positioned.fill(
                child: CustomPaint(
                  painter: _ParticlePainter(),
                ),
              ),
              
              // Main content
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Small badge above headline
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _accentColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.eco, color: _accentColor, size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Smart Plant Monitoring',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Main headline
                      const Text(
                        'One-Click Plant\nDefense & Monitoring',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Subtitle
                      Text(
                        'Dive into smart agriculture, where innovative IoT technology\nmeets plant care expertise',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 20,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      // CTA Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const DashboardScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Open Dashboard',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton(
                            onPressed: () {
                              _scrollController.animateTo(
                                MediaQuery.of(context).size.height * 0.8,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white, width: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Discover More',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Scroll indicator
              Positioned(
                bottom: 32,
                left: 32,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Scroll down',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
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

  /// Products section (prepared for Amazon links and conversions)
  Widget _buildProductsSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Featured Products',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose the perfect PhytoPi solution for your needs',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 48),
            
            // Product cards (prepared for future product data)
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _buildProductCard(
                  context,
                  title: 'PhytoPi Starter Kit',
                  description: 'Complete monitoring solution for small gardens',
                  price: '\$99.99',
                  onBuyNow: () {
                    // TODO: Link to Amazon or direct purchase
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Purchase functionality coming soon!'),
                        backgroundColor: _accentColor,
                      ),
                    );
                  },
                ),
                _buildProductCard(
                  context,
                  title: 'PhytoPi Pro',
                  description: 'Advanced monitoring with AI insights',
                  price: '\$199.99',
                  onBuyNow: () {
                    // TODO: Link to Amazon or direct purchase
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Purchase functionality coming soon!'),
                        backgroundColor: _accentColor,
                      ),
                    );
                  },
                ),
                _buildProductCard(
                  context,
                  title: 'PhytoPi Enterprise',
                  description: 'Multi-device management for commercial use',
                  price: '\$499.99',
                  onBuyNow: () {
                    // TODO: Link to Amazon or direct purchase
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Purchase functionality coming soon!'),
                        backgroundColor: _accentColor,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context, {
    required String title,
    required String description,
    required String price,
    required VoidCallback onBuyNow,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width > 900
          ? (MediaQuery.of(context).size.width - 72) / 3
          : MediaQuery.of(context).size.width > 600
              ? (MediaQuery.of(context).size.width - 48) / 2
              : MediaQuery.of(context).size.width - 48,
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
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                Icons.eco,
                size: 64,
                color: _accentColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: _accentColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton(
                onPressed: onBuyNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Buy Now',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Features section
  Widget _buildFeaturesSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why Choose PhytoPi?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _buildFeatureCard(
                  context,
                  icon: Icons.sensors,
                  title: 'Real-Time Monitoring',
                  description: 'Track temperature, humidity, and light levels in real-time',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.notifications_active,
                  title: 'Smart Alerts',
                  description: 'Get notified when your plants need attention',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.analytics,
                  title: 'Data Analytics',
                  description: 'View historical data and trends for optimal plant care',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.cloud,
                  title: 'Cloud Sync',
                  description: 'Access your data from anywhere, anytime',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.security,
                  title: 'Secure & Private',
                  description: 'Your data is encrypted and stored securely',
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.phone_android,
                  title: 'Multi-Platform',
                  description: 'Works on web, mobile, and tablet devices',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width > 900
          ? (MediaQuery.of(context).size.width - 72) / 3
          : MediaQuery.of(context).size.width > 600
              ? (MediaQuery.of(context).size.width - 48) / 2
              : MediaQuery.of(context).size.width - 48,
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _accentColor, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Pricing section (prepared for future functionality)
  Widget _buildPricingSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
        child: Column(
          children: [
            const Text(
              'Simple, Transparent Pricing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose the plan that works best for you',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 48),
            // TODO: Add pricing cards when pricing is finalized
            Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Text(
                'Pricing plans coming soon',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Footer
  Widget _buildFooter(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.eco, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'PhytoPi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 24,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DashboardScreen(),
                          ),
                        );
                      },
                      child: const Text('Dashboard', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () {
                        _scrollController.animateTo(
                          MediaQuery.of(context).size.height * 0.8,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Shop', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Support page coming soon!')),
                        );
                      },
                      child: const Text('Support', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '© 2024 PhytoPi. All rights reserved.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for particle effects in hero section
class _ParticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    // Draw some subtle particles/stars
    final random = _SeededRandom(42);
    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 1, paint);
    }

    // Draw some connecting lines (network effect)
    paint.color = Colors.white.withOpacity(0.05);
    for (int i = 0; i < 20; i++) {
      final x1 = random.nextDouble() * size.width;
      final y1 = random.nextDouble() * size.height;
      final x2 = random.nextDouble() * size.width;
      final y2 = random.nextDouble() * size.height;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simple seeded random for consistent particle placement
class _SeededRandom {
  int _seed;

  _SeededRandom(this._seed);

  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }
}

