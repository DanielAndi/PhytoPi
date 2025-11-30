import 'package:flutter/material.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  void _showClaimDeviceDialog(BuildContext context) {
    final deviceIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claim Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the Device ID found on your PhytoPi unit.'),
            const SizedBox(height: 16),
            TextField(
              controller: deviceIdController,
              decoration: const InputDecoration(
                labelText: 'Device ID',
                hintText: 'e.g., PP-1234-5678',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement actual claim logic with Supabase
              final id = deviceIdController.text;
              Navigator.pop(context);
              if (id.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Claiming device $id...')),
                );
              }
            },
            child: const Text('Claim'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Devices',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showClaimDeviceDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Claim Device'),
          ),
        ],
      ),
    );
  }
}
