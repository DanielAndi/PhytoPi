import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../providers/device_provider.dart';

class AiHealthScreen extends StatefulWidget {
  const AiHealthScreen({super.key});

  @override
  State<AiHealthScreen> createState() => _AiHealthScreenState();
}

class _AiHealthScreenState extends State<AiHealthScreen> {
  Map<String, dynamic>? _latestJob;
  Map<String, dynamic>? _latestInference;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final device = context.read<DeviceProvider>().selectedDevice;
    if (device == null || !SupabaseConfig.isInitialized) {
      setState(() {
        _loading = false;
        _latestJob = null;
        _latestInference = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final jobs = await SupabaseConfig.client!
          .from('ai_capture_jobs')
          .select()
          .eq('device_id', device.id)
          .order('created_at', ascending: false)
          .limit(1);

      final inferences = await SupabaseConfig.client!
          .from(SupabaseConfig.mlInferencesTable)
          .select()
          .eq('device_id', device.id)
          .order('timestamp', ascending: false)
          .limit(1);

      if (mounted) {
        setState(() {
          _latestJob = (jobs as List).isNotEmpty ? jobs.first : null;
          _latestInference = (inferences as List).isNotEmpty ? inferences.first : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _triggerCapture() async {
    final device = context.read<DeviceProvider>().selectedDevice;
    if (device == null || !SupabaseConfig.isInitialized) return;

    try {
      await SupabaseConfig.client!
          .from(SupabaseConfig.deviceCommandsTable)
          .insert({
        'device_id': device.id,
        'command_type': 'capture_image',
        'payload': {},
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Capture command sent')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = context.watch<DeviceProvider>().selectedDevice;

    if (device == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text('Select a device', style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final job = _latestJob;
    final inference = _latestInference;
    final diagnostic = inference?['diagnostic'] as String?;
    final tips = inference?['tips'] as List?;
    final imageUrl = job?['image_url'] as String?;
    final status = job?['status'] as String?;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('AI Plant Health', style: theme.textTheme.headlineSmall),
                FilledButton.icon(
                  onPressed: _triggerCapture,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture Now'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (imageUrl != null && status == 'completed') ...[
              FutureBuilder<String>(
                future: _getImageUrl(imageUrl),
                builder: (context, snap) {
                  if (snap.hasData) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        snap.data!,
                        height: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderImage(theme),
                      ),
                    );
                  }
                  return _placeholderImage(theme);
                },
              ),
              const SizedBox(height: 24),
            ] else if (status == 'pending' || status == 'processing')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 16),
                      Text('Processing... ($status)'),
                    ],
                  ),
                ),
              )
            else if (job == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.photo_camera, size: 48, color: theme.disabledColor),
                      const SizedBox(height: 16),
                      Text(
                        'No captures yet',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text('Tap "Capture Now" to take a plant photo for AI analysis.'),
                    ],
                  ),
                ),
              ),
            if (diagnostic != null && diagnostic.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Diagnostic', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(diagnostic),
                ),
              ),
            ],
            if (tips != null && tips.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Tips', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              ...tips.map((t) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.lightbulb_outline),
                  title: Text(t is String ? t : t.toString()),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage(ThemeData theme) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(Icons.image_not_supported, size: 64, color: theme.disabledColor),
      ),
    );
  }

  Future<String> _getImageUrl(String path) async {
    try {
      final url = SupabaseConfig.client!.storage
          .from('device-images')
          .getPublicUrl(path);
      return url;
    } catch (_) {
      return '';
    }
  }
}
