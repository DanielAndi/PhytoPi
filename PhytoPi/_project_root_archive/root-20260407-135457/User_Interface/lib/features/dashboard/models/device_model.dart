class Device {
  final String id;
  final String name;
  final bool isOnline;
  final DateTime? lastSeen;

  Device({
    required this.id,
    required this.name,
    this.isOnline = false,
    this.lastSeen,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Device',
      isOnline: (json['status'] == 'active') || (json['is_online'] ?? false),
      lastSeen: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : (json['last_seen'] != null 
              ? DateTime.parse(json['last_seen']) 
              : null),
    );
  }
}

