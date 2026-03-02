import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/supabase_config.dart';
import '../providers/device_provider.dart';
import '../widgets/mjpeg_view.dart';

enum _StreamState { loading, live, disconnected }

class AiHealthScreen extends StatefulWidget {
  const AiHealthScreen({super.key});

  @override
  State<AiHealthScreen> createState() => _AiHealthScreenState();
}

class _AiHealthScreenState extends State<AiHealthScreen> {
  Map<String, dynamic>? _latestCompletedJob;  // for displaying the captured image
  Map<String, dynamic>? _inProgressJob;       // pending or processing job (shows spinner)
  Map<String, dynamic>? _latestInference;
  bool _loading = true;
  String? _error;
  _StreamState _streamState = _StreamState.loading;
  String _streamUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
    _streamUrl = _cacheBustUrl(AppConfig.streamUrl);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _streamState = _StreamState.live);
    });
  }

  String _cacheBustUrl(String base) {
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}_t=${DateTime.now().millisecondsSinceEpoch}';
  }

  void _retryStream() {
    setState(() {
      _streamState = _StreamState.loading;
      _streamUrl = _cacheBustUrl(AppConfig.streamUrl);
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _streamState = _StreamState.live);
    });
  }

  Future<void> _load() async {
    final device = context.read<DeviceProvider>().selectedDevice;
    if (device == null || !SupabaseConfig.isInitialized) {
      setState(() {
        _loading = false;
        _latestCompletedJob = null;
        _inProgressJob = null;
        _latestInference = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Latest completed job — used to show the captured image
      final completedJobs = await SupabaseConfig.client!
          .from('ai_capture_jobs')
          .select()
          .eq('device_id', device.id)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(1);

      // Any currently pending or processing job — shows the spinner
      final pendingJobs = await SupabaseConfig.client!
          .from('ai_capture_jobs')
          .select()
          .eq('device_id', device.id)
          .inFilter('status', ['pending', 'processing'])
          .order('created_at', ascending: false)
          .limit(1);

      // Latest inference — always shown independently of job status
      final inferences = await SupabaseConfig.client!
          .from(SupabaseConfig.mlInferencesTable)
          .select()
          .eq('device_id', device.id)
          .order('timestamp', ascending: false)
          .limit(1);

      if (mounted) {
        setState(() {
          _latestCompletedJob =
              (completedJobs as List).isNotEmpty ? completedJobs.first : null;
          _inProgressJob =
              (pendingJobs as List).isNotEmpty ? pendingJobs.first : null;
          _latestInference =
              (inferences as List).isNotEmpty ? inferences.first : null;
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

    final inference = _latestInference;
    final diagnostic = inference?['diagnostic'] as String?;
    final tips = inference?['tips'] as List?;
    final imageUrl = _latestCompletedJob?['image_url'] as String?;
    final inProgressStatus = _inProgressJob?['status'] as String?;
    final resultMap = inference?['result'] as Map<String, dynamic>?;
    final analysis = resultMap?['llm']?['analysis'] as Map<String, dynamic>?;
    final sensorSnapshot = resultMap?['sensor_snapshot'] as String?;
    final envAssessment = analysis?['environment_assessment'] as String?;
    final healthStatus = analysis?['health_status'] as String? ??
        resultMap?['vision']?['plant_state'] as String?;
    final isHealthy = healthStatus != 'needs_attention';

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
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

            // Health status banner (shown when analysis available)
            if (analysis != null) ...[
              _HealthStatusBanner(isHealthy: isHealthy, theme: theme),
              const SizedBox(height: 24),
            ],

            // Live stream
            Text('Live View', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_streamState == _StreamState.loading)
                    const Center(child: CircularProgressIndicator(color: Colors.white))
                  else
                    MjpegView(url: _streamUrl, fit: BoxFit.contain),
                  if (_streamState == _StreamState.disconnected)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_off, size: 48, color: Colors.white70),
                            const SizedBox(height: 8),
                            const Text('Stream disconnected',
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _retryStream,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: TextButton.icon(
                      onPressed: _retryStream,
                      icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
                      label: const Text('Retry',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Captured image
            Text('AI Capture', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),

            // In-progress banner (shown above the last completed image if a new job is running)
            if (inProgressStatus != null)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 14),
                      Text('New capture in progress ($inProgressStatus)…'),
                    ],
                  ),
                ),
              ),

            if (imageUrl != null) ...[
              FutureBuilder<String>(
                future: _getImageUrl(imageUrl),
                builder: (context, snap) {
                  if (snap.hasData && snap.data!.isNotEmpty) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        snap.data!,
                        height: 280,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderImage(theme),
                      ),
                    );
                  }
                  return _placeholderImage(theme);
                },
              ),
              const SizedBox(height: 24),
            ] else if (inProgressStatus == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.photo_camera, size: 48, color: theme.disabledColor),
                      const SizedBox(height: 16),
                      Text('No captures yet', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text('Tap "Capture Now" to take a plant photo for AI analysis.'),
                    ],
                  ),
                ),
              ),

            // Rich analysis grid
            if (analysis != null) ...[
              Text('Plant Analysis', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              _AnalysisGrid(analysis: analysis, theme: theme),
              const SizedBox(height: 24),
            ],

            // Environment assessment (sensor cross-check)
            if (envAssessment != null && envAssessment.isNotEmpty) ...[
              Text('Environment Assessment', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(Icons.sensors, color: theme.colorScheme.primary),
                  title: Text(envAssessment, style: theme.textTheme.bodyMedium),
                  subtitle: sensorSnapshot != null && sensorSnapshot.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            sensorSnapshot,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Diagnostic
            if (diagnostic != null && diagnostic.isNotEmpty) ...[
              Text('Diagnostic', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(diagnostic, style: theme.textTheme.bodyMedium),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Care tips
            if (tips != null && tips.isNotEmpty) ...[
              Text('Care Tips', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              ...tips.asMap().entries.map((e) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text('${e.key + 1}',
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onPrimaryContainer)),
                      ),
                      title: Text(e.value is String ? e.value : e.value.toString()),
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
      height: 280,
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
      // device-images is a private bucket — use a signed URL (valid 1 hour)
      final url = await SupabaseConfig.client!.storage
          .from('device-images')
          .createSignedUrl(path, 3600);
      return url;
    } catch (_) {
      return '';
    }
  }
}

// ---------------------------------------------------------------------------
// Health status banner
// ---------------------------------------------------------------------------
class _HealthStatusBanner extends StatelessWidget {
  const _HealthStatusBanner({required this.isHealthy, required this.theme});
  final bool isHealthy;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = isHealthy ? Colors.green.shade700 : Colors.orange.shade700;
    final bg = isHealthy ? Colors.green.shade50 : Colors.orange.shade50;
    final icon = isHealthy ? Icons.check_circle_outline : Icons.warning_amber_outlined;
    final label = isHealthy ? 'Plant is Healthy' : 'Needs Attention';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Text(label,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Analysis grid — displays species, leaf data, growth stage, disease signs
// ---------------------------------------------------------------------------
class _AnalysisGrid extends StatelessWidget {
  const _AnalysisGrid({required this.analysis, required this.theme});
  final Map<String, dynamic> analysis;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final items = <_AnalysisItem>[
      _AnalysisItem(Icons.eco_outlined, 'Species', analysis['species'] ?? '—'),
      _AnalysisItem(Icons.palette_outlined, 'Leaf Colour', analysis['leaf_color'] ?? '—'),
      _AnalysisItem(Icons.crop_free_outlined, 'Leaf Area', analysis['leaf_area'] ?? '—'),
      _AnalysisItem(Icons.texture_outlined, 'Leaf Condition', analysis['leaf_condition'] ?? '—'),
      _AnalysisItem(Icons.timeline_outlined, 'Growth Stage', analysis['growth_stage'] ?? '—'),
      _AnalysisItem(Icons.bug_report_outlined, 'Disease / Pests', analysis['disease_signs'] ?? '—'),
      _AnalysisItem(Icons.water_drop_outlined, 'Soil', analysis['soil_observation'] ?? '—'),
    ].where((i) => i.value.isNotEmpty && i.value != '—').toList();

    return Column(
      children: items
          .map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(item.icon, color: theme.colorScheme.primary),
                  title: Text(item.label,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  subtitle: Text(item.value, style: theme.textTheme.bodyMedium),
                ),
              ))
          .toList(),
    );
  }
}

class _AnalysisItem {
  const _AnalysisItem(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}
