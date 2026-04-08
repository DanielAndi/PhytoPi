import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/dashboard_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import 'store_screen.dart';

class LandingPageScreen extends StatelessWidget {
  const LandingPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    final authProvider = context.read<AuthProvider>();
    final isAuthenticated = authProvider.isAuthenticated;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.eco, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Text('PhytoPi'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StoreScreen()),
              );
            },
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Store'),
          ),
          const SizedBox(width: 8),
          if (isAuthenticated) ...[
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                );
              },
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Dashboard'),
            ),
            const SizedBox(width: 8),
          ],
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (value) {
              if (value == 'dashboard') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                );
              } else if (value == 'login') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              } else if (value == 'logout') {
                context.read<AuthProvider>().signOut();
              }
            },
            itemBuilder: (context) {
              final isAuthed = context.read<AuthProvider>().isAuthenticated;
              return [
                if (isAuthed)
                  const PopupMenuItem<String>(
                    value: 'dashboard',
                    child: Row(
                      children: [
                        Icon(Icons.dashboard, size: 20),
                        SizedBox(width: 12),
                        Text('Dashboard'),
                      ],
                    ),
                  ),
                PopupMenuItem<String>(
                  value: isAuthed ? 'logout' : 'login',
                  child: Row(
                    children: [
                      Icon(isAuthed ? Icons.logout : Icons.login, size: 20),
                      SizedBox(width: 12),
                      Text(isAuthed ? 'Logout' : 'Login'),
                    ],
                  ),
                ),
              ];
            },
            icon: const Icon(Icons.person_outline),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroCard(isAuthenticated: isAuthenticated),
                const SizedBox(height: 24),
                Text('Success metrics', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                const _MetricsGrid(),
                const SizedBox(height: 28),
                Text('How it works', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                const _HowItWorksGrid(),
                const SizedBox(height: 28),
                Text('What you can monitor', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                const _MonitorGrid(),
                const SizedBox(height: 28),
                Text('Architecture overview', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                const _ArchitectureCard(),
                const SizedBox(height: 28),
                _FooterCard(isAuthenticated: isAuthenticated),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool isAuthenticated;
  const _HeroCard({required this.isAuthenticated});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 820;
          final content = _HeroCopy(isAuthenticated: isAuthenticated);
          final visual = const _HeroVisual();

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 16),
                visual,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              const SizedBox(width: 20),
              const SizedBox(width: 360, child: _HeroVisual()),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final bool isAuthenticated;
  const _HeroCopy({required this.isAuthenticated});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Automated plant care.\nRemote monitoring.\nSmarter growing.',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'PhytoPi is an IoT automated plant care system that senses environmental conditions, analyzes trends, and triggers adjustments like irrigation—while giving you a fast, real-time dashboard.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (isAuthenticated)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  );
                },
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('Open dashboard'),
              )
            else
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('Login'),
              ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StoreScreen()),
                );
              },
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Store'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surfaceContainerHigh.withOpacity(
          theme.brightness == Brightness.dark ? 0.35 : 1,
        ),
        border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
      ),
      child: Center(
        child: Icon(
          Icons.auto_graph_rounded,
          size: 110,
          color: theme.colorScheme.primary.withOpacity(0.9),
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = const [
      _MiniMetric(
        title: '≥80% less manual care',
        subtitle: 'Target reduction in manual plant-care labor',
        icon: Icons.handyman_outlined,
      ),
      _MiniMetric(
        title: '<2s dashboard refresh',
        subtitle: 'Performance target for the mobile dashboard',
        icon: Icons.speed,
      ),
      _MiniMetric(
        title: '<\$250 hardware goal',
        subtitle: 'Target unit hardware cost (prototype goal ~\$200)',
        icon: Icons.payments_outlined,
      ),
      _MiniMetric(
        title: '3+ health metrics',
        subtitle: 'Light, soil moisture, growth projection vs actual',
        icon: Icons.monitor_heart_outlined,
      ),
    ];

    return _AdaptiveGrid(
      children: items
          .map(
            (m) => DashboardCard(
              accentColor: theme.colorScheme.primary,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(m.icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m.subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _HowItWorksGrid extends StatelessWidget {
  const _HowItWorksGrid();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = const [
      _Step(
        title: 'Sense',
        subtitle: 'Collect environmental readings and camera snapshots.',
        icon: Icons.sensors_outlined,
      ),
      _Step(
        title: 'Analyze',
        subtitle: 'Detect trends and anomalies; project expected growth.',
        icon: Icons.analytics_outlined,
      ),
      _Step(
        title: 'Actuate',
        subtitle: 'Trigger safe adjustments like watering and humidity control.',
        icon: Icons.tune,
      ),
      _Step(
        title: 'Alert',
        subtitle: 'Notify users and log actions for verification and troubleshooting.',
        icon: Icons.notifications_active_outlined,
      ),
    ];

    return _AdaptiveGrid(
      children: steps
          .map(
            (s) => DashboardCard(
              accentColor: theme.colorScheme.secondary,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.secondary.withOpacity(
                      theme.brightness == Brightness.dark ? 0.18 : 0.12,
                    ),
                    child: Icon(s.icon, color: theme.colorScheme.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MonitorGrid extends StatelessWidget {
  const _MonitorGrid();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = const [
      _MonitorItem(title: 'Soil moisture', icon: Icons.grass_outlined),
      _MonitorItem(title: 'Light levels', icon: Icons.light_mode_outlined),
      _MonitorItem(title: 'Temperature', icon: Icons.thermostat_outlined),
      _MonitorItem(title: 'Humidity', icon: Icons.water_drop_outlined),
      _MonitorItem(title: 'Water reservoir', icon: Icons.water_outlined),
      _MonitorItem(title: 'Camera + AI health', icon: Icons.videocam_outlined),
    ];

    return _AdaptiveGrid(
      minItemWidth: 240,
      children: items
          .map(
            (i) => DashboardCard(
              accentColor: theme.colorScheme.primary,
              child: Row(
                children: [
                  Icon(i.icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      i.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ArchitectureCard extends StatelessWidget {
  const _ArchitectureCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashboardCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sensors → Edge compute → Cloud → Dashboard',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Hardware (Raspberry Pi 5 + ESP32) gathers sensor and camera data, stores it, and drives actuators like a pump. '
            'The Flutter dashboard provides fast visibility, configuration, and alerts.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _Pill(label: 'Raspberry Pi 5'),
              _Pill(label: 'ESP32'),
              _Pill(label: 'Sensors + Camera'),
              _Pill(label: 'Actuators (pump, etc.)'),
              _Pill(label: 'Flutter UI'),
              _Pill(label: 'Supabase backend'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterCard extends StatelessWidget {
  final bool isAuthenticated;
  const _FooterCard({required this.isAuthenticated});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashboardCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.eco, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Built as a capstone IoT project: measurable goals, verifiable logs, and a responsive dashboard-first UX.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => isAuthenticated
                      ? const DashboardScreen()
                      : const LoginScreen(),
                ),
              );
            },
            child: Text(isAuthenticated ? 'Dashboard' : 'Login'),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  const _AdaptiveGrid({
    required this.children,
    this.minItemWidth = 260,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 980 ? 3 : (width >= 640 ? 2 : 1);
        final itemWidth =
            ((width - (16 * (cols - 1))) / cols).clamp(minItemWidth, width);
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map((c) => SizedBox(width: itemWidth.toDouble(), child: c))
              .toList(),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withOpacity(
          theme.brightness == Brightness.dark ? 0.35 : 1,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MiniMetric {
  final String title;
  final String subtitle;
  final IconData icon;
  const _MiniMetric({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _Step {
  final String title;
  final String subtitle;
  final IconData icon;
  const _Step({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _MonitorItem {
  final String title;
  final IconData icon;
  const _MonitorItem({required this.title, required this.icon});
}

