import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/config/supabase_config.dart';
import '../models/device_model.dart';
import '../models/sensor_model.dart';

class DeviceProvider extends ChangeNotifier {
  List<Device> _devices = [];
  Device? _selectedDevice;
  List<Sensor> _sensors = [];
  
  // Map sensor type (e.g., 'temp_c') to the latest value
  Map<String, double> _latestReadings = {};
  
  // Map sensor type to a list of data points for charts
  Map<String, List<FlSpot>> _historicalReadings = {};
  
  DateTime? _lastUpdate;
  bool _isLoading = false;
  String? _error;
  bool _hasReadings = false;
  
  RealtimeChannel? _readingsSubscription;

  List<Device> get devices => _devices;
  Device? get selectedDevice => _selectedDevice;
  List<Sensor> get sensors => _sensors;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasReadings => _hasReadings;
  DateTime? get lastUpdate => _lastUpdate;
  
  Map<String, double> get latestReadings => _latestReadings;
  Map<String, List<FlSpot>> get historicalReadings => _historicalReadings;

  DeviceProvider() {
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    if (!SupabaseConfig.isInitialized) {
      _loadDemoDevices();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await SupabaseConfig.client!
          .from(SupabaseConfig.devicesTable)
          .select()
          .order('created_at');
      
      final data = response as List<dynamic>;
      _devices = data.map((json) => Device.fromJson(json)).toList();
      
    } catch (e) {
      _error = e.toString();
      debugPrint('DeviceProvider: Error loading devices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadDemoDevices() {
    _devices = [
      Device(id: 'demo-1', name: 'Living Room PhytoPi', isOnline: true, lastSeen: DateTime.now()),
      Device(id: 'demo-2', name: 'Bedroom PhytoPi', isOnline: false, lastSeen: DateTime.now().subtract(const Duration(hours: 2))),
    ];
    notifyListeners();
  }

  void selectDevice(Device device) {
    if (_selectedDevice?.id == device.id) return;
    
    _selectedDevice = device;
    _latestReadings.clear();
    _historicalReadings.clear();
    _sensors.clear();
    _lastUpdate = null;
    _hasReadings = false;
    
    notifyListeners();
    
    if (SupabaseConfig.isInitialized) {
      _fetchSensorsAndSubscribe(device.id);
    } else {
      _simulateDemoReadings();
    }
  }

  void clearSelection() {
    _unsubscribe();
    _selectedDevice = null;
    _sensors = [];
    _latestReadings = {};
    _historicalReadings = {};
    _hasReadings = false;
    _lastUpdate = null;
    notifyListeners();
  }

  Future<void> _fetchSensorsAndSubscribe(String deviceId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch sensors with their types
      final response = await SupabaseConfig.client!
          .from(SupabaseConfig.sensorsTable)
          .select('*, sensor_types(*)')
          .eq('device_id', deviceId);
      
      final data = response as List<dynamic>;
      _sensors = data.map((json) => Sensor.fromJson(json)).toList();
      
      if (_sensors.isNotEmpty) {
        await _fetchInitialHistory();
        _subscribeToReadings();
      }
      
    } catch (e) {
      _error = e.toString();
      debugPrint('DeviceProvider: Error loading sensors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchInitialHistory() async {
    try {
      // For each sensor, fetch last 24 hours of readings
      // Limiting to 100 points per sensor for performance for now
      for (final sensor in _sensors) {
        if (sensor.sensorType == null) continue;
        
        final typeKey = sensor.sensorType!.key;
        
        final response = await SupabaseConfig.client!
            .from(SupabaseConfig.readingsTable)
            .select('value, ts')
            .eq('sensor_id', sensor.id)
            .order('ts', ascending: false)
            .limit(50); // Limit history points
            
        final data = response as List<dynamic>;
        if (data.isNotEmpty) {
          // Update latest reading from the most recent one
          final latest = data.first;
          _latestReadings[typeKey] = (latest['value'] as num).toDouble();
          _lastUpdate = DateTime.parse(latest['ts']); // This will be roughly the last update
          
          // Build history (reversed because we fetched descending)
          final points = data.map((r) {
             // Convert timestamp to something plottable, e.g., index or relative time
             // For simplicity in this chart, we might just use an index 0..N or relative hours
             // But FlChart needs X,Y. Let's use millisecondsSinceEpoch for X but scaled?
             // Or just index for now as the chart in dashboard was index based.
             // Let's try to map to an index based on time or just sequential.
             // Sequential is easier for a simple trend line.
             return (r['value'] as num).toDouble();
          }).toList().reversed.toList(); // Oldest first
          
          _historicalReadings[typeKey] = List.generate(points.length, (index) {
             return FlSpot(index.toDouble(), points[index]);
          });
          
          _hasReadings = true;
        }
      }
    } catch (e) {
      debugPrint('DeviceProvider: Error fetching history: $e');
    }
  }

  void _subscribeToReadings() {
    _unsubscribe();

    _readingsSubscription = SupabaseConfig.client!
        .channel('public:${SupabaseConfig.readingsTable}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.readingsTable,
          callback: (payload) {
            _handleNewReading(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _handleNewReading(Map<String, dynamic> record) {
    try {
      final sensorId = record['sensor_id'] as String?;
      if (sensorId == null) return;

      dynamic rawValue = record['value'];
      final double value;
      if (rawValue is num) {
        value = rawValue.toDouble();
      } else if (rawValue is String) {
        value = double.tryParse(rawValue) ?? 0.0;
      } else {
        return; // Unknown format
      }

      final tsString = record['ts'] as String?;
      final ts = tsString != null ? DateTime.parse(tsString) : DateTime.now();
      
      final sensor = _sensors.firstWhere(
        (s) => s.id == sensorId,
        orElse: () => Sensor(id: '', deviceId: '', typeId: '', metadata: {}),
      );
      
      if (sensor.id.isEmpty || sensor.sensorType == null) return;
      
      final typeKey = sensor.sensorType!.key;
      
      _latestReadings[typeKey] = value;
      _lastUpdate = ts;
      _hasReadings = true;
      
      // Update history
      final currentHistory = _historicalReadings[typeKey] ?? [];
      final newIndex = currentHistory.isNotEmpty ? currentHistory.last.x + 1 : 0;
      
      // Keep only last 50 points
      if (currentHistory.length >= 50) {
        currentHistory.removeAt(0);
        // Shift indices to keep chart moving smoothly or just append
        // If we just append, x grows indefinitely. For a scrolling chart that's fine,
        // but eventually float precision issues? unlikely for 50 points.
        // But let's just append for now as before.
        // Actually, let's shift x values back to 0..49 to keep it clean?
        // The previous implementation shifted values.
        // Let's stick to the previous logic but cleaner.
        final shifted = List<FlSpot>.generate(currentHistory.length, (i) {
           return FlSpot(i.toDouble(), currentHistory[i].y);
        });
        shifted.add(FlSpot(shifted.length.toDouble(), value));
        _historicalReadings[typeKey] = shifted;
      } else {
        currentHistory.add(FlSpot(newIndex.toDouble(), value));
        _historicalReadings[typeKey] = List.from(currentHistory); 
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('DeviceProvider: Error handling new reading: $e');
    }
  }

  void _unsubscribe() {
    if (_readingsSubscription != null) {
      SupabaseConfig.client?.removeChannel(_readingsSubscription!);
      _readingsSubscription = null;
    }
  }
  
  // Demo Mode Simulation
  Timer? _demoTimer;
  
  void _simulateDemoReadings() {
    _demoTimer?.cancel();
    
    // Set initial values
    _latestReadings = {
      'temp_c': 22.5,
      'humidity': 65.0,
      'light_lux': 850.0, // Lux
    };
    _hasReadings = true;
    _lastUpdate = DateTime.now();
    
    // Generate initial history
    _historicalReadings = {
      'temp_c': List.generate(10, (i) => FlSpot(i.toDouble(), 20 + Random().nextDouble() * 5)),
      'humidity': List.generate(10, (i) => FlSpot(i.toDouble(), 60 + Random().nextDouble() * 10)),
    };
    notifyListeners();

    _demoTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_selectedDevice == null) {
        timer.cancel();
        return;
      }
      
      // Update values with random walk
      final currentTemp = _latestReadings['temp_c'] ?? 22.0;
      final newTemp = currentTemp + (Random().nextDouble() - 0.5);
      _latestReadings['temp_c'] = newTemp;
      
      final currentHum = _latestReadings['humidity'] ?? 60.0;
      final newHum = currentHum + (Random().nextDouble() - 0.5) * 2;
      _latestReadings['humidity'] = newHum;

      final currentLight = _latestReadings['light_lux'] ?? 800.0;
      final newLight = (currentLight + (Random().nextDouble() - 0.5) * 50).clamp(0.0, 2000.0);
      _latestReadings['light_lux'] = newLight;

      _lastUpdate = DateTime.now();
      
      // Update history
      for (final key in ['temp_c', 'humidity']) {
         final history = _historicalReadings[key]!;
         if (history.length >= 20) history.removeAt(0);
         
         // Shift indices
         final shifted = List.generate(history.length, (i) => FlSpot(i.toDouble(), history[i].y));
         final val = key == 'temp_c' ? newTemp : newHum;
         shifted.add(FlSpot(shifted.length.toDouble(), val));
         _historicalReadings[key] = shifted;
      }

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _unsubscribe();
    _demoTimer?.cancel();
    super.dispose();
  }
  
  Future<void> claimDevice(String serialNumber) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (!SupabaseConfig.isInitialized) {
        // Demo mode
        final newDevice = Device(
          id: serialNumber, 
          name: 'New Device ($serialNumber)',
          isOnline: true,
          lastSeen: DateTime.now()
        );
        _devices.add(newDevice);
        selectDevice(newDevice);
        return;
      }

      final response = await SupabaseConfig.client!
          .rpc('claim_device_by_serial', params: {'serial_text': serialNumber});
      
      // Re-fetch devices to ensure list is up to date
      await _loadDevices();
      
      // Select the newly claimed device
      if (response != null) {
        final data = response as Map<String, dynamic>;
        final newDeviceId = data['id'];
        try {
          final newDevice = _devices.firstWhere((d) => d.id == newDeviceId);
          selectDevice(newDevice);
        } catch (_) {
          // Should not happen if _loadDevices worked
        }
      }
      
    } catch (e) {
      _error = e.toString();
      debugPrint('DeviceProvider: Error claiming device: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
