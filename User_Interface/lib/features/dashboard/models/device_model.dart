class Device {
  final String id;
  final String name;
  final DateTime? lastSeen;
  final bool _statusActive;
  final bool _isOnlineOverride;

  Device({
    required this.id,
    required this.name,
    this.lastSeen,
    bool statusActive = false,
    bool isOnlineOverride = false,
  })  : _statusActive = statusActive,
        _isOnlineOverride = isOnlineOverride;

  /// Online if last_seen within 90 seconds (heartbeat from Pi). Status 'active' means
  /// device is enabled, not that it's currently connected — use last_seen for that.
  bool get isOnline {
    const offlineTimeout = Duration(seconds: 90);
    if (_isOnlineOverride) return true; // Manual override for testing only
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen!) < offlineTimeout;
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    final lastSeen = json['last_seen'] != null
        ? DateTime.parse(json['last_seen'])
        : (json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null);
    return Device(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Device',
      lastSeen: lastSeen,
      statusActive: json['status'] == 'active',
      isOnlineOverride: json['is_online'] == true,
    );
  }
}

