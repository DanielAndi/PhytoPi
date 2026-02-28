import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _lightsOn = false;
  bool _pumpOn = false;
  bool _fansOn = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceProvider = context.watch<DeviceProvider>();
    final selectedDevice = deviceProvider.selectedDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts & Commands'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Alerts', icon: Icon(Icons.notifications)),
            Tab(text: 'Commands', icon: Icon(Icons.touch_app)),
            Tab(text: 'Schedules', icon: Icon(Icons.schedule)),
            Tab(text: 'Thresholds', icon: Icon(Icons.tune)),
          ],
        ),
      ),
      body: selectedDevice == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.devices_other, size: 64, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text(
                    'Select a device to manage alerts and commands',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAlertsTab(deviceProvider),
                _buildCommandsTab(deviceProvider),
                _buildSchedulesTab(),
                _buildThresholdsTab(),
              ],
            ),
    );
  }

  Widget _buildAlertsTab(DeviceProvider deviceProvider) {
    final theme = Theme.of(context);
    final alerts = deviceProvider.alerts;

    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text('No alerts', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (context, i) {
        final a = alerts[i];
        final type = a['type'] as String? ?? '';
        final message = a['message'] as String? ?? '';
        final severity = a['severity'] as String? ?? 'medium';
        final triggered = a['triggered_at'] != null
            ? DateTime.parse(a['triggered_at'])
            : null;
        final resolved = a['resolved_at'] != null;

        Color severityColor = Colors.grey;
        if (severity == 'critical') severityColor = Colors.red;
        else if (severity == 'high') severityColor = Colors.orange;
        else if (severity == 'medium') severityColor = Colors.amber;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: resolved ? theme.colorScheme.surfaceContainerHighest : null,
          child: ListTile(
            leading: Icon(
              type == 'water_level_low' ? Icons.water_drop : Icons.warning,
              color: severityColor,
            ),
            title: Text(message),
            subtitle: triggered != null
                ? Text(DateFormat.yMd().add_Hm().format(triggered))
                : null,
            trailing: resolved
                ? Chip(label: Text('Resolved', style: TextStyle(fontSize: 12)))
                : null,
          ),
        );
      },
    );
  }

  Widget _buildCommandsTab(DeviceProvider deviceProvider) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Manual Controls', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          _commandCard(
            title: 'Lights',
            icon: Icons.lightbulb,
            onPressed: () async {
              final target = !_lightsOn;
              await deviceProvider.toggleGrowLights(target);
              if (mounted) setState(() => _lightsOn = target);
              _showSnack('Lights ${target ? "ON" : "OFF"}');
            },
            state: _lightsOn,
          ),
          _commandCard(
            title: 'Pump',
            icon: Icons.water_drop,
            onPressed: () async {
              final target = !_pumpOn;
              await deviceProvider.togglePump(target, durationSec: 30);
              if (mounted) setState(() => _pumpOn = target);
              _showSnack('Pump ${target ? "ON" : "OFF"} (30s)');
            },
            state: _pumpOn,
          ),
          _commandCard(
            title: 'Fans',
            icon: Icons.air,
            onPressed: () async {
              final target = !_fansOn;
              await deviceProvider.toggleFans(target);
              if (mounted) setState(() => _fansOn = target);
              _showSnack('Fans ${target ? "ON" : "OFF"}');
            },
            state: _fansOn,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await deviceProvider.runVentilation(durationSec: 300, dutyPercent: 80);
              _showSnack('Ventilation run for 5 min');
            },
            icon: const Icon(Icons.air),
            label: const Text('Run Ventilation (5 min)'),
          ),
        ],
      ),
    );
  }

  Widget _commandCard({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    required bool state,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: state ? Colors.green : null),
        title: Text(title),
        trailing: FilledButton(
          onPressed: onPressed,
          child: Text(state ? 'Turn Off' : 'Turn On'),
        ),
      ),
    );
  }

  Widget _buildSchedulesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text('Schedules coming soon', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildThresholdsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.tune, size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text('Threshold config coming soon', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}
