import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/config/supabase_config.dart';
import '../models/device_model.dart';
import '../models/sensor_model.dart';

class DeviceProvider extends ChangeNotifier {
  static const int _maxHistoryPoints = 10000; // Store up to ~1 week of minute-by-minute data

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
      
      // Auto-select first device if none selected
      if (_selectedDevice == null && _devices.isNotEmpty) {
        selectDevice(_devices.first);
      }
      
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
    
    if (_selectedDevice == null && _devices.isNotEmpty) {
      selectDevice(_devices.first);
    } else {
      notifyListeners();
    }
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
      // For each sensor, fetch initial history (up to limit)
      for (final sensor in _sensors) {
        if (sensor.sensorType == null) continue;
        
        final typeKey = sensor.sensorType!.key;
        
        final response = await SupabaseConfig.client!
            .from(SupabaseConfig.readingsTable)
            .select('value, ts')
            .eq('sensor_id', sensor.id)
            .order('ts', ascending: false)
            .limit(_maxHistoryPoints);
            
        final data = response as List<dynamic>;
        if (data.isNotEmpty) {
          // Update latest reading from the most recent one
          final latest = data.first;
          _latestReadings[typeKey] = (latest['value'] as num).toDouble();
          _lastUpdate = DateTime.parse(latest['ts']); // This will be roughly the last update
          
          // Build history (reversed because we fetched descending)
          final points = data.map((r) {
             final val = (r['value'] as num).toDouble();
             final ts = DateTime.parse(r['ts']).millisecondsSinceEpoch.toDouble();
             return FlSpot(ts, val);
          }).toList();

          // Ensure points are sorted by X (time) to prevent chart loops
          points.sort((a, b) => a.x.compareTo(b.x));
          
          _historicalReadings[typeKey] = points;
          
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
      final newTimestamp = ts.millisecondsSinceEpoch.toDouble();
      
      // Add new point
      currentHistory.add(FlSpot(newTimestamp, value));
      
      // Keep only last N points, but after sorting to ensure we keep the newest ones
      // Sort by X (time) to prevent chart loops
      currentHistory.sort((a, b) => a.x.compareTo(b.x));
      
      if (currentHistory.length > _maxHistoryPoints) {
        // Remove oldest points (first ones after sort)
        final excess = currentHistory.length - _maxHistoryPoints;
        currentHistory.removeRange(0, excess);
      }
      
      _historicalReadings[typeKey] = List.from(currentHistory);
      
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
      'soil_moisture': 45.0,
      'water_level': 80.0,
    };
    _hasReadings = true;
    _lastUpdate = DateTime.now();
    
    // Generate initial history
    final now = DateTime.now();
    _historicalReadings = {
      'temp_c': List.generate(10, (i) {
        final ts = now.subtract(Duration(minutes: (10 - i) * 5)).millisecondsSinceEpoch.toDouble();
        return FlSpot(ts, 20 + Random().nextDouble() * 5);
      }),
      'humidity': List.generate(10, (i) {
        final ts = now.subtract(Duration(minutes: (10 - i) * 5)).millisecondsSinceEpoch.toDouble();
        return FlSpot(ts, 60 + Random().nextDouble() * 10);
      }),
      'light_lux': List.generate(10, (i) {
        final ts = now.subtract(Duration(minutes: (10 - i) * 5)).millisecondsSinceEpoch.toDouble();
        return FlSpot(ts, 800 + Random().nextDouble() * 100);
      }),
      'soil_moisture': List.generate(10, (i) {
        final ts = now.subtract(Duration(minutes: (10 - i) * 5)).millisecondsSinceEpoch.toDouble();
        return FlSpot(ts, 40 + Random().nextDouble() * 10);
      }),
      'water_level': List.generate(10, (i) {
        final ts = now.subtract(Duration(minutes: (10 - i) * 5)).millisecondsSinceEpoch.toDouble();
        return FlSpot(ts, 75 + Random().nextDouble() * 5);
      }),
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

      final currentSoil = _latestReadings['soil_moisture'] ?? 45.0;
      final newSoil = (currentSoil + (Random().nextDouble() - 0.5) * 2).clamp(0.0, 100.0);
      _latestReadings['soil_moisture'] = newSoil;

      final currentWater = _latestReadings['water_level'] ?? 80.0;
      final newWater = (currentWater + (Random().nextDouble() - 0.5)).clamp(0.0, 100.0);
      _latestReadings['water_level'] = newWater;

      final now = DateTime.now();
      _lastUpdate = now;
      
      // Update history
      final ts = now.millisecondsSinceEpoch.toDouble();
      for (final key in ['temp_c', 'humidity', 'light_lux', 'soil_moisture', 'water_level']) {
         final history = _historicalReadings[key] ?? []; // Handle potential null if key not in initial map (though it should be)
         if (history.length >= 20) history.removeAt(0);
         
         double val = 0.0;
         if (key == 'temp_c') val = newTemp;
         else if (key == 'humidity') val = newHum;
         else if (key == 'light_lux') val = newLight;
         else if (key == 'soil_moisture') val = newSoil;
         else if (key == 'water_level') val = newWater;

         history.add(FlSpot(ts, val));
         _historicalReadings[key] = List.from(history);
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
